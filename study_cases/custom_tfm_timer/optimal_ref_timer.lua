-- tfm_lua51_optimal_ref_timer.lua
-- Array of References architecture.
-- Eliminates hash lookups in the hot path by storing direct table references 
-- in the iteration array, while maintaining a hash table for O(1) API lookups.
local unpack = unpack

local timers = {} -- Hash: string label -> table reference (API lookups)
local activeRefs = {} -- Array: integer index -> table reference (Hot path iteration)
local freeIndices = {} -- Stack: recycled indices
local timerPool = {} -- Stack: recycled tables

local SERVER_DELAY = 500

local M = {}

function M.addTimer(args)
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
        idx = #activeRefs + 1
    end

    local label = args[4]
    if type(label) ~= "string" or label == "" then
        return nil, "Label must be a non-empty string"
    end

    if timers[label] then
        return nil, "Timer '" .. label .. "' already exists"
    end

    t.label = label
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
    activeRefs[idx] = t -- Store direct reference, not the string label
    return label
end

function M.getTimerId(label) return timers[label] and label or nil end

function M.pauseTimer(label)
    if type(label) ~= "string" then return false end
    local t = timers[label]
    if t and t.enabled and not t.done then
        t.paused = true;
        return true
    end
    return false
end

function M.resumeTimer(label)
    if type(label) ~= "string" then return false end
    local t = timers[label]
    if t and t.paused and not t.done then
        t.paused = false;
        return true
    end
    return false
end

function M.removeTimer(label)
    if type(label) ~= "string" then return false end
    local t = timers[label]
    if not t or not t.enabled or t.done then return false end

    t.enabled = false
    t.done = true

    activeRefs[t.index] = nil
    freeIndices[#freeIndices + 1] = t.index

    t.callback = nil;
    t.label = nil;
    t.arguments = nil;
    t.index = nil
    timerPool[#timerPool + 1] = t
    timers[label] = nil
    return true
end

function M.clearTimers()
    local n = #activeRefs
    for i = 1, n do
        local t = activeRefs[i]
        if t then
            timers[t.label] = nil
            t.callback = nil;
            t.label = nil;
            t.arguments = nil;
            t.index = nil
            timerPool[#timerPool + 1] = t
        end
        activeRefs[i] = nil
        freeIndices[#freeIndices + 1] = i
    end
end

-- =====================================================================
-- HOT PATH: Direct Reference Iteration
-- No hash lookups (timers[label]) required. Direct memory offset access.
-- =====================================================================
function M.timersLoop()
    for i = 1, #activeRefs do
        local t = activeRefs[i]

        if t then
            repeat
                if not t.enabled or t.paused or t.done then break end

                t.curTime = t.curTime + SERVER_DELAY
                if t.curTime < t.time then break end

                t.curTime = 0
                t.loop = t.loop + 1

                if t.callback then
                    t.callback(t.loop, unpack(t.arguments))
                end

                if t.maxLoops > 0 and t.loop >= t.maxLoops then
                    t.done = true
                    if eventTimerComplete then
                        eventTimerComplete(t.label, t.label)
                    end

                    local label = t.label -- Cache label before clearing

                    activeRefs[i] = nil
                    freeIndices[#freeIndices + 1] = i

                    t.callback = nil;
                    t.label = nil;
                    t.arguments = nil;
                    t.index = nil
                    timerPool[#timerPool + 1] = t
                    timers[label] = nil
                end
            until true
        end
    end
end

return M
