-- benchmarker.lua
-- Restructured comparative benchmark.
-- Isolates Add, Loop, Remove, and Bulk Clear operations.
-- =====================================================================
-- 1. COMPATIBILITY SHIMS
-- =====================================================================
table = table or {}
table.unpack = table.unpack or unpack
eventTimerComplete = function() end

-- =====================================================================
-- 2. DYNAMIC MODULE LOADER
-- =====================================================================
local function loadModule(filename)
    local file = io.open(filename, "r")
    if not file then error("File not found: " .. filename) end
    local source = file:read("*a")
    file:close()

    local api_capture = [[
    return {
        addTimer = addTimer, removeTimer = removeTimer, pauseTimer = pauseTimer,
        resumeTimer = resumeTimer, clearTimers = clearTimers, timersLoop = timersLoop,
        getTimerId = getTimerId
    }
    ]]

    local chunk, err = loadstring(source .. "\n" .. api_capture)
    if not chunk then
        chunk, err = loadstring(source)
        if not chunk then
            error("Syntax error in " .. filename .. ": " .. err)
        end
    end

    local env = {}
    setmetatable(env, {__index = _G})
    setfenv(chunk, env)

    local result = chunk()
    if type(result) == "table" and result.addTimer then return result end

    return {
        addTimer = env.addTimer,
        removeTimer = env.removeTimer,
        pauseTimer = env.pauseTimer,
        resumeTimer = env.resumeTimer,
        clearTimers = env.clearTimers,
        timersLoop = env.timersLoop,
        getTimerId = env.getTimerId
    }
end

-- =====================================================================
-- 3. BENCHMARK EXECUTION
-- =====================================================================
local modules = {
    {
        name = "1. original_algorithm",
        file = "original_algorithm.lua",
        legacy_api = true
    }, {
        name = "2. overengineered",
        file = "overengineered_algorithm.lua",
        legacy_api = false
    }, {
        name = "3. optimal (Extracted)",
        file = "optimal_timer.lua",
        legacy_api = false
    }, {
        name = "4. optimal_inline",
        file = "optimal_inline_timer.lua",
        legacy_api = false
    }, {
        name = "5. optimal_repeat",
        file = "optimal_repeat_timer.lua",
        legacy_api = false
    },
    {
        name = "6. optimal_ref",
        file = "optimal_ref_timer.lua",
        legacy_api = false
    }
}

local N = 5000 -- Number of timers
local TICKS = 2000 -- Number of loop iterations
local dummyCallback = function() end

local function runBenchmark()
    print(string.rep("=", 95))
    print(string.format("%-25s | %-12s | %-12s | %-12s | %-12s | %-12s",
                        "Implementation", "Add (ms)", "Loop (ms)",
                        "Remove (ms)", "Clear (ms)", "Total (ms)"))
    print(string.rep("-", 95))

    for _, modDef in ipairs(modules) do
        local ok, mod = pcall(loadModule, modDef.file)

        if not ok then
            print(string.format("%-25s | FAILED: %s", modDef.name, mod))
        else
            collectgarbage("collect")
            local args = {dummyCallback, 10000, 0, "base"} -- 10000ms ensures no timers expire during Loop phase

            local t_add, t_loop, t_remove, t_clear = 0, 0, 0, 0

            -- PHASE 1: ADDITION
            local start = os.clock()
            for i = 1, N do
                args[4] = "t_" .. i
                if modDef.legacy_api then
                    mod.addTimer(args[1], args[2], args[3], args[4])
                else
                    mod.addTimer(args)
                end
            end
            t_add = (os.clock() - start) * 1000

            -- PHASE 2: HOT PATH (LOOP)
            -- Timers are set to 10000ms, server delay is 500ms. They will not expire.
            -- This purely measures iteration and hash-lookup overhead.
            start = os.clock()
            for _ = 1, TICKS do mod.timersLoop() end
            t_loop = (os.clock() - start) * 1000

            -- PHASE 3: INDIVIDUAL REMOVAL
            -- Measures the cumulative cost of the O(1) removal API.
            start = os.clock()
            for i = 1, N do mod.removeTimer("t_" .. i) end
            t_remove = (os.clock() - start) * 1000

            -- PHASE 4: BULK CLEAR (The O(N^2) Trap)
            -- Re-add timers, then call clearTimers(). 
            -- This forces original_algorithm's table.remove loop to execute, exposing the O(N^2) shift.
            for i = 1, N do
                args[4] = "c_" .. i
                if modDef.legacy_api then
                    mod.addTimer(args[1], args[2], args[3], args[4])
                else
                    mod.addTimer(args)
                end
            end

            start = os.clock()
            mod.clearTimers()
            t_clear = (os.clock() - start) * 1000

            local t_total = t_add + t_loop + t_remove + t_clear

            print(string.format(
                      "%-25s | %12.2f | %12.2f | %12.2f | %12.2f | %12.2f",
                      modDef.name, t_add, t_loop, t_remove, t_clear, t_total))

            collectgarbage("collect")
        end
    end
    print(string.rep("=", 95))
    print("Metrics: os.clock() CPU time in milliseconds. Lower is better.")
end

runBenchmark()
