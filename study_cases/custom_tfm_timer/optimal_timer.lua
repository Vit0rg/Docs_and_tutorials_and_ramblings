-- tfm_lua51_optimal_timer.lua
-- Strictly flat, strictly O(1), strictly forward, strictly Lua 5.1.
local unpack = unpack

local timers = {}
local activeLabels = {}
local freeIndices = {}
local timerPool = {}

local SERVER_DELAY = 500

-- =====================================================================
-- EXTRACTED GUARD FUNCTIONS (Zero nesting via early returns)
-- =====================================================================

local function processTimer(t)
	if not t.enabled or t.paused or t.done then return false end

	t.curTime = t.curTime + SERVER_DELAY
	if t.curTime < t.time then return false end

	t.curTime = 0
	t.loop = t.loop + 1

	if t.callback then t.callback(t.loop, unpack(t.arguments)) end

	if t.maxLoops > 0 and t.loop >= t.maxLoops then
	t.done = true
	return true
	end

	return false
end

local function completeTimer(i, label, t)
	if eventTimerComplete then eventTimerComplete(label, label) end

	activeLabels[i] = nil

	freeIndices[#freeIndices + 1] = i

	t.callback = nil;
	t.label = nil;
	t.arguments = nil;
	t.index = nil

	timerPool[#timerPool + 1] = t
	timers[label] = nil
end

local function handleTimerSlot(i, label)
	if not label then return end

	local t = timers[label]

	if not t then return end
	if not processTimer(t) then return end

	completeTimer(i, label, t)
end

local function releaseTimerSlot(i, label)
	if not label then return end

	local t = timers[label]
	if not t then return end
	t.callback = nil;
	t.label = nil;
	t.arguments = nil;
	t.index = nil

	timerPool[#timerPool + 1] = t
	timers[label] = nil
end

-- =====================================================================
-- PUBLIC API
-- =====================================================================

function addTimer(args)
	local t = timerPool[#timerPool]
	if t then
	timerPool[#timerPool] = nil
	else
	t = {}
	end

	local idx = freeIndices[#freeIndices]
	if idx then
	freeIndices[#freeIndices] = nil
	else
	idx = #activeLabels + 1
	end

	local label = args[4]
	if type(label) ~= "string" or label == "" then
	return nil, "Label must be a non-empty string"
	end

	if timers[label] then
	return nil, "Timer '" .. label .. "' already exists"
	end
	t.label = args[4]
	t.callback = args[1]
	t.time = args[2]
	t.curTime = 0
	t.loop = 0
	t.maxLoops = args[3] or 1
	t.done = false
	t.paused = false
	t.enabled = true
	t.index = idx

	if #args > 4 then
	t.arguments = {unpack(args, 5)}
	else
	t.arguments = {}
	end

	timers[label] = t
	activeLabels[idx] = label
	return label
end

function getTimerId(label) return timers[label] and label or nil end

function pauseTimer(label)
	if type(label) ~= "string" then return false end

	local t = timers[label]

	if t and t.enabled and not t.done then
	t.paused = true
	return true
	end

	return false
end

function resumeTimer(label)
	if type(label) ~= "string" then return false end

	local t = timers[label]

	if t and t.paused and not t.done then
	t.paused = false
	return true
	end

	return false
end

function removeTimer(label)
	if type(label) ~= "string" then return false end

	local t = timers[label]

	if not t or not t.enabled or t.done then return false end

	t.enabled = false
	t.done = true

	activeLabels[t.index] = nil
	freeIndices[#freeIndices + 1] = t.index

	t.callback = nil;
	t.label = nil;
	t.arguments = nil;
	t.index = nil

	timerPool[#timerPool + 1] = t
	timers[label] = nil

	return true
end

-- Zero nesting: single-line loop body delegates to extracted function
function clearTimers()
	local n = #activeLabels

	for i = 1, n do
	releaseTimerSlot(i, activeLabels[i])
	activeLabels[i] = nil
	freeIndices[#freeIndices + 1] = i
	end
end

-- Zero nesting: single-line loop body delegates to extracted function
function timersLoop()
	for i = 1, #activeLabels do handleTimerSlot(i, activeLabels[i]) end
end
