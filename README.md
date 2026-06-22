# Native Lua Architecture & Design Patterns

Welcome to a comprehensive, VM-level guide to high-performance Lua architecture. 

- This repository is a deep dive into translating traditional Object-Oriented Design Patterns (GoF) into **native, idiomatic Lua**.
- Rather than forcing Lua to act like Java or C++, this guide leverages Lua's core primitives—first-class functions, closures, flexible tables, and the LuaJIT trace compiler—to build systems that are faster, smaller, and easier to maintain.

## 🎯 Core Philosophy
* **Dissolve the Boilerplate:** Complex OOP hierarchies collapse into simple data structures and function dispatch.
* **Respect the VM:** Architecture is designed around LuaJIT's trace compiler, Garbage Collector (GC) starvation, and CPU cache locality.
* **Data-Oriented over Object-Oriented:** Favor flat context passing (PCI) and array-of-structs over deep metatable inheritance.
* **Proven in Production:** Concepts are validated through rigorous benchmarking and real-world game mod teardowns.

---

## 📚 Repository Contents

### 🏛️ Core Architectural Idioms
Practical, high-performance replacements for traditional design patterns, tailored for game loops and hot paths.
* **[Native Lua Architectural Idioms](./lua_native_architectural_idioms.md)** *(formerly lua_implemented_patterns_synergies.md)*
  The 5 essential Lua idioms: Direct Hash Dispatch, Explicit Context Passing, Table Recycling, Sequential Phase Execution, and Environment Injection. Includes progressive code shifts (Naive -> OOP -> Idiomatic) and LuaJIT benchmarks.
* **[Procedural Context Injection (PCI)](./lua_procedural_context_injection.md)**
  Lua's lightweight equivalent to Dependency Injection. Learn how to manage state, eliminate `_ENV` global lookups, and enable zero-copy FFI mapping using flat `ctx` tables.

### 🧠 Design Patterns & Theory
- The academic and theoretical foundations of translating the Gang of Four (GoF) patterns into dynamic languages.
* **[Lua Design Patterns: Translating GoF into Native Idioms](./lua_design_patterns.md)**
  - A masterclass analyzing all 23 GoF patterns through the lens of Peter Norvig’s Lisp thesis. 
  - Explores how Lua achieves compile-time pattern dissolution at runtime. 
  - Includes Mermaid diagrams, CS literature references, and strict LuaJIT profiling protocols.

### 🔬 Case Studies & Teardowns
- Real-world architectural teardowns, evaluating existing codebases to extract practical refactoring lessons.
* **[Study Cases Directory](./study_cases/)**
  * **The Von Noying Algorithm (Factorio):** A 3-part analysis of Chris Uehlinger's 1000 SPM self-expanding Factorio factory.
    * [Part 1: Contextual Profile & Analysis](./study_cases/original_algorithm_analysis.md)
    * [Part 2: Data Structures & Algorithms Analysis](./study_cases/original_algorithm_technical_analysis.md)
    * [Part 3: Refactored Implementation & Performance Optimization](./refactored_implementation.md) - *Applying PCI and Minimal-Overhead Dispatchers to eliminate UPS degradation.*

---

## 🗺️ Who is this for?

| Audience | What you will find here |
| :--- | :--- |
| **🟡 The Novice** | **The "Why" and "How".** Progressive examples showing exactly *why* global variables and `if/elseif` chains hurt performance, and step-by-step guides to refactoring them. |
| **🟠 The Intermediate** | **The Industry Bridge.** "Rosetta Stone" translations mapping Lua idioms to standard industry concepts (e.g., PCI = Dependency Injection, Hash Dispatch = Strategy Pattern). |
| **🔴 The Expert** | **The VM Proof.** LuaJIT trace-compiler analysis, FFI boundary optimization, GC starvation techniques, and rigorous benchmarking methodologies (warmups, GC halting). |

---

## 🛠️ Key Concepts Covered

* **Minimal-Overhead Dispatchers:** Replacing $O(n)$ `if/elseif` chains with $O(1)$ hash table lookups.
* **GC Starvation (Object Pooling):** Reusing tables in hot paths to guarantee flatline frame times and eliminate Garbage Collection spikes.
* **FFI Boundary Optimization:** Structuring Lua data to map directly to C-structs without expensive marshaling or metatable unpacking.
* **Trace-Friendly Architecture:** Avoiding `__index` metamethods and closure allocations in tight loops to keep the LuaJIT compiler happy.

## 📄 License

- This repository and its documentation are licensed under the MIT License. 
- See the [LICENSE](LICENSE) file for more details.

---
*Built with a deep respect for the Lua VM, Data-Oriented Design, and the enduring relevance of the Gang of Four.*