# Timer System Study Case: `original_algorithm.lua` vs `overengineered_algorithm.lua`

**Author**: Vit0rg
**Created:** May 29th 2026
**Document last updated:** June 22nd 2026
**License**: MIT
---

## Table of Contents

1. [Contextual Profile and Analysis](#1-contextual-profile-and-analysis)  
   1.1 [Project Context](#11-project-context)  
   1.2 [Technical Stack](#12-technical-stack)  
   1.3 [Structural Profile](#13-structural-profile)  
2. [Core Design Philosophy](#2-core-design-philosophy)  
   2.1 [`original_algorithm.lua`: Performance via Pooling & Array Iteration](#21-original_algorithmlua-performance-via-pooling--array-iteration)  
   2.2 [`overengineered_algorithm.lua`: Usability via String Labels & Dictionary Storage](#22-overengineered_algorithmlua-usability-via-string-labels--dictionary-storage)  
3. [Creator-Found Problems](#3-creator-found-problems)  
   3.1 [Critical Bugs](#31-critical-bugs)  
   3.2 [Practical Problems](#32-practical-problems)  
   3.3 [Performance Issues](#33-performance-issues)  
4. [Architectural Flaws](#4-architectural-flaws)  
   4.1 [The "Hybrid Identity Crisis" Anti-Pattern](#41-the-hybrid-identity-crisis-anti-pattern)  
   4.2 [Scattered State & Hot-Path Allocations](#42-scattered-state--hot-path-allocations)  
   4.3 [Bytecode Bloat & Interpreter Overhead](#43-bytecode-bloat--interpreter-overhead)  
5. [Synthesis: The Ideal Hybrid](#5-synthesis-the-ideal-hybrid)  
6. [Appendix: Reference Implementation Sketch](#6-appendix-reference-implementation-sketch)  

---

## 1. Contextual Profile and Analysis

### 1.1 Project Context

- **"Timer Module"** 
- A reusable timer/dispatch system for Transformice Lua environments, designed to schedule callbacks with millisecond precision, support looping, pause/resume, and label-based identification.
- The `original_algorithm.lua` represents a **performance-first** implementation focused on GC avoidance and interpreter execution speed (~2-3 hours of focused development).
- The `overengineered_algorithm.lua` represents a **usability-first** iteration that prioritizes developer ergonomics (string labels, simpler API) but regresses significantly on runtime performance characteristics.
- Both implementations target the same functional requirements but embody fundamentally different architectural trade-offs within the strict constraints of a pure Lua 5.1 interpreter.

### 1.2 Technical Stack

| Component | Specification |
|-----------|--------------|
| **Runtime** | Transformice Module API: **Standard Lua 5.1 Interpreter** (Sandboxed, No JIT) |
| **Tick Resolution** | 500ms server delay (`SERVER_DELAY = 500`) |
| **GC Constraints** | Lua 5.1 uses a **non-incremental, mark-and-sweep GC**. High-frequency table allocation/deallocation triggers "Stop-the-World" pauses, causing severe UPS degradation. |
| **Desync Sensitivity** | Numerical table indices risk access and removal collisions; string namespaces are isolated and safe. |
| **Optimization Targets** | Flat GC profile (zero hot-path allocations), minimizing interpreter dispatch overhead, O(1) safe removal during iteration. |

### 1.3 Structural Profile

| Metric | `original_algorithm.lua` | `overengineered_algorithm.lua` |
|--------|-------------------------|-------------------------------|
| **Total Lines** | ~110 lines (dense) | ~95 lines (flatter) |
| **Nesting Depth** | 5 levels in `timersLoop` (deep if-chain) | 3 levels + `repeat/until` hack |
| **Global/Implicit State** | `timerList`, `timersPool`, `List.*` | `timersList`, `_toRemove` (re-allocated per tick) |
| **Iteration Strategy** | Numerical array: `for id = 1, #timerList do` | Hash-table: `for label, timer in pairs(timersList) do` |
| **Object Allocation** | Pooled: reuses state objects via `List` stack | Eager: `timersList[label] = {}` on add, `= nil` on remove |
| **Label Lookup Cost** | O(n) linear scan in `getTimerId` | O(1) direct hash access |
| **Control Flow** | Standard nested `if` statements | `repeat ... until true` with `do break end` |

---

## 2. Core Design Philosophy

### 2.1 `original_algorithm.lua`: Performance via Pooling & Array Iteration

- **Object Pooling as First-Class Concern**: 
- The custom `List` doubly-linked list acts as a stack for freed timer IDs.
- When a timer is removed, its numerical ID is returned to `timersPool`; when a new timer is added, it reuses an ID and its associated state table. 
- This completely eliminates per-tick table allocations, keeping the Lua 5.1 GC idle.

- **Array-Part Iteration for Interpreter Speed**: 
- The main loop iterates numerically (`for id = 1, #timerList do`). 
- In Lua 5.1, iterating over the array part of a table via integer indices is significantly faster than hash traversal, as it relies on direct memory offset calculations rather than following hash bucket pointers.

- **Numerical IDs as Primary Key**: 
- Timers are stored and accessed by integer index.
- String labels are secondary metadata, requiring O(n) lookup via `getTimerId`.

### 2.2 `overengineered_algorithm.lua`: Usability via String Labels & Dictionary Storage

- **String Labels as Primary Key**: 
- Timers are stored directly in a hash table: `timersList[label] = state`.
- This makes the API intuitive (`pauseTimer("mySkillCooldown")`) and avoids numerical ID mapping.

- **Dictionary Iteration with Safe Removal**:
- Uses `pairs(timersList)` for iteration. 
- In Lua 5.1, `pairs()` must traverse the hash part of the table, which incurs higher interpreter overhead per element compared to array iteration.
- A `_toRemove` buffer array collects labels for post-iteration cleanup.

- **Control-Flow Hack for "Continue"**: 
- The `repeat ... until true` block with `do break end` simulates a `continue` statement.
- While clever, this generates extra bytecode (JMP instructions) that the Lua 5.1 VM must interpret, adding unnecessary CPU cycles in a hot loop.

---

## 3. Creator-Found Problems

### 3.1 Critical Bugs

#### 3.1.1 Desync Risk in `original_algorithm.lua` (Numerical ID Collision)
- **Problem**: 
- The system stores timers in `timerList[id]` where `id` is a sequential integer.
- In Transformice, other players access or the engine itself may manipulate numerical indices in shared tables, risking accidental overwrites.

- **Impact**:
- A timer could be silently corrupted or skipped if an external script writes to `timerList[5]`.

- **Root Cause**: 
- Numerical indices are not namespace-isolated; string keys provide a safe, collision-resistant namespace.

#### 3.1.2 GC Churn in `overengineered_algorithm.lua` (No Pooling)
- **Problem**: 
- Every `addTimer` call allocates a new table (`timersList[label] = {}`), and every `removeTimer` sets it to `nil`. 
- **Impact**:
- Lua 5.1's mark-and-sweep GC will trigger "Stop-the-World" pauses when the memory threshold is hit. 
- In a game loop with frequent timer churn, this causes massive, unpredictable UPS drops.

- **Root Cause**: 
- Prioritizing API simplicity over memory management discipline.

### 3.2 Practical Problems

#### 3.2.1 Label Lookup Cost in `original_algorithm.lua`
- **Problem**: 
- `getTimerId(label)` performs a linear scan: `for id = 1, #timerList do ...`. This is O(n) per lookup.

- **Impact**: 
- If a script frequently resolves labels to IDs, interpreter overhead degrades performance as the timer count grows.

- **Mitigation**:
- Maintain a secondary `labelToId` hash table (O(1) lookup) while keeping the primary `timerList` as a numerical array.

#### 3.2.2 Hot-Path Allocation in `overengineered_algorithm.lua`
- **Problem**:
- Inside `timersLoop()`, the code declares `local _toRemove = {}`.

- **Impact**:
- This creates a **new table allocation every single 500ms tick**, regardless of whether any timers actually complete.
-  This guarantees continuous GC pressure and is a critical anti-pattern in Lua 5.1.

- **Root Cause**:
- Lack of awareness regarding how local variable initialization inside frequently called functions interacts with the GC.

### 3.3 Performance Issues

#### 3.3.1 UPS Degradation Under Load

| Scenario | `original_algorithm.lua` | `overengineered_algorithm.lua` |
|----------|-------------------------|-------------------------------|
| **100 active timers, 10 ticks/sec** | Stable UPS (GC remains idle) | Periodic UPS stutters (GC triggered by `_toRemove` & state churn) |
| **500 timers, frequent add/remove** | Flat GC profile (pool hit rate >90%) | Severe GC spikes (constant table creation/destruction) |
| **Loop Interpretation Overhead** | Low (Standard `for` loop) | High (`pairs()` hash traversal + `repeat/break` bytecode bloat) |

- **Root Cause**:
- `original_algorithm.lua` trades lookup speed for iteration speed and GC stability; 
- `overengineered_algorithm.lua` suffers from both hash traversal overhead and continuous GC churn.

---

## 4. Architectural Flaws

### 4.1 The "Hybrid Identity Crisis" Anti-Pattern

- **Both files** attempt to serve two masters: performance *and* usability, but each leans too far in one direction.

- `original_algorithm.lua` optimizes for the VM (pooling, array iteration) but burdens the developer with numerical IDs and O(n) label lookups.
- `overengineered_algorithm.lua` optimizes for the developer (string labels, simple API) but burdens the Lua 5.1 interpreter with GC churn, hash traversal costs, and bytecode bloat.

### 4.2 Scattered State & Hot-Path Allocations

- **`original_algorithm.lua`**: 
- The `clearTimers` function uses a `repeat/until` loop that calls `table.remove(timerList, timer)`. 
- In Lua 5.1, `table.remove` on an array shifts all subsequent elements down, making this an **O(N^2)** operation.

- **`overengineered_algorithm.lua`**: 
- As noted, `local _toRemove = {}` inside `timersLoop` is a hidden allocation.
- State lives in `timersList` (hash) and this temporary buffer, making lifecycle transitions harder to reason about and garbage to manage.

### 4.3 Bytecode Bloat & Interpreter Overhead

>  Neither file uses flat, guard-style checks at the top of the loop body. 

- `overengineered_algorithm.lua` uses the `repeat ... until true` with `do break end` hack. 
- In Lua 5.1 bytecode, this generates unnecessary `JMP` instructions and loop condition checks that the interpreter must evaluate on every iteration. 
- **Why this matters**: 
- Without a JIT compiler to optimize away redundant jumps, the Lua 5.1 VM must interpret every single bytecode instruction.
- Bloated control flow directly increases the CPU time required per tick.

---

## 5. Synthesis: The Ideal Hybrid

- A production-ready timer system for Transformice must respect the realities of the **Lua 5.1 interpreter** and its **non-incremental GC**. It should combine:

1. **String-label primary API** (desync-safe, developer-friendly).
2. **Object pooling via simple stack** (use `pool[#pool+1] = state` / `state = pool[#pool]; pool[#pool] = nil`). This is mandatory to prevent Lua 5.1 GC pauses.
3. **Numerical array for iteration** (`activeIds` array) + **hash for label lookup** (`labelToId`). Array iteration is faster for the interpreter to process than `pairs()` hash traversal.
4. **Flat, guard-based loop** (avoids `repeat/break` bytecode bloat):
   ```lua
   for i = #activeIds, 1, -1 do
       local id = activeIds[i]
       local t = timers[id]
       if not t then -- stale ref cleanup end
       if not t.enabled or t.paused or t.done then -- skip end
       -- hot path: linear, no nesting, minimal bytecode
   end
   ```
5. **Backwards iteration with swap-pop removal** for O(1) safe deletion during loop, avoiding `table.remove` O(N) shifts.

---

## 6. Appendix: Reference Implementation Sketch

```lua
-- tfm_lua51_hybrid_timer.lua (conceptual sketch)
local timers = {}          -- { [id] = state }
local labelToId = {}       -- { [label] = id }
local activeIds = {}       -- [1] = id1, [2] = id2, ...
local pool = {}            -- stack of reusable state objects

local function acquire()
    local n = #pool
    if n > 0 then
        local t = pool[n]
        pool[n] = nil
        return t
    end
    return {}
end

local function release(t)
    -- clear fields to prevent memory leaks in pooled objects
    for k in pairs(t) do t[k] = nil end
    pool[#pool + 1] = t
end

function addTimer(callback, ms, loops, label, ...)
    if labelToId[label] then return nil end
    local id = acquire()
    -- initialize id (or use a separate state table if id is just an index)
    -- For simplicity, assuming id is the table itself or maps to one
    -- ...
    labelToId[label] = id
    activeIds[#activeIds + 1] = id
    return label
end

function timersLoop()
    -- Backwards iteration allows O(1) swap-pop removal
    for i = #activeIds, 1, -1 do
        local id = activeIds[i]
        local t = timers[id]
        
        -- Flat guard clauses (minimal bytecode, no repeat/break hacks)
        if not t then
            activeIds[i] = activeIds[#activeIds]
            activeIds[#activeIds] = nil
        elseif t.enabled and not t.paused and not t.done then
            t.curTime = t.curTime + 500
            if t.curTime >= t.time then
                -- trigger logic...
            end
        end
    end
end
```

> **Note**: This sketch omits error handling and edge cases for brevity. A production version would ensure the `id` mapping correctly handles the pool without creating new tables, strictly adhering to the zero-allocation rule for the Lua 5.1 GC.

---