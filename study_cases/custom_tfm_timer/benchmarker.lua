-- benchmarker.lua
-- Comparative benchmark for the 5 Timer System implementations.
-- Strictly Lua 5.1 compliant.
-- =====================================================================
-- 1. COMPATIBILITY SHIMS (Lua 5.1 Environment)
-- =====================================================================
-- The legacy scripts use table.unpack (Lua 5.2+) and expect eventTimerComplete.
table = table or {}
table.unpack = table.unpack or unpack

-- Dummy event to prevent nil errors in legacy scripts
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
        addTimer = addTimer,
        removeTimer = removeTimer,
        pauseTimer = pauseTimer,
        resumeTimer = resumeTimer,
        clearTimers = clearTimers,
        timersLoop = timersLoop,
        getTimerId = getTimerId
    }
    ]]

    -- Attempt to load with the API capture appended (required for legacy scripts)
    local chunk, err = loadstring(source .. "\n" .. api_capture)

    -- If it fails, it's likely because the script already has a 'return' statement 
    -- at the end (like the optimal_inline/repeat scripts). Load it natively instead.
    if not chunk then
        chunk, err = loadstring(source)
        if not chunk then
            error("Syntax error in " .. filename .. ": " .. err)
        end
    end

    -- Execute in a fresh environment to prevent global cross-contamination
    local env = {}
    setmetatable(env, {__index = _G})
    setfenv(chunk, env)

    local result = chunk()

    -- If the script returned a table (optimal_inline/repeat), use it directly.
    if type(result) == "table" and result.addTimer then return result end

    -- Fallback for legacy scripts that defined functions globally in the env
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
-- 3. BENCHMARK METRICS & EXECUTION
-- =====================================================================
local modules = {
    -- 'legacy_api = true' flags the original script to unpack arguments
    {
        name = "1. original_algorithm",
        file = "original_algorithm.lua",
        legacy_api = true
    }, {
        name = "2. overengineered_algorithm",
        file = "overengineered_algorithm.lua",
        legacy_api = false
    }, {
        name = "3. optimal_timer (Extracted)",
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
    }
}

local TIMER_COUNT = 5000
local TICK_COUNT = 2000
local dummyCallback = function() end

local function runBenchmark()
    print(string.rep("=", 70))
    print(string.format("%-30s | %-10s | %-10s | %-10s | %-10s",
                        "Implementation", "Add (ms)", "Loop (ms)", "Clear (ms)",
                        "Total (ms)"))
    print(string.rep("-", 70))

    for _, modDef in ipairs(modules) do
        local ok, mod = pcall(loadModule, modDef.file)

        if not ok then
            print(string.format("%-30s | FAILED TO LOAD: %s", modDef.name, mod))
        else
            -- Warm-up / GC stabilization
            collectgarbage("collect")

            local args = {dummyCallback, 1000, 0, "base_label"}
            local t_add, t_loop, t_clear = 0, 0, 0

            -- PHASE 1: ADDITION
            local start = os.clock()
            for i = 1, TIMER_COUNT do
                args[4] = "timer_" .. i

                -- Handle the legacy signature of original_algorithm.lua
                if modDef.legacy_api then
                    mod.addTimer(args[1], args[2], args[3], args[4])
                else
                    mod.addTimer(args)
                end
            end
            t_add = (os.clock() - start) * 1000

            -- PHASE 2: HOT PATH (LOOP)
            start = os.clock()
            for _ = 1, TICK_COUNT do mod.timersLoop() end
            t_loop = (os.clock() - start) * 1000

            -- PHASE 3: TEARDOWN (CLEAR)
            start = os.clock()
            mod.clearTimers()
            t_clear = (os.clock() - start) * 1000

            local t_total = t_add + t_loop + t_clear

            print(string.format("%-30s | %10.2f | %10.2f | %10.2f | %10.2f",
                                modDef.name, t_add, t_loop, t_clear, t_total))

            -- Force GC before next module to ensure fair memory baseline
            collectgarbage("collect")
        end
    end
    print(string.rep("=", 70))
    print(
        "Benchmark Complete. (Lower is better. Measured via os.clock CPU time)")
end

runBenchmark()
