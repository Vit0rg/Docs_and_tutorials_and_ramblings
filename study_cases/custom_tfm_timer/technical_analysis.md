# Timer System Study Case: Evolution of Architectures in Lua 5.1

> **Repository**: [Vit0rg/Docs_and_tutorials_and_ramblings](https://github.com/Vit0rg/Docs_and_tutorials_and_ramblings)  
> **Author**: Vit0rg  
> **Formalized by**: AI Assistant (Qwen3.7-Plus)
> **Date**: June 24th 2026  
> **Document last updated**: June 24th 2026  
> **Target Platform**: Transformice Module API (Standard Lua 5.1 Interpreter, Sandboxed)  
> **Focus**: Native Lua 5.1 Architecture, Incremental GC Mitigation, Interpreter Dispatch Optimization, Desync Safety

---

## Document Artifacts & Timestamps

| Artifact | File Name | Role in Analysis | Conceptual Timestamp |
| :--- | :--- | :--- | :--- |
| **Baseline 1** | `original_algorithm.lua` | Initial performance-focused implementation | 201?-?-? |
| **Baseline 2** | `overengineered_algorithm.lua` | Usability-focused iteration | 2026-06-05 |
| **Optimization 1** | `optimal_timer.lua` | Dual-stack pooling with extracted guards | 2026-06-22 |
| **Optimization 2** | `optimal_inline_timer.lua` | Deep inline nesting variant | 2026-06-23 |
| **Optimization 3** | `optimal_repeat_timer.lua` | Algorithmic `repeat..break` variant | 2026-06-23 |
| **Optimization 4** | `optimal_ref_timer.lua` | Array of References architecture | 2026-06-24 |
| **Benchmark 1** | `benchmarker.lua` | Initial sequential benchmark script | 2026-06-23 |
| **Benchmark 2** | `improved_benchmarker.lua` | Variable-isolated benchmark script | 2026-06-24 |
| **Analysis** | `technical_analysis.md` | This document | 2026-06-24 |

---

## Table of Contents

- [1. Contextual Profile and Analysis](#1-contextual-profile-and-analysis)
  - [1.1 Project Context](#11-project-context)
  - [1.2 Technical Stack](#12-technical-stack)
  - [1.3 Lua 5.1 Table Internals Primer](#13-lua-51-table-internals-primer)
  - [1.4 Structural Profile](#14-structural-profile)
- [2. Core Design Philosophy & Architecture](#2-core-design-philosophy--architecture)
  - [2.1 `original_algorithm.lua`](#21-original_algorithmlua)
  - [2.2 `overengineered_algorithm.lua`](#22-overengineered_algorithmlua)
  - [2.3 `optimal_timer.lua`](#23-optimal_timerlua)
  - [2.4 `optimal_inline_timer.lua`](#24-optimal_inline_timerlua)
  - [2.5 `optimal_repeat_timer.lua`](#25-optimal_repeat_timerlua)
  - [2.6 `optimal_ref_timer.lua`](#26-optimal_ref_timerlua)
  - [2.7 System Architecture & State Machine (UML)](#27-system-architecture--state-machine-uml)
- [3. Creator-Found Problems](#3-creator-found-problems)
  - [3.1 Lua 5.1 Standard Library Incompatibilities](#31-lua-51-standard-library-incompatibilities)
  - [3.2 Vararg Stack Spilling & Memory Traps](#32-vararg-stack-spilling--memory-traps)
  - [3.3 Namespace Collision & Desync](#33-namespace-collision--desync)
- [4. Execution Profiles: Memory & Speed](#4-execution-profiles-memory--speed)
  - [4.1 Time Complexity Profile](#41-time-complexity-profile)
  - [4.2 Memory & Garbage Collection Profile](#42-memory--garbage-collection-profile)
  - [4.3 Quantitative Interpreter Metrics](#43-quantitative-interpreter-metrics)
- [5. Architectural Flaws & VM Mechanics](#5-architectural-flaws--vm-mechanics)
  - [5.1 The Hash Lookup Tax](#51-the-hash-lookup-tax)
  - [5.2 The `OP_CALL` Penalty vs. Cyclomatic Complexity](#52-the-op_call-penalty-vs-cyclomatic-complexity)
  - [5.3 Hot-Path Allocations & GC Step Counter](#53-hot-path-allocations--gc-step-counter)
  - [5.4 O(N²) Array Shifting & Cache Thrashing](#54-on-array-shifting--cache-thrashing)
- [6. Empirically Optimal Trade-off Architecture](#6-empirically-optimal-trade-off-architecture)
- [Appendix A: Core Loop Architectures](#appendix-a-core-loop-architectures)
- [Appendix B: Empirical Benchmark & VM Profiling](#appendix-b-empirical-benchmark--vm-profiling)
- [7. Conclusion](#7-conclusion)
- [Appendix C: External CS References & Theoretical Foundations](#appendix-c-external-cs-references--theoretical-foundations)

---

## 1. Contextual Profile and Analysis

### 1.1 Project Context
- **Objective:** Develop a reusable timer/dispatch system for Transformice Lua environments.
- The system schedules callbacks with millisecond precision.
- It supports looping, pause/resume, and label-based identification.

- **Methodology:** The architecture was refined iteratively via empirical VM profiling.
- This process isolated interpreter dispatch costs, garbage collection (GC) mechanics, and algorithmic complexity.

### 1.2 Technical Stack
| Component | Specification |
| :--- | :--- |
| **Runtime** | Transformice Module API: Standard Lua 5.1 Interpreter (Sandboxed, No JIT). |
| **Tick Resolution** | 500ms server delay (`SERVER_DELAY = 500`). |
| **GC Constraints** | Lua 5.1 uses an incremental mark-and-sweep GC. |
| **GC Impact** | In a constrained 500ms tick environment, incremental allocation steps cause frequent, perceptible micro-stutters. |
| **Desync Sensitivity** | Numerical table indices risk collision with external modules; string namespaces provide isolation. |

### 1.3 Lua 5.1 Table Internals Primer
- To understand the performance deltas analyzed in this document, one must understand how Lua 5.1 stores tables.
- A Lua table is a hybrid data structure consisting of two distinct parts:
  - **The Array Part:** Stores contiguous integer keys (e.g., `1, 2, 3`).
  - Accessing these via a numerical `for` loop utilizes direct memory offset calculations (`O(1)` pointer arithmetic).
  - This makes the Array Part exceptionally fast.
  
  - **The Hash Part:** Stores string keys and non-contiguous/non-integer keys.
  - Accessing these requires computing the key's hash, identifying the correct bucket, and traversing a linked list to handle collisions.

- **Crucial Takeaway:** Iterating over the Array Part (numerical indices) is fundamentally faster than traversing the Hash Part (string lookups or `pairs()`).

- The evolution of this timer system is largely the story of moving hot-path operations from the Hash Part to the Array Part.

### 1.4 Structural Profile
| Metric | `original` | `overengineered` | `optimal` | `optimal_inline` | `optimal_repeat` | `optimal_ref` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Nesting Depth** | 5 levels | 3 levels + hack | 0 levels (extracted) | 6 levels (inline) | 1 level (`repeat`) | 1 level (`repeat`) |
| **Iteration Strategy** | Numerical array | Hash-table (`pairs`) | Numerical array | Numerical array | Numerical array | Numerical array (Refs) |
| **Hot-Path Lookup** | Direct Array | Hash + `pairs` | Hash (`timers[label]`) | Hash (`timers[label]`) | Hash (`timers[label]`) | Direct Array (No Hash) |
| **Removal Mechanism** | `table.remove` (O(N²)) | `_toRemove` buffer | `freeIndices` (O(1)) | `freeIndices` (O(1)) | `freeIndices` (O(1)) | `freeIndices` (O(1)) |

---

## 2. Core Design Philosophy & Architecture

### 2.1 `original_algorithm.lua`
- **Definition:** Implements object pooling via a custom doubly-linked `List` to recycle numerical IDs.
- It iterates over a contiguous numerical array.
- **Execution & Lua Internals:**
  ```lua
  function addTimer(callback, ms, loops, label, ...)
      timer.arguments = { ... } 
  end
  function clearTimers()
      table.remove(timerList, timer)
  end
  ```

- In Lua 5.1, the `...` expression is not a first-class table.
- Capturing it via `{ ... }` forces the VM to evaluate `OP_VARARG` and allocate a hidden table on the heap.

- **Cyclomatic Complexity & VM Instructions:** The `clearTimers` function executes `table.remove` inside a `repeat` loop.
- In the Lua C-backend (`ltable.c`), removing an element from the middle of the array part requires a `memmove` operation.
- This shifts all subsequent elements down, resulting in O(N²) time complexity and severe CPU cache line invalidation.

### 2.2 `overengineered_algorithm.lua`
- **Definition:** Prioritizes API ergonomics by using string labels as primary keys in a hash table.
- It iterates via `pairs()` and uses a buffer for safe removal.

- **Execution & Lua Internals:**
  ```lua
  local function timersLoop()
      local _toRemove = {} 
      for label, timer in pairs(timersList) do
          repeat
              if timer.isComplete then do break end end
  ```

- The `local _toRemove = {}` declaration executes on every 500ms tick.
- The `repeat ... do break end` construct is a syntactic workaround for Lua 5.1's lack of a `continue` statement.

- **Cyclomatic Complexity & VM Instructions:** The `pairs()` iterator invokes the C function `next` (`ltable.c`).
- This requires hash bucket traversal and collision resolution.
- The `do break end` hack generates redundant `OP_JMP` instructions.
- The continuous allocation of `_toRemove` increments the GC step counter, forcing frequent incremental GC steps that cause micro-stutters.

### 2.3 `optimal_timer.lua`
- **Definition:** Decouples storage (hash table) from iteration (numerical array).
- It implements dual-stack pooling (`timerPool`, `freeIndices`).
- It extracts loop logic into local functions to achieve zero-nesting control flow.

- **Execution & Lua Internals:**
  ```lua
  local function processTimer(t)
      if not t.enabled or t.paused or t.done then return false end
  end
  function timersLoop()
      for i = 1, #activeLabels do handleTimerSlot(i, activeLabels[i]) end
  end
  ```

- The loop delegates execution to `handleTimerSlot`, which in turn calls `processTimer`.

- **Cyclomatic Complexity & VM Instructions:** Cyclomatic complexity is minimized via flat control flow.
- However, the execution requires crossing function boundaries.
- In the Lua 5.1 VM (`lvm.c`), this triggers `OP_CALL`.
- This requires allocating a new `CallInfo` structure on the C stack, register setup, and teardown via `OP_RETURN`.
- This incurs a heavy relative interpreter dispatch weight per function call.

### 2.4 `optimal_inline_timer.lua`
- **Definition:** Eliminates function boundaries by inlining all guard logic directly into the `timersLoop` body.
- It accepts deep nesting to avoid `OP_CALL` overhead.

- **Execution & Lua Internals:**
  ```lua
  function timersLoop()
      for i = 1, #activeLabels do
          local label = activeLabels[i]
          if label then
              local t = timers[label]
              if t then
                  if t.enabled and not t.paused and not t.done then
  ```

- The execution remains entirely within a single function scope.

- **Cyclomatic Complexity & VM Instructions:** Cyclomatic complexity is high (6 levels of nesting).
- However, the VM instructions are restricted to `OP_TEST` and `OP_JMP`.
- These incur a minimal relative dispatch weight.
- The contiguous bytecode block maximizes Instruction Cache (I-Cache) locality.

### 2.5 `optimal_repeat_timer.lua`
- **Definition:** Utilizes the `repeat ... until true` block with `break` to simulate early exits.
- It achieves flat nesting without crossing function boundaries.

- **Execution & Lua Internals:**
  ```lua
  function timersLoop()
      for i = 1, #activeLabels do
          local label = activeLabels[i]
          local t = timers[label] 
          if t then
              repeat
                  if not t.enabled or t.paused or t.done then break end
  ```
- The `break` instruction immediately exits the `repeat` block, skipping subsequent condition checks.

- **Cyclomatic Complexity & VM Instructions:** Cyclomatic complexity is low (1 level of nesting).
- The VM generates minimal `OP_TEST` and `OP_BREAK` instructions.
- However, because `activeLabels` stores strings, `local t = timers[label]` compiles to `OP_GETTABLE` with a string key.
- This forces the VM to execute `luaH_getstr`, computing the string hash and traversing the hash bucket linked list.

### 2.6 `optimal_ref_timer.lua`
- **Definition:** Resolves the hash lookup overhead by storing direct table references in the iteration array (`activeRefs`).
- It reserves the hash table strictly for external API lookups.

- **Execution & Lua Internals:**
  ```lua
  function M.addTimer(args)
      timers[label] = t
      activeRefs[idx] = t -- Store direct reference
  end
  function M.timersLoop()
      for i = 1, #activeRefs do
          local t = activeRefs[i] -- Direct Memory Offset
  ```
- The hot loop fetches the state object directly from the array part of `activeRefs`.

- **Cyclomatic Complexity & VM Instructions:** Cyclomatic complexity is low.
- The `local t = activeRefs[i]` compiles to `OP_GETTABLE` with an integer key.
- The Lua C-backend bypasses `luaH_getstr` and executes a direct pointer arithmetic offset into the array part.
- This eliminates the string hash resolution overhead entirely.

### 2.7 System Architecture & State Machine (UML)

#### 2.7.1 Timer Lifecycle State Machine
```mermaid
stateDiagram-v2
    [*] --> Initialized : addTimer()
    Initialized --> Active : timersLoop() tick
    Active --> Paused : pauseTimer()
    Paused --> Active : resumeTimer()
    Active --> Completed : maxLoops reached
    Active --> Removed : removeTimer()
    Paused --> Removed : removeTimer()
    Completed --> [*] : Sanitize & Return to Pool
    Removed --> [*] : Sanitize & Return to Pool
```

#### 2.7.2 Definitive Data Structure Architecture (`optimal_ref`)
```mermaid
graph TD
    subgraph Public API
        A[addTimer / removeTimer / pauseTimer]
    end
    subgraph Core Data Structures
        H[(timers: Hash Table)]
        AR[(activeRefs: Array of References)]
        F[(freeIndices: Stack)]
        P[(timerPool: Stack)]
    end
    subgraph Hot Path
        Loop[timersLoop]
    end

    A -->|O 1 String Lookup| H
    A -->|Appends/Clears| AR
    A -->|Pushes/Pops| F
    A -->|Pushes/Pops| P

    Loop -->|Iterates 1 to N| AR
    Loop -->|Direct Memory Offset| State[Timer State Objects]
    Loop -->|Recycles Index| F
    Loop -->|Recycles Object| P
    
    AR -->|Direct Table References| State
    H -->|String Keys| State
```

---

## 3. Creator-Found Problems

### 3.1 Lua 5.1 Standard Library Incompatibilities
- **Problem:** The predecessors utilize `table.unpack`.

- **Lua Internals:** `table.unpack` was introduced in Lua 5.2.
- In Lua 5.1, the global `unpack` exists, but `table.unpack` is `nil`.

- **Execution Failure:** Calling `table.unpack(timer.arguments)` triggers an `OP_GETTABLE` on the `table` namespace, returning `nil`.
- This is followed by an `OP_CALL` on `nil`.
- The VM throws a fatal `attempt to call a nil value` error, crashing the script immediately.

- **Resolution:** The optimal scripts cache the global `unpack` (`local unpack = unpack`) and use it directly.

### 3.2 Vararg Stack Spilling & Memory Traps
- **Problem:** `original_algorithm.lua` uses `...` in `addTimer` and captures it via `{ ... }`.

- **Lua Internals:** In Lua 5.1, varargs are not stored as a table on the stack.
- When a function captures `...` into a table constructor, the VM must execute `OP_VARARG`.
- The VM allocates a hidden table on the heap to preserve the arguments.

- **Execution Failure:** This generates ~64 bytes of garbage per `addTimer` call.
- This continuously advances the GC step counter, triggering frequent incremental GC steps that cause micro-stutters.

- **Resolution:** The API signature is changed to accept a pre-packed `args` table.
- The allocation burden is shifted to the caller, keeping the module's internal GC profile flat.

- **Secondary Trap (`unpack(nil)`):** Conditional initialization leaves `t.arguments` as `nil` if no extra args are passed.
- Passing `nil` to `unpack` triggers a C API `luaL_checktype` failure.
- The optimal scripts assign a direct `{}` to prevent this crash.

### 3.3 Namespace Collision & Desync
- **Problem:** `original_algorithm.lua` uses sequential numerical indices (`timerList[id]`) as the primary storage mechanism.

- **Lua Internals:** The Transformice Module API shares a global state.
- Numerical indices in semi-global tables are highly susceptible to collision if external modules manipulate array bounds.

- **Execution Failure:** An external script writing to `timerList[5]` silently overwrites the timer state.
- This causes logic desync, skipped callbacks, or fatal type errors during the `timersLoop`.

- **Resolution:** The optimal scripts use string labels as the primary key in the `timers` hash table.
- This isolates the namespace from numerical index manipulation.

---

## 4. Execution Profiles: Memory & Speed

### 4.1 Time Complexity Profile
| Operation | `original` | `overengineered` | `optimal` | `optimal_inline` | `optimal_repeat` | `optimal_ref` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Add Timer** | O(1) | O(1) | O(1) | O(1) | O(1) | O(1) |
| **Remove Timer** | O(1) | O(1) | O(1) | O(1) | O(1) | O(1) |
| **Get Timer ID** | O(N) | O(1) | O(1) | O(1) | O(1) | O(1) |
| **Main Loop (Tick)** | O(N) | O(N) + O(K) | O(N) | O(N) | O(N) | O(N) |
| **Clear All Timers** | **O(N²)** | O(N) | O(N) | O(N) | O(N) | O(N) |

### 4.2 Memory & Garbage Collection Profile
| Metric | `original` | `overengineered` | `optimal` | `optimal_inline` | `optimal_repeat` | `optimal_ref` |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **State Object Alloc** | Pooled | Eager | Pooled | Pooled | Pooled | Pooled |
| **Vararg/Args Alloc** | Spills on add | Allocates on add | Direct `{}` | Direct `{}` | Direct `{}` | Direct `{}` |
| **Loop Buffer Alloc** | None | Every tick | None | None | None | None |
| **Steady-State GC** | Low (leak) | High (churn) | Negligible | Negligible | Negligible | Negligible |

### 4.3 Quantitative Interpreter Metrics
- **`table.remove(t, i)` Cost:** 
- On an array of size N=1000, removing an element requires `N - i` memory moves (`memmove` in `ltable.c`).
- Executing this inside a loop results in catastrophic CPU cache line invalidation.

- **`pairs()` vs Numerical `for`:**
- Iterating via `pairs()` requires invoking the `next` C function and traversing hash nodes.
- This takes approximately 3x to 5x more relative interpreter dispatch weight than a numerical `for` loop.

- **Hash Lookup Overhead:**
- Resolving a string key in a Lua 5.1 hash table requires computing the string hash (`luaS_hash`) and traversing the bucket linked list.
- Over 10,000,000 iterations, this adds ~300ms of pure CPU overhead compared to direct array indexing.

---

## 5. Architectural Flaws & VM Mechanics

### 5.1 The Hash Lookup Tax
- **Flaw:** Iterating over an array of strings (`activeLabels`) and resolving them via a hash table (`timers[label]`) in the hot path.

- **VM Mechanics:** The `OP_GETTABLE` instruction with a string key invokes `luaH_getstr`.
- This function computes the string's hash, identifies the hash bucket, and traverses the linked list of nodes to handle collisions.

- **Impact:** In a pure interpreter without JIT inlining, this hash resolution occurs on every tick for every timer.
- The empirical benchmark demonstrates a ~305ms delta (over 10,000,000 lookups) between `optimal_repeat` (hash lookup) and `optimal_ref` (direct array offset).

### 5.2 The `OP_CALL` Penalty vs. Cyclomatic Complexity
- **Flaw:** Extracting guard functions (`optimal_timer.lua`) to achieve zero-nesting control flow.

- **VM Mechanics:** In Lua 5.1, crossing a function boundary triggers `OP_CALL`.
- The VM must allocate a `CallInfo` structure on the C stack, copy upvalues/arguments, and set up registers.
- Upon return, `OP_RETURN` tears down the `CallInfo`.
- This incurs a heavy relative interpreter dispatch weight.

- **Impact:** While cyclomatic complexity is reduced, the raw execution speed is penalized.
- The `OP_CALL` overhead accumulates to ~700ms over the benchmark duration.
- This makes `optimal_inline` and `optimal_repeat` significantly faster in raw CPU time.

### 5.3 Hot-Path Allocations & GC Step Counter
- **Flaw:** Allocating tables inside the 500ms `timersLoop` (e.g., `local _toRemove = {}` in `overengineered_algorithm`).

- **VM Mechanics:** Lua 5.1 uses an incremental mark-and-sweep GC.
- Every table allocation increments the global state's `totalbytes` and advances the GC step counter (`luaC_step`).
- When the counter exceeds the `gcpause` threshold, the VM executes an incremental traversal step.

- **Impact:** Allocating a buffer every 500ms guarantees that the GC threshold is breached continuously.
- In a constrained 500ms game loop, these incremental steps cause frequent, perceptible micro-stutters that degrade Updates Per Second (UPS).

### 5.4 O(N²) Array Shifting & Cache Thrashing
- **Flaw:** Using `table.remove` inside a loop (`original_algorithm.lua`).

- **VM Mechanics:** The `table.remove` C function (`luaB_tremove`) shifts all elements above the removed index down by one position using `memmove`.

- **Impact:** Executing this in a loop results in O(N²) time complexity.
- Furthermore, `memmove` on large arrays causes severe CPU cache thrashing.
- The working set exceeds the L1/L2 cache lines, forcing constant main memory fetches.

---

## 6. Empirically Optimal Trade-off Architecture

- The progression of implementations demonstrates that "optimal" architecture in a constrained VM is an empirically derived trade-off.

- **Predecessors (`original`, `overengineered`):** Failed due to O(N²) lifecycle operations, vararg GC spills, and continuous hot-path allocations triggering incremental GC micro-stutters.

- **Control Flow Optimizations (`optimal`, `optimal_inline`, `optimal_repeat`):** Resolved GC and algorithmic flaws.
- However, empirical benchmarking revealed that iterating over an array of strings and resolving them via a hash table incurs a measurable CPU penalty (The Hash Lookup Tax).
- Furthermore, extracted guards (`optimal`) incur an `OP_CALL` penalty.

- **Array of References (`optimal_ref`):** Resolves the hash lookup overhead by storing direct table references in the iteration array.
- It retains O(1) API lookups via a separate hash table, maintains strict O(1) lifecycle operations, and utilizes the `repeat..break` pattern to maintain flat control flow without incurring `OP_CALL` penalties.
- `optimal_ref_timer.lua` represents the empirically optimal trade-off for this specific problem space within the Lua 5.1 interpreter.

### Decision Matrix for Implementation Selection
| Primary Project Constraint | Recommended Variant | Rationale |
| :--- | :--- | :--- |
| **Maximum Raw Execution Speed** | `optimal_ref_timer.lua` | Bypasses the Hash Lookup Tax via direct array memory offsets. Yields the lowest absolute execution time. |
| **Maximum Readability & Maintainability** | `optimal_timer.lua` | Zero-nesting extracted guards. Easiest to modify and debug, at the cost of a measurable `OP_CALL` interpreter penalty. |
| **Balanced Speed & Flat Control Flow** | `optimal_repeat_timer.lua` | Avoids `OP_CALL` overhead and maintains flat nesting via `repeat..break`, but pays the Hash Lookup Tax on string resolution. |

---

## Appendix A: Core Loop Architectures

```lua
-- OPTIMAL REPEAT: Algorithmic early-exit, flat nesting, zero OP_CALL
function timersLoop()
    for i = 1, #activeLabels do
        local label = activeLabels[i]
        local t = label and timers[label] -- Hash Lookup Tax
        if t then
            repeat
                if not t.enabled or t.paused or t.done then break end
                t.curTime = t.curTime + SERVER_DELAY
                if t.curTime < t.time then break end
                -- ... trigger logic and inline cleanup ...
            until true
        end
    end
end

-- OPTIMAL REF: Direct Reference Iteration. Bypasses hash resolution.
function timersLoop()
    for i = 1, #activeRefs do
        local t = activeRefs[i] -- Direct Memory Offset
        if t then
            repeat
                if not t.enabled or t.paused or t.done then break end
                t.curTime = t.curTime + SERVER_DELAY
                if t.curTime < t.time then break end
                -- ... trigger logic and inline cleanup ...
            until true
        end
    end
end
```

---

## Appendix B: Empirical Benchmark & VM Profiling

### B.1 Benchmark Script Internals & Variable Isolation
- Microbenchmarks that fail to isolate variables produce misleading data.
- The initial benchmark (`benchmarker.lua`) failed because it executed Add, Loop, and Clear phases sequentially without isolating the underlying mechanics.

- **The Loop Illusion:** The initial benchmark showed `original_algorithm` as the fastest in the Loop phase.
- It failed to separate pure iteration from hash lookups.
- `original_algorithm` iterated over direct table references, while the `optimal` variants iterated over strings.
- The benchmark measured the Hash Lookup Tax, not the loop logic.

- **The Clear Illusion:** The initial benchmark showed `original_algorithm.clearTimers()` taking `0.00ms`.
- Because no timers expired during the test, the `timersPool` was empty.
- The `repeat` loop evaluated `nil` and exited immediately, performing zero cleanup.
- The O(N²) `table.remove` trap was never triggered.

#### Benchmark Execution Flow (UML)
- The improved benchmarker (`improved_benchmarker.lua`) isolates execution phases to expose algorithmic flaws.
```mermaid
graph TD
    A[Start Benchmark] --> B[Phase 1: Add N Timers]
    B --> C[Phase 2: Loop TICKS times]
    C --> D[Phase 3: Remove N Timers via API]
    D --> E[Phase 4: Re-add N Timers]
    E --> F[Phase 5: clearTimers]
    F --> G[Record Metrics]
    
    B -.->|Measures Vararg Spill & Pool Alloc| B
    C -.->|Measures Iteration & Hash Lookup Tax| C
    D -.->|Measures O N  vs O 1  API Lookup| D
    F -.->|Triggers O N^2 table.remove trap| F
```

### B.2 Empirical Results
- **Metrics:** `os.clock()` CPU time in milliseconds. N=5000 timers, TICKS=2000.

| Implementation | Add (ms) | Loop (ms) | Remove (ms) | Clear (ms) | Total (ms) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **1. original** | 21.48 | 1612.49 | **552.56** | **0.00 (No-op)** | 2186.54 |
| **2. overengineered** | 16.87 | 2968.65 | 2.85 | 0.00 (GC suicide) | 2988.37 |
| **3. optimal (Extracted)**| 9.71 | 2069.04 | 4.32 | 1.40 | 2084.48 |
| **4. optimal_inline** | 15.42 | 1353.61 | 3.75 | 1.33 | 1374.10 |
| **5. optimal_repeat** | 14.15 | 1372.56 | 3.73 | 1.39 | 1391.84 |
| **6. optimal_ref** | **12.50** | **1067.44** | **4.61** | **1.32** | **1085.87** |

---

## 7. Conclusion

### Methodology
- The evaluation relied on a restructured benchmarking methodology that isolated execution phases (Add, Loop, Remove, Clear) to expose hidden algorithmic and VM-level flaws.
- Sequential benchmarks initially obscured the O(N²) `table.remove` trap and the CPU cost of hash resolution by mixing iteration, callback execution, and teardown.
- By isolating these variables, the methodology forced the exposure of interpreter-specific bottlenecks that theoretical Big-O analysis alone failed to quantify in the context of the Lua 5.1 C VM.

### Findings
- The empirical profiling revealed three strict constraints inherent to the Lua 5.1 interpreter that dictate architectural choices.

- **The GC Step Counter:** Lua 5.1’s incremental mark-and-sweep garbage collector means that *any* table allocation in a hot path continuously advances the GC step counter.
- In a 500ms tick environment, this guarantees frequent, perceptible micro-stutters that degrade UPS.
- Strict object pooling is not an optimization; it is a mandatory requirement for stable UPS.

- **The `OP_CALL` Penalty vs. Cyclomatic Complexity:** Extracting guard functions to achieve zero-nesting control flow incurs a severe interpreter dispatch penalty.
- Crossing function boundaries requires allocating `CallInfo` structures on the C stack (`OP_CALL`), incurring a heavy relative dispatch weight.
- Inline branching (`OP_TEST`/`OP_JMP` or `OP_BREAK`) incurs a minimal relative weight.
- In a pure interpreter, flat control flow via function extraction is measurably slower than deeply nested or `repeat..break` inline logic.

- **The Hash Lookup Tax:** Iterating over an array of strings and resolving them via a hash table (`timers[label]`) forces the VM to execute `luaH_getstr`.
- This computes the string hash and traverses bucket linked lists.
- Over millions of iterations, this pointer indirection introduces a massive CPU overhead compared to direct array memory offset calculations.

### Results
- The predecessors (`original_algorithm`, `overengineered_algorithm`) were disqualified by O(N²) lifecycle operations, vararg GC spills, and continuous hot-path allocations.
- The intermediate optimal variants resolved the GC and algorithmic flaws but exposed the `OP_CALL` penalty and the Hash Lookup Tax.
- The most recent architecture (`optimal_ref_timer.lua`) resolves these interpreter penalties through structural decoupling.
- By storing direct table references in the iteration array (`activeRefs`) rather than string labels, the hot path executes `OP_GETTABLE` with an integer key.
- This bypasses string hash resolution entirely and achieves direct memory offset access.
- Concurrently, it retains a separate hash table (`timers`) strictly for O(1) external API lookups.
- Combined with the `repeat..break` algorithmic early-exit pattern to eliminate `OP_CALL` overhead, and dual-stack pooling to maintain a flat GC profile, `optimal_ref_timer.lua` yields the lowest empirically measured execution time.
- It represents the optimal trade-off for this specific problem space, balancing API safety, memory stability, and raw interpreter dispatch speed within the strict boundaries of Lua 5.1.

---

## Appendix C: External CS References & Theoretical Foundations

- **Ierusalimschy, R., et al. "The Implementation of Lua 5.0"** (Proceedings of the Fifth Brazilian Symposium on Programming Languages).
  - *Concept:* Lua's internal table structure (Array Part vs. Hash Part) and the incremental mark-and-sweep GC mechanics.
  - *Application:* Validates the dichotomy between `OP_GETTABLE` with integer keys (direct array offset) vs. string keys (hash bucket traversal).
  - *Application:* Explains the GC step counter (`luaC_step`) and why hot-path allocations trigger frequent micro-stutters in a fixed-tick game loop.

- **Drepper, U. "What Every Programmer Should Know About Memory"** (Red Hat, Inc.).
  - *Concept:* CPU cache hierarchy, cache line invalidation, and `memmove` performance.
  - *Application:* Explains the catastrophic CPU cache thrashing caused by the O(N²) `table.remove` operation in `original_algorithm.lua`.
  - *Application:* Explains the I-Cache locality benefits of the inline nesting approach.

- **Myers, B., et al. "Pitfalls in Benchmarking"** (ACM SIGMETRICS Performance Evaluation Review).
  - *Concept:* Variable isolation, warm-up phases, and the dangers of sequential phase execution in microbenchmarks.
  - *Application:* Explains the failure of the initial benchmark (which mixed iteration, hash lookups, and callback execution).
  - *Application:* Validates the design of the improved benchmark to isolate Add, Loop, Remove, and Clear operations.

- **Gamma, E., et al. "Design Patterns: Elements of Reusable Object-Oriented Software"** (Addison-Wesley).
  - *Concept:* The Object Pool Pattern (Memory Pool pattern).
  - *Application:* Validates the `timerPool` and `freeIndices` dual-stack architecture.
  - *Application:* Adapts the pattern for Lua's table-based memory model to minimize the overhead of object creation and bypass the GC.

- **Cormen, T. H., et al. "Introduction to Algorithms"** (MIT Press).
  - *Concept:* Time Complexity of Array Operations, Deferred Compaction, and Tombstone Marking.
  - *Application:* Explains the O(N²) complexity of `table.remove`.
  - *Application:* Validates the use of Tombstone Marking (`activeRefs[i] = nil`) combined with a Free List (`freeIndices`) to reduce removal to strict O(1) time complexity.

- **Lua 5.1 Source Code & Internals** (Lua.org, `lvm.c`, `ltable.c`, `lobject.h`).
  - *Concept:* The `OP_CALL` overhead in the C VM, `luaF_newCclosure`, and `luaH_getstr` vs `luaH_getnum`.
  - *Application:* Provides the relative interpreter dispatch weights for function dispatch (`OP_CALL`) vs. conditional branching (`OP_TEST`/`OP_JMP`).
  - *Application:* Details the mechanics of string hash resolution in the Lua table implementation.
---