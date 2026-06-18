# Lua Procedural Context Injection (PCI)

**Author:** Vit0rg  
**Created:** June 17th 2026  
**Document last updated:** June 18th 2026  
**Inspired on:** GoF-to-Lua mapping and `vit0rg/volley` + `vit0rg/echeckers` architecture review. Using the 1st review of lua design patterns.  
**License:** MIT

---

## Table of Contents

- [Introduction](#introduction)
- [Premature optimization X Architectural Pattern](#premature-optimization-x-architectural-pattern)
- [Core Mechanism](#core-mechanism)
- [Performance Profile](#performance-profile)
- [Implementations](#implementations)
  - [1. The Standard Stateless Module](#1-the-standard-stateless-module)
  - [2. The Closure-Bound Module (Partial Application)](#2-the-closure-bound-module-partial-application)
  - [3. The Middleware Pipeline](#3-the-middleware-pipeline)
  - [4. Strategy / Behavior Injection](#4-strategy--behavior-injection)
  - [5. Asynchronous / Coroutine Context](#5-asynchronous--coroutine-context)
- [Data Structures Used](#data-structures-used)
- [Synergistic Patterns](#synergistic-patterns)
- [Applying PCI to existing projects](#applying-pci-to-existing-projects)
  - [1. Diagnosing the Current State](#1-diagnosing-the-current-state)
  - [2. Reshaping the Architecture](#2-reshaping-the-architecture)
  - [3. Mistakes that PCI Prevents](#3-mistakes-that-pci-prevents)
  - [4. Rules for the New Project (Prevention Checklist)](#4-rules-for-the-new-project-prevention-checklist)
  - [Optional: Native Modules over Concatenation](#optional-native-modules-over-concatenation)
- [5. References](#5-references)

---

## Introduction
- Procedural Context Injection (PCI) is the most lightweight, performant, and idiomatic method for managing dependencies in Lua.
- It completely discards Object-Oriented Programming (OOP) paradigms, metatables, and abstraction layers.  
- Instead, it relies on Lua’s native first-class functions and plain tables.  
- Dependencies are packed into a single, flat "context" table (usually named `ctx` or `env`), which is passed explicitly as the first argument to stateless functions.  
- This approach satisfies strict performance constraints regarding register pressure while eliminating the fragility of global state.


## Premature optimization X Architectural Pattern
- Premature optimization is sacrificing readability and architecture for marginal performance gains.
- PCI sacrifices nothing. 
- It results in cleaner, more cohesive data structures, highly testable pure functions, and explicit data flow. 
- The fact that it also perfectly aligns with the Lua VM's register allocation and JIT compiler limits makes it an informed, environment-specific architectural design, not a premature optimization.

## Core Mechanism

1. **Composition:** A single plain table (`ctx`) is instantiated at the application root, containing all shared infrastructure and systems.
2. **Injection:** The `ctx` table is passed as the **first argument** to module functions alongside transient data (e.g., `update(ctx, dt)`).
3. **Resolution:** Dependencies are accessed via direct, flat hash-table lookups (e.g., `ctx.physics`), bypassing the performance cost of global `_ENV` lookups and metamethod resolution.

---

## Performance Profile

### Speed Profile: The Register Pressure Advantage

- **Minimized Register Footprint:** In the Lua VM, every argument in a function signature consumes a CPU register. Scattered arguments (e.g., `function update(dt, board, player, hand, ui)`) quickly exhaust available registers, forcing the VM to "spill" variables into the slower call stack. In JIT environments (LuaJIT), this causes non-linear performance degradation and trace aborts. PCI reduces the dependency signature to exactly **one register** (`ctx`), eliminating scattered argument initialization.
- **Direct Lookups:** Accessing `ctx.db` is a direct C-level hash table lookup. It is significantly faster than a `GETTABUP` opcode (used for global variables) which must traverse the `_ENV` environment table.
- **No Metatable Traversal:** Unlike OOP (`self.db`), there is no `__index` metamethod fallback chain to traverse.

### Memory Profile

- **Minimal Allocations:** Only one table is allocated for the `ctx`, and one table for the module's function registry.
- **No Hidden State:** No memory is wasted on per-instance `self` tables, metatables, or hidden upvalue environments.
- **Garbage Collection:** Because there are no circular references created by metatables (e.g., `self.__index = self`), the GC has significantly less work to do, reducing pause times.

---

## Implementations

### 1. The Standard Stateless Module

- The baseline approach. Modules return a table of pure functions. 
- The `ctx` is passed explicitly, keeping the register footprint minimal.

```lua
-- user_service.lua
local M = {}

-- 2 registers used: 'ctx' and 'user_id'
function M.get_user(ctx, user_id)
    ctx.logger.info("Fetching user: " .. user_id)
    return ctx.db.query("SELECT * FROM users WHERE id = ?", user_id)
end

return M
```

### 2. The Closure-Bound Module (Partial Application)

- If passing `ctx` explicitly becomes tedious, a factory function captures the `ctx` in a closure. 
- This eliminates the need to pass `ctx` at call time while maintaining zero OOP overhead.

```lua
-- user_service.lua
local function build(ctx)
    local M = {}

    -- 'ctx' is captured as an upvalue.
    -- Function signature uses exactly 1 register: 'user_id'
    function M.get_user(user_id)
        ctx.logger.info("Fetching user: " .. user_id)
        return ctx.db.query("SELECT * FROM users WHERE id = ?", user_id)
    end

    return M
end

return build
```

### 3. The Middleware Pipeline

- PCI is perfectly suited for middleware chains.
- The `ctx` is passed sequentially through a list of functions, allowing each to read or mutate it without inflating argument lists.

```lua
-- router.lua
local M = {}

function M.execute_pipeline(ctx, handlers)
    for _, handler in ipairs(handlers) do
        local ok, err = pcall(handler, ctx)
        if not ok or ctx.halted then break end
    end
end

return M
```

### 4. Strategy / Behavior Injection

- Because `ctx` is just a plain table, you can easily swap out implementations of dependencies at runtime without changing the consumer code.

```lua
-- main.lua
local user_service = require("user_service")

-- Production Context
local prod_ctx = { db = require("pg_driver").connect(), logger = require("file_logger") }

-- Test/Mock Context (Zero overhead mocking)
local mock_ctx = {
    db = { query = function() return { id = 1, name = "Mock" } end },
    logger = { info = function() end }
}

-- The exact same function works with both contexts
user_service.get_user(prod_ctx, 10)
user_service.get_user(mock_ctx, 10)
```

### 5. Asynchronous / Coroutine Context

- In Lua's cooperative multitasking (coroutines), passing a plain table `ctx` is vastly superior to using global state or thread-locals.
- The `ctx` safely travels across `yield` and `resume` boundaries.

```lua
-- worker.lua
local M = {}

function M.process_async(ctx, job_id)
    ctx.logger.info("Starting job " .. job_id)
    coroutine.yield()
    ctx.db.query("UPDATE jobs SET status = 'done' WHERE id = ?", job_id)
end

return M
```

---

## Data Structures Used

1.  **Plain Lua Tables (Hash Maps):** Used exclusively for the `ctx` object and module namespaces. No metatables are attached.
2.  **First-Class Functions:** Functions are treated as standard data types, stored in tables, and passed as arguments.
3.  **Closures:** Used optionally (Implementation 2) to capture the `ctx` reference in the lexical scope.
4.  **Arrays (Sequential Tables):** Used for middleware pipelines and lists of handlers.

---

## Synergistic Patterns

- **The Module Pattern:** PCI is the natural dependency management solution for the standard Lua Module pattern (`local M = {}; return M`).
- **Functional Composition:** Because functions take `ctx` as a uniform first argument, they can be easily composed, mapped, or chained without wrapper objects.
- **Command Pattern:** A "command" is simply a function reference paired with a `ctx` table and specific arguments. This makes queuing background jobs incredibly lightweight.
- **Environment Sandboxing:** The `ctx` table can be passed to `load` or `_ENV` to safely sandbox untrusted code while providing it access to approved dependencies.

---

# Applying PCI to existing projects
- The current architecture of repositories like `echeckers` and `volley` (specifically targeting the Transformice API) relies on specific constraints: Node.js concatenation-based build systems, engine-driven event loops, and strict rules about minimizing function arguments.

## 1. Diagnosing the Current State

### Anti-Pattern A: Data Fragmentation via Scattered Locals (The Upvalue Trap)

- In repositories like `volley` (v2.3.2), the concatenation build system encourages fragmenting state across dozens of scattered `local` tables (e.g., `players`, `playerCanTransform`, `playerForce`, `playerInGame`, `playerPhysicId`, `playerLanguage`) rather than cohesive objects. 
- Match state is similarly scattered across `gameStats`, `teamsScores`, `ballOnGame`, etc.

#### **The Cost:**
- These tables act as implicit upvalues. 
- Every function in the concatenated file can access them without passing them as arguments. 
- While upvalues are fast, this creates massive coupling. 
- You cannot test a function without initializing all parallel tables, and the state is highly prone to desync because related data (e.g., a player's force and their physical ID) is artificially separated.

#### **The API Reality:** 
- In environments like the Transformice API, the engine handles core physics. 
- The Lua API is strictly for game logic and player data manipulation.
- Fragmenting this API-level data across parallel tables makes event bridging (e.g., `eventPlayerDied`) unnecessarily complex.

### Anti-Pattern B: Register Pressure (The "Exponential Cost" of Scattered Arguments)
- The projects correctly identifies that `function f(a,b,c,d)` has an "exponential performance cost" compared to `function f(args)`.

#### **The Lua Reality:** 
- This is not about the cost of moving arguments during a call; it is about **register pressure and stack spilling**.
- Every argument in a signature consumes a CPU register. 
- A function with 6 arguments and 10 locals exhausts registers, forcing the VM to spill variables into the slower call stack. In LuaJIT, this causes trace aborts, tanking performance.

#### **The Fix:**
- Packing dependencies into a single `ctx` table reduces the function signature to exactly 1 register for dependencies, completely satisfying the project's performance rule while allowing cohesive data access.

## 2. Reshaping the Architecture

### The Game Context

- Build **one** context table at startup. 
- This replaces both scattered locals and long argument lists.

```lua
-- context.lua
local function create_game_ctx(config)
    return {
        config     = config,
        rng        = require("systems.rng").new(config.seed),
        rules      = require("rules." .. config.game_mode),
        state      = {
            players = {}, -- Consolidates playerCanTransform, playerForce, etc.
            scores  = { red = 0, blue = 0 },
            turn    = 1,
        },
        systems    = { ui = require("systems.ui") }
    }
end

return create_game_ctx
```

### Stateless Systems, Minimal Signatures
- Every system is a plain table of functions. 
- Notice how we pass `ctx` to satisfy dependency injection, and `time_elapsed` or `player_name` for transient data, keeping the register count extremely low.

```lua
-- systems/game_mode.lua (Transformice/Volley Context)
local M = {}

-- Uses exactly 2 registers: 'ctx' and 'time_elapsed'.
-- Avoids: function tick(time_elapsed, player_list, config, score_table) -> 4 registers!
function M.tick(ctx, time_elapsed)
    for player_name, data in pairs(ctx.state.players) do
        if data.is_infected then
            data.score = data.score - (ctx.config.infection_penalty * time_elapsed)
        end
    end
end

function M.onPlayerDied(ctx, name, player_list)
    local p = ctx.state.players[name]
    if p and not p.is_infected then
        p.is_infected = true
        ctx.systems.ui.show_infection_effect(ctx, name)
    end
end

return M
```

## 3. Mistakes that PCI Prevents

- **Register Exhaustion:**

* `function draw(dt, board, ui, player, config)` caused stack spilling in the hot loop.
* `function draw(ctx, dt)` uses 2 registers.

- **Global/Upvalue state corruption:**

* A debug print accidentally mutated `_G.board` or a scattered local table.
* All state lives in `ctx.state`; functions receive `ctx` explicitly, making reads/writes grep-able.

- **Untestable AI:**

* `ai.lua` read directly from globals/upvalues; couldn't run headless.
* Pass a mock `ctx` with a fixed `rng` seed => deterministic, reproducible AI tests.

- **No replay system:**

* Game state scattered across globals and singletons.
* Snapshot `ctx.state` to disk => replay is just reloading state into a fresh `ctx`.

## 4. Rules for the New Project (Prevention Checklist)

- Enforce these rules from day one to maintain high performance and clean architecture:

### Rule 1: Ban Scattered Dependency Arguments

```lua
-- ❌ BANNED: Causes register pressure and stack spilling
function process_turn(dt, board, player, hand, ui, config) ... end

-- ✅ REQUIRED: PCI minimizes the signature to preserve registers
function process_turn(ctx, dt)
    local board = ctx.state.board
    local player = ctx.state.player
end
```

### Rule 2: Ban Globals After Initialization

```lua
-- ❌ Banned after main.lua finishes booting
Board = {}

-- ✅ Lives in ctx
ctx.state.board = {}
```

### Rule 3: Pure Functions for Rules and AI

- Any function that calculates game logic should take `ctx` and return a value _without mutating `ctx`_.

```lua
-- Pure: Easy to test, no side effects, easily JIT compiled
function M.get_valid_moves(ctx, player_id)
    local moves = {}
    return moves
end
```

### Rule 4: Context Mutation

- Mutations to `ctx.state` should only happen in dedicated "command" or "event handler" functions.
- Pure calculation functions must never mutate the context; they should only read from it and return new values.

```lua
-- ❌ BANNED: Mutating context inside a pure calculation function
function M.calculate_score(ctx, player_id)
    ctx.state.score = ctx.state.score + 10 -- Hidden side effect!
    return ctx.state.score
end

-- ✅ REQUIRED: Pure functions return values; specific mutator functions change state
function M.calculate_score(ctx, player_id)
    return ctx.state.base_score + (ctx.state.multiplier * 10)
end

function M.apply_score(ctx, points)
    ctx.state.score = ctx.state.score + points
end
```

### Rule 5: The "Replay Test" Mandate

Because all state is in `ctx`, writing a replay system or a unit test takes exactly one line of code:

```lua
-- Save replay
table.insert(replay_frames, deep_copy(ctx.state))

-- Load test state
local test_ctx = deep_copy(ctx)
test_ctx.state.board[1] = { unit = "dragon" }
```

### Optional: Native Modules over Concatenation

- Use Lua's native `require()` and `return` statements instead of concatenating files.
- It handles dependency graphs automatically and allows for proper encapsulation.
- If you _must_ use a concatenation build system for deployment, define `local ctx = {...}` at the very top of the bundle so all subsequent functions can access it as an upvalue, but still pass it explicitly as an argument to maintain testability.

---

## 5. References

- **Codebase Architecture Review:** Analysis of `vit0rg/volley` (v2.3.2) and `vit0rg/echeckers` repositories, focusing on concatenation-based build systems, data fragmentation via scattered locals, and the Upvalue Trap.
- **Transformice API Constraints:** Native engine lifecycle (`eventLoop`, `event*` callbacks) and the strict separation of engine physics vs. Lua game logic/player data manipulation.
- **Lua/LuaJIT VM Internals:** Understanding register pressure, stack spilling, trace aborts, and opcode costs (`GETTABUP` vs local/upvalue lookups).
- **Design Patterns:** GoF (Gang of Four) patterns adapted for procedural Lua (Module Pattern, Command Pattern, Strategy Pattern).
- **Architecture Theory:** Application of the 5 Tiers of Architecture Theory, specifically scoping PCI as a Tier 4 (Subsystem) implementation to prevent "God Context" anti-patterns.
