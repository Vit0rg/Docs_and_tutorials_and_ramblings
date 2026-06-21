# Docs, Tutorials, and Ramblings

Welcome to my personal collection of documentation, tutorials, and architectural ramblings. This repository primarily focuses on advanced **Lua programming**, **game development architecture**, and **idiomatic design patterns**. 

The core philosophy across these documents is that Lua's dynamic nature (first-class functions, flexible tables, and metatables) makes many traditional Object-Oriented Programming (OOP) patterns from the Gang of Four (GoF) unnecessary or trivial. Instead, these documents explore how to leverage Lua's native primitives to achieve zero-overhead, high-performance, and maintainable architectures.

## 📚 Table of Contents

- [Lua Design Patterns](#lua-design-patterns)
- [Implemented Pattern Synergies](#implemented-pattern-synergies)
- [Theoretical Creational Pattern Synergies](#theoretical-creational-pattern-synergies)
- [Procedural Context Injection (PCI)](#procedural-context-injection-pci)
- [Study Cases](#study-cases)

---

## 📖 Documentation Overview

### Lua Design Patterns
**File:** `lua_design_patterns.md`

A comprehensive guide to implementing classic GoF design patterns in Lua. This document explores how Lua's dynamic features collapse complex class-based implementations into a few lines of code. It covers:
- **Creational Patterns:** Optimized for low Garbage Collection (GC) pressure and fast instantiation.
- **Structural Patterns:** Focused on composition, hierarchy, and interface adaptation.
- **Behavioral Patterns:** Managing communication, state, and algorithm routing in game loops.

*Key Insight:* In Lua, ~15 of the 23 GoF patterns "dissolve" into closures, tables, and metatables. The remaining patterns retain conceptual value but require 5–10x less boilerplate than traditional OOP.

### Implemented Pattern Synergies
**File:** `lua_implemented_patterns_synergies.md`

Explores practical combinations (synergies) of design patterns tailored for Lua game development. These synergies replace class hierarchies with lightweight, controlled side effects and direct dispatch. Topics include:
1. **Game Loop Orchestrator:** State + Command + Observer for decoupling actions from side effects.
2. **Zero-Overhead Dispatcher:** Strategy + Factory + Lookup Table for O(1) hash dispatch.
3. **Performance Optimizer:** Facade + Object Pool + Flyweight to aggressively recycle IDs and starve the GC.
4. **Turn-Based Flow:** Procedural Phase Loop + C-Style Iterator for predictable, zero-allocation sequencing.
5. **Cross-Platform Behavior Injector:** Bridge + Decorator for decoupling core logic from presentation.

### Theoretical Creational Pattern Synergies
**File:** `lua_theoretical_creational_patterns_synergies.md`

In traditional OOP, Creational Patterns manage class hierarchies. In Lua, they manage **memory, configuration, and routing**. This document outlines 5 core theoretical synergies for object creation:
1. **Zero-Allocation Spawner:** Prototype + Object Pool + Flyweight to create high volumes of objects without GC spikes.
2. **Dynamic Configuration Assembler:** Builder + Strategy + Facade for clean, complex object construction.
3. **Decoupled Instantiator:** Factory Method + Lookup Table + Mediator for runtime routing without conditional branching.
4. **Global State Guardian:** Singleton + Proxy + Weak Tables for safe global access without `_G` pollution.
5. **Cross-Platform Family Provider:** Abstract Factory + Bridge + Module Caching for subsystem swapping.

### Procedural Context Injection (PCI)
**File:** `lua_procedural_context_injection.md`

Introduces **Procedural Context Injection (PCI)**, the most lightweight and performant method for managing dependencies in Lua. PCI completely discards OOP paradigms, metatables, and abstraction layers. 
- **Core Mechanism:** Dependencies are packed into a single, flat "context" table (`ctx`), which is passed explicitly as the first argument to stateless functions.
- **Performance Profile:** Minimizes register pressure in the Lua VM, enables direct C-level hash table lookups, and avoids `__index` metamethod traversal.
- **Applications:** Includes implementations for standard stateless modules, closure-bound modules, middleware pipelines, and asynchronous/coroutine contexts.
- **Project Rules:** Provides a strict checklist to prevent anti-patterns like scattered dependency arguments, global state corruption, and register exhaustion.

### Study Cases
**Directory:** `study_cases/`

Real-world architectural teardowns and code analyses. This directory contains deep dives into existing codebases, evaluating their design patterns, performance bottlenecks, and structural flaws to extract practical refactoring lessons.

#### Chris Uehlinger's Factorio Self-Expanding Algorithm
**Files:** `study_cases/chrisuehlinger_factorio_algorithm/`

A comprehensive architectural analysis of "Von Noying", a 1000 SPM (science per minute) bot-based self-expanding factory built in Factorio by Chris Uehlinger. The study dissects the original Lua script (~450+ lines of monolithic code) running via the Moon Logic Combinator mod.

**Key Analysis Points:**
- **Core Mechanics:** Breakdown of the Tier-Based Demand Resolution, the 3x3 Tile/Megatile system, and the Ulam Spiral expansion pattern.
- **Architectural Flaws:** Identifies critical anti-patterns such as the "God Script" monolith, scattered implicit state, massive `if/elseif` chains (O(n) linear scanning), and the Ulam spiral algorithm being copy-pasted verbatim four times.
- **Performance & Practical Issues:** Analyzes UPS degradation at scale, artillery coverage gaps, module production bottlenecks, and workarounds for complex fluid routing (oil processing) and bootstrap dependencies.
- **Refactoring Insights:** Highlights how applying proper design patterns (like the Zero-Overhead Dispatcher or Procedural Context Injection) could resolve the register pressure and state management issues present in the original code.

---

## 💡 Core Philosophy

- **Dissolve OOP Boilerplate:** Leverage Lua's first-class functions, closures, and tables instead of forcing class hierarchies.
- **Zero-Overhead & GC Starvation:** Design architectures that minimize memory allocations, recycle tables, and avoid iterator closures that trigger Garbage Collection.
- **Explicit Data Flow:** Favor passing context explicitly (like PCI) over relying on hidden global state or complex metatable inheritance.
- **Environment-Specific Design:** Write code that aligns perfectly with the Lua VM's register allocation and JIT compiler limits.

## 📄 License

This repository is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.