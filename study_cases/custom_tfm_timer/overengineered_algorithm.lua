local timersList = {}

-- Expects a table with at least 4 items
-- 1 => callback function
-- 2 => duration (called time in some previous versions)
-- 3 => loops (max iterations)
-- 4 => label (MUST be passed)
local function addTimer(args)
  local label = args[4]

  if label == nil or label == '' or type(label) ~= "string" then
    print('Error: Label must be a string and cannot be nil or empty')
    return
  end

  if timersList[label] then
    print('Warning: Overwriting existing timer with label: ' .. label)
  end

  if not timersList[label] then
    timersList[label] = {}
  end

  local timerId = timersList[label]

  timerId.callback = args[1]
  timerId.duration = args[2]
  timerId.loops = args[3] or 1

  if #args > 4 then
    timerId.arguments = { table.unpack(args, 5) }
  end

  timerId.currentTime = 0
  timerId.currentLoop = 0

  timerId.isComplete = false
  timerId.isPaused = false
  timerId.isEnabled = true

  return label
end

local function getTimerId(label)
  if timersList[label] then
    return label
  end

  print("Timer not found.")
  return false
end

local function pauseTimer(id)
  if timersList[id] and timersList[id].isEnabled then
    timersList[id].isPaused = true
    return true
  end

  return false
end

local function resumeTimer(id)
  if timersList[id] and timersList[id].isPaused then
    timersList[id].isPaused = false
    return true
  end

  return false
end

local function removeTimer(id)
  if timersList[id] and timersList[id].isEnabled then
    -- timersList[id].isEnabled = false
    timersList[id] = nil
    return true
  end

  return false
end

local function clearTimers()
  timersList = {}
end

local function timersLoop()
  local serverDelay = 500
  local _toRemove = {} -- Safe removal buffer for pairs() iteration

  for label, timer in pairs(timersList) do
    -- This hackerish 'repeat until true' makes the
    -- 'do break end' line act like a continue statement,
    -- which adds insignicant overhead. Vit0rg
    repeat
      if timer.isComplete or not timer.isEnabled or timer.isPaused then
        do break end
      end

      timer.currentTime = timer.currentTime + serverDelay

      if timer.currentTime < timer.duration then
        do break end
      end

      timer.currentTime = 0
      timer.currentLoop = timer.currentLoop + 1

      if timer.callback ~= nil then
        timer.callback({ timer.currentLoop, timer.arguments })
      end

      if timer.loops > 0 and timer.currentLoop >= timer.loops then
        timer.isComplete = true
        -- eventTimerComplete(label, timer.label)
        _toRemove[#_toRemove + 1] = label
      end
    until true
  end

  -- Safely remove completed timers after iteration
  for i = 1, #_toRemove do
    timersList[_toRemove[i]] = nil
  end
end