# Chris Uehlinger self-expanding factory algorithm overview

**Author**: Vit0rg  
**Created**: June 20th 2026  
**Document last updated:** June 21st 2026 
**Based on**: 
[The algorithm](https://gist.github.com/chrisuehlinger/c38fff88b7e429c81c2582430a2c3ab9)
[Factorio Automated: A 1000SPM self-expanding factory built with bots and Lua](https://youtu.be/PGiTkkMOfiw)
**License**: MIT  

---

## Table of Contents

- [Contextual Profile and Analysis](#contextual-profile-and-analysis)
  - [Project Context](#project-context)
  - [Technical Stack](#technical-stack)
  - [Structural Profile](#structural-profile)
- [Core Design Philosophy](#core-design-philosophy)
  - [Tier-Based Demand Resolution](#tier-based-demand-resolution)
  - [Tile System](#tile-system)
  - [The Spiral Expansion Pattern](#the-spiral-expansion-pattern)
- [Creator-Found Problems](#creator-found-problems)
  - [Critical Bugs](#critical-bugs)
    - [1. Factorio 2.0 Incompatibility](#1-factorio-20-incompatibility)
    - [2. The "Von Noying" Naming Bug](#2-the-von-noying-naming-bug)
    - [3. Pin Offset Misalignment Bug](#3-pin-offset-misalignment-bug)
    - [4. Bootstrap Dependency Bug](#4-bootstrap-dependency-bug)
  - [Practical Problems](#practical-problems)
    - [1. Uranium Enrichment Build Condition](#1-uranium-enrichment-build-condition)
    - [2. Solar Power Efficiency Failure](#2-solar-power-efficiency-failure)
    - [3. Oil Processing Limitation](#3-oil-processing-limitation)
    - [4. Water Infrastructure Copout](#4-water-infrastructure-copout)
  - [Performance Issues](#performance-issues)
    - [1. UPS Degradation](#1-ups-degradation)
    - [2. Biter Defense Slowdown](#2-biter-defense-slowdown)
    - [3. Module Production Bottleneck](#3-module-production-bottleneck)
    - [4. Build Condition Sensitivity](#4-build-condition-sensitivity)
- [Architectural Flaws](#architectural-flaws)
  - [1. The "God Script" Anti-Pattern](#1-the-god-script-anti-pattern)
  - [2. Scattered Implicit State](#2-scattered-implicit-state)
  - [3. Duplicated Spiral Algorithm](#3-duplicated-spiral-algorithm)
  - [4. Massive if/elseif Chains](#4-massive-ifelseif-chains)
  - [5. Mixed Purity](#5-mixed-purity)
  - [6. Register Pressure](#6-register-pressure)
  - [7. Off-by-One / Logic Bugs](#7-off-by-one--logic-bugs)
  - [8. Missing Infrastructure Handlers](#8-missing-infrastructure-handlers)
- [Next Steps](#next-steps)

---

## Contextual Profile and Analysis

### Project Context
- "Von Noying" - A bot-based self-expanding Factorio factory created by Chris Uehlinger starting in 2021.
- The project represents ~6 months of total development time (with 2 months on initial train/belt version, 1-2 months on bot version, and years of tweaking).
- It achieves 1000 SPM (science per minute) after 500+ megatiles and ~6 hours of game time, but takes several days of real-world time with biters enabled.
- It reads logistic network signals (via red wire) and resource scanner data (via green wire) to autonomously decide what blueprints to deploy next, orchestrating a spiral expansion pattern.

### Technical Stack

- Moon Logic Combinator: Lua scripting environment for Factorio (enabling sophisticated algorithm)
- Recursive Blueprints Mod: Essential for self-expanding factory capability
- Circuit Network: Red wire (demand signals) + Green wire (state signals)


### Structural Profile

| Metric                     | Observation                                                                                        |
| -------------------------- | -------------------------------------------------------------------------------------------------- |
| **Total Lines**            | ~450+ lines of dense, monolithic Lua                                                               |
| **Nesting Depth**          | Up to 7 levels deep (megatile decision block)                                                      |
| **Global/Implicit State**  | `var`, `out`, `red`, `green`, `delay`, `lastSignal`, `newSignal`, `tagSignal`                      |
| **Duplicated Code Blocks** | The spiral coordinate calculation (Ulam spiral) is copy-pasted **4 times** verbatim                |
| **if/elseif Chain Length** | The megatile selection block has a single chain of ~8 conditions with deeply nested sub-conditions |
| **Function Count**         | Only 1 named function: `choose_item_from_tiers()`                                                  |
---

## Core Design Philosophy

### Tier-Based Demand Resolution

- Products organized in dependency tiers. Algorithm checks tier 1 -> tier 2 -> etc.
- If any item in a tier has negative demand, build manufacturing tile for the item with highest demand in that tier.
- This prevents "building green chip assemblers when you don't have copper wire."

### Tile System

- Tile: 3x3 unit (smallest manufacturing unit)
- Megatile: 3x3 grid of tiles (8 manufacturing tiles + 1 blank center)
- 1-Minute Surplus Rule: Each tile manufactures until it has 1 minute of product surplus, then requests 1 minute of ingredients

### The Spiral Expansion Pattern

- The factory uses an Ulam spiral for placement coordinates.
- The duplicated spiral algorithm (appearing 4 times in the script) calculates the next megatile position based on tile count.

---

## Creator-Found Problems

### Critical Bugs

#### 1. Factorio 2.0 Incompatibility

- As of March 2025, the scenarios no longer work with Factorio 2.0 due to mod compatibility issues.
- The recursive blueprints mod and moon logic combinator mod are no longer compatible[[video description update 2025-03-17]].
- This is a breaking change that renders the entire system non-functional on the current version of the game.

#### 2. The "Von Noying" Naming Bug

- The creator chose the name "Von Noying" during a frustrating debugging session and now regrets it.
- But the name is embedded throughout all files and scripts.
- He deliberately avoided saying the name in the video because he's "not in love with it"[[video description]].
- This represents a technical debt of naming conventions that are hard to refactor.

#### 3. Pin Offset Misalignment Bug

- When transplanting the root megatile to a new scenario, the map pins placed by the algorithm don't line up correctly.
- This requires manual adjustment of PIN_OFFSET_X and PIN_OFFSET_Y variables in the Moon Logic combinator[[video description]].
- This is a coordinate system bug that makes the system fragile when moved between scenarios.

#### 4. Bootstrap Dependency Bug

- The root megatile requires manual bootstrap with:
  - A blueprint book from the Blueprint Deployer
  - A stack of heavy oil barrels in storage chests
  - At least one logistic bot in a Roboport
- Without these, the factory cannot start.
- This represents a missing initialization routine in the algorithm itself[[video description]].

### Practical Problems

#### 1. Uranium Enrichment Build Condition

- Problem: Couldn't find reliable "build condition" for uranium enrichment tile
- Solution: Hardcoded both nuclear-related tiles into the root megatile instead of letting algorithm build them
- Impact: One of each tile fuels 1000 SPM worth of nuclear megatiles permanently
- Root Cause: Complex state dependencies made conditional logic unreliable

#### 2. Solar Power Efficiency Failure

- Problem: Designed "perfect" solar/accumulator megatile, but Roboports consume up to 4MW each when charging bots
- Result: "Giant oceans of solar dotted with islands of manufacturing tiles"
- Solution: Switched to nuclear power with 2x2 reactor neighbor bonus
- Technical Detail: Nuclear reactors use local circuits to check steam levels every few minutes, only feeding fuel when below 500° (not 1000°) to save fuel cells

#### 3. Oil Processing Limitation

- Problem: Algorithm has no method for building/pipng pump jacks
- Workaround: All oil processing based on coal liquefaction
- Bootstrap Requirement: Must start with heavy oil barrels in root megatile
- Complexity: Three-way cracking system (heavy -> light -> petroleum) with overflow to solid fuels
    - Coal liquefaction has wild product ratios
    - Doesn't produce enough light oil or petroleum
    - Requires complex fluid routing:
        - Heavy oil -> light oil (eastern area) when `heavy > light`
        - Light oil -> petroleum (southern area) when `light > petroleum`
    - Excess petroleum -> solid fuel (rare fallback)


#### 4. Water Infrastructure Copout

- Problem: Never implemented offshore pump tiles
- Reason: Would require multiphase blueprinting logic
- Current Solution: Infinite water pipes (acknowledged as a "copout")
- Justification: Barreling process creates a bottleneck, making it "a little bit fairer"
- Impact: This limits the factory's ability to scale water-intensive operations like oil processing and nuclear power.

### Performance Issues

#### 1. UPS Degradation
- Problem: 
    - The factory maintains 60+ UPS for the first couple hundred megatiles. 
    - But by the time it reaches 1000 SPM (science per minute), it drops to 24-30 UPS (on an M1 Max MacBook Pro)
- Symptom: Above 60 FPS for first ~200 megatiles
- Failure Point: Drops to half speed by 1000 SPM
- Root Cause:
    - Bot-based logistics are inherently UPS-intensive
    - Long travel times as the factory expands
    - More active bots at any given time
    - Inefficient layout due to algorithmic placement rather than hand-optimized design
- Creator's Assessment: "I wanted the algorithm to sort of design the factory as it goes which means I pay the price in terms of inefficient layout, long travel times, more active Bots at any given time, and therefore lower UPS"
- Comparison: Other 10,000 SPM bot bases achieve their scale by designing **self-contained mini-factories** and stamping out dozens of copies with **unconnected logistic networks**
- Vit0rg: "This is the tradeoff of taking creation speed and simplicity over optimization and a proper architecture."

#### 2. Biter Defense Slowdown
- Problem: Construction bots busy repairing damage instead of building
- Impact: "Factory expands a lot slower when dealing with biters"
- Mitigation:
    - The factory starts with an artillery cannon that clears the area around the root megatile for about 36 megatiles.
    - After that, the algorithm sets flags at corners to build artillery station tiles
    - Algorithm waits until "almost all construction bots are idle" before surveying/building
- Artillery Gap: Coverage becomes insufficient at 100+ megatiles, needs research for artillery range
- Vit0rg: "The coverage issue comes from the improper layout growth."
- Missing Feature: 
    - Artillery range research should be injected after a certain number of megatiles (around a few hundred) because gaps in artillery coverage start approaching the factory's outer layers

#### 3. Module Production Bottleneck
- Problem: 
    - The factory uses level 3 modules everywhere but cannot actually craft them
    - A level 3 module supply chain about as large as a 1000 SPM factory alone
- Current State: Combinators disconnected, relies on infinite chest forever
- Trade-off: Downgrading to L1/L2 modules would require refactoring every manufacturing tile and solving water barreling issues
- Status: "I have been putting it off"
- Vit0rg: "Again, an improper layout growth, becomes the root of bottlenecks."
- Impact: This represents a fundamental scaling problem where the factory cannot become truly self-sufficient.

#### 4. Build Condition Sensitivity

- Issue: If algorithm builds same tile twice by accident -> massive downstream demand spikes
- Design Response: Small manufacturing tiles ensure overproduction doesn't create "too much downstream demand"
- Lesson: "This was the main reason I opted for this unconventional design"
- Vit0rg: "The issue here probably comes from a racing condition, considering the vertically coupling of the algorithm."

---

## Architectural flaws

### 1. The "God Script" Anti-Pattern

- Everything in single execution scope with no separation between:
  - Input parsing (red/green signals)
  - State management (var table)
  - Decision logic (what to build)
  - Output formatting (out table, map tags)
  - Side effects (game.print)
- "Why is the state so hard to manage?" -> Cognitive overhead.

### 2. Scattered Implicit State

- The script uses a mix of:
  - local variables at file scope (acting as persistent state between ticks)
  - A var table (acting as a global state bag)
  - Implicit circuit-network globals (red, green)
  - An implicit out table for outputs

- This makes it impossible to test, replay, or reason about state transitions.
- You cannot snapshot the state because it is fragmented across var, lastSignal, newSignal, tagSignal, and file-scoped locals.

### 3. Duplicated Spiral Algorithm

- The Ulam spiral coordinate calculation appears 4 times in the script:

```lua
-- Lines ~195, ~240, ~310, ~380
local n = ...
local x = -1; local y = 0
local steps = 0; local max_steps = 1; local turns_taken = 0
for i = 2, n, 1 do
    steps = steps + 1
    if steps == max_steps then steps = 0; turns_taken = turns_taken + 1 end
    if steps == 0 and turns_taken % 2 == 0 then max_steps = max_steps + 1 end
    if turns_taken % 4 == 0 then x = x - 1
    elseif turns_taken % 4 == 1 then y = y - 1
    elseif turns_taken % 4 == 2 then x = x + 1
    elseif turns_taken % 4 == 3 then y = y + 1
    end
end
```

- This is a maintenance hazard.
- If the spiral logic needs fixing, it must be fixed in 4 places.

### 4. Massive if/elseif Chains

- The megatile decision block is a textbook example of poor dispatch:

```lua
if currently_constructed_megatiles == 1 then
    newSignal = 106
elseif green['uranium-ore'] > 100000 or ... then
    newSignal = 1
elseif var.need_power then
    if currently_constructed_megatiles > 10 and ... then
        newSignal = 106
    else
        newSignal = 2
    end
elseif currently_constructed_megatiles < 9 then
    newSignal = 2
elseif lastSignal ~= 110 and (...) then
    newSignal = 110
else
    newSignal = 1
end
```

- This is O(n) linear scanning through conditions.
- Adding a new megatile type requires inserting into the middle of this chain, risking breakage of existing logic.

### 5. Mixed Purity

- `game.print()` calls are scattered throughout decision logic.
- `add_chart_tag()` is called inline.
- This means you cannot unit-test the "what should we build?" logic without mocking the entire game API.

### 6. Register Pressure

- The script declares ~15 local variables at the top level for signal unpacking:

```lua
local currently_constructed_megatiles = red['signal-info']
local currently_constructed_research_tiles = red['signal-dot']
local available_logistic_bots = red['signal-A']
-- ... 10 more
```

- Each of these consumes a register.
- In a tick-based game loop, this contributes to register spilling.

### 7. Off-by-One / Logic Bugs

- `var.tilesBuilt % 8 == 0 and var.tilesBuilt / 8 >= currently_constructed_megatiles`
- The use of `/` (float division) instead of `//` (integer division) is suspicious.
- If `tilesBuilt` is 8, `8/8 = 1.0 >= 1` works, but this is fragile.
- `The choose_item_from_tiers()` function has a typo: `currrent_item` (three r's) is used consistently but is a naming bug.
- The "check_again" fallback loop in `choose_item_from_tiers()` duplicates the entire inner loop body **instead of reusing logic**.

### 8. Missing Infrastructure Handlers
- No methods for:
  - Pump jack placement
  - Offshore pump tiles
  - Multiphase blueprinting
  - Module production tiles (disabled)

---

## Next Steps
- This document covers the contextual profile, conceptual design, and empirical/architectural flaws of the algorithm. 

For a deep dive into the specific code mechanics, please refer to:
* [Part 2: Data Structures, Algorithms, and Design Patterns Analysis](./original_algorithm_technical_analysis.md)