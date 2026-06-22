# Lua Implemented Patterns Synergies

**Author:** Vit0rg  
**Created:** May 15th 2026  
**Document last updated:** June 16th 2026 | Based on `vit0rg/volley` + `vit0rg/echeckers` architecture review and GoF-to-Lua mapping.  
**License:** MIT

## Table of Contents

- [Introduction](#introduction)
- [Synergy 1: Game Loop Orchestrator](#synergy-1-game-loop-orchestrator)
- [Synergy 2: Minimal-Overhead Dispatcher](#synergy-2-minimal-overhead-dispatcher)
- [Synergy 3: Performance Optimizer](#synergy-3-performance-optimizer)
- [Synergy 4: Turn-Based Flow](#synergy-4-turn-based-flow)
- [Synergy 5: Cross-Platform Behavior Injector](#synergy-5-cross-platform-behavior-injector)

---

## Introduction

- Synergies, when used correctly, enhance performance and maintainability. 
- Since many Gang of Four (GoF) design patterns are dissolved or redundant in Lua.
- Lua primitives (tables, closures, and metatables) become the main actors. 
- These synergies work by replacing class hierarchies and interfaces with lightweight, controlled side effects and direct dispatch.

---

## Synergy 1: Game Loop Orchestrator

**Architectural Role:** Orchestration and Propagation. Manages game flow, executes the action, and ripples side-effects (UI, stats) without tight coupling.  
**Core Question Answered:** _"When should this run, and who needs to know about the result?"_  
**Patterns Used:** State + Command + Observer (3 Behavioral patterns coordinating).

**Benefits:**

- Handles horizontal coupling (cross-module side effects, UI, state).
- Decouples input parsing, state transitions, and rendering with zero boilerplate.

**Example (Volley: `eventLoop.lua` + `eventChatCommand.lua`):**

```lua
-- STATE: Current implicit FSM
mode = "startGame"  -- Global string -> state
function eventLoop(elapsed, remaining)
  if mode == "startGame" then
    if teamsReady then mode = "gameStart" end
  elseif mode == "gameStart" then
    -- physics, scoring, win checks
    if scoreReached then mode = "endGame" end
  elseif mode == "endGame" then
    if displayTimer > 5 then mode = "startGame" end
  end
end

-- COMMAND: Table-driven Command Dispatcher
local handler = COMMANDS[permLevel][cmdName]
if handler then handler(name, args) end -- Dispatch command

-- OBSERVER (implicit): Side effects triggered post-mutation
function cmdJoin(name)
  gameStats.players[name] = { joined = true, team = "red" }  -- Mutates state
  tfm.exec.chatMessage(name .. " joined the red team")       -- Triggers chat update
  ui.addTextArea(7, "Players: " .. #gameStats.players)       -- Triggers UI update
end
```

**How it works:**

- **State** = _When_ to run (`mode` tracks FSM state).
- **Command** = _What_ to run (`COMMANDS[cmd]()` table-driven dispatch).
- **Observer** = _Who_ gets notified (implicit side-effects trigger UI/chat updates).

---

## Synergy 2: Minimal-Overhead Dispatcher

**Architectural Role:** Routing and Selection. Replaces verbose `if/elseif` chains with instant, zero-allocation O(1) hash dispatch.  
**Core Question Answered:** _"Which specific algorithm or handler should execute for this exact input?"_  
**Patterns Used:** Strategy + Factory + Lookup Table (Behavioral + Creational + Lua primitive).

**Benefits:**

- Handles vertical coupling (input → resolver → handler).
- Functions/tables are swapped at runtime based on config keys.
- O(1) dispatch, hot-reload friendly, ~0 allocation per swap.

**Example (Volley: `eventChatCommand.lua`):**

```lua
-- FACTORY + LOOKUP TABLE (Initialization)
COMMANDS = {
  [1] = { join = cmdJoin, leave = cmdLeave },
  [2] = { kick = cmdKick, mute = cmdMute },
  [3] = { ban = cmdBan, config = cmdConfig }
}

-- STRATEGY (Dispatch Hot Path)
local handler = COMMANDS[math.min(USER_PERMISSIONS[name] or 1, 3)][string.lower(cmd)]
if handler then handler(name, args) end
```

**How it works:**

- **Strategy** = _How_ to run (the function reference itself).
- **Factory** = _Who_ picks the behavior (the permission-level resolver).
- **Lookup Table** = Fast routing (`COMMANDS[tier][cmdName]` hash access).

---

## Synergy 3: Performance Optimizer

**Architectural Role:** Optimization and Resource Management. Hides complex setup behind a simple API while aggressively recycling IDs and sharing read-only data to starve the Garbage Collector.  
**Core Question Answered:** _"How can we do this without allocating new memory or exposing subsystem complexity?"_  
**Patterns Used:** Facade + Object Pool + Flyweight (Structural + Creational + Structural).

**Benefits:**

- Reduces GC pressure by 30–40% while keeping APIs clean.

**Example (Volley: `timer.lua` + `eventKeyboard.lua`):**

```lua
-- 1. FLYWEIGHT: Shared, read-only configuration (allocated once at init)
local KEYS = { LEFT = 0, UP = 1, RIGHT = 2, DOWN = 3, TRANSFORM = 32 }
local CONSUMABLES = { [49] = { cooldown = 5000, effect = "jump_boost" } }

-- 2. OBJECT POOL: Pre-allocated reusable IDs
local timerList = {}
local timersPool = List.new() -- Manual list implementation for pooling

function addTimer(callback, ms, loops, label, ...)
  local id = List.popleft(timersPool) or (#timerList + 1)
  -- ... setup timer
  return id
end

-- 3. FACADE: Simple API hiding the complexity
-- Usage: Cooldown reset (player-specific timer)
addTimer(function()
  playerConsumable[name] = true
  tfm.exec.chatMessage("<bv>You can spawn a new consumable<n>", name)
end, 5000, 1, "enablePlayerConsumable_" .. name)
```

**How it works:**

- **Flyweight** = Data sharer that avoids duplicating static data (`KEYS`, `CONSUMABLES`).
- **Object Pool** = Memory saver that prevents allocation churn (`timersPool`).
- **Facade** = Clean API that hides pooling/flyweight complexity (`addTimer()`, `removeTimer()`).  
  _(Note: The `!join` command does not start a countdown; it mutates state. Timers are used for delayed effects like consumable cooldowns or match transitions)._

---

## Synergy 4: Turn-Based Flow

**Architectural Role:** Procedural Sequencing and minimal-overhead Iteration. Relies on simple, sequential function calls and strict C-style loops to completely avoid `ipairs`/`pairs` GC pressure.  
**Core Question Answered:** _"How do we sequence game steps predictably and iterate over collections with zero allocation overhead?"_  
**Patterns Used:** Procedural Phase Loop + Implicit Contract + C-Style Iterator.

**Benefits:**

- Predictable, bug-resistant flow via convention, not rigid OOP enforcement.
- Maximum iteration speed by adhering to project standards (no iterator closures).

**Example (Echeckers: `game/battle/battle.lua` + `phases/`):**

```lua
-- 1. PHASE STATE: Explicit loop calling phase functions sequentially
-- 2. IMPLICIT CONTRACT: Each phase file follows a convention (read state, act, yield control)
for turn = 1, MAX_TURNS do
    draw_phase()      -- 1. Draw cards based on mode
    standby_phase()   -- 2. Player/AI actions (input handling)
    battle_phase()    -- 3. Resolve combat / field effects
    end_phase()       -- 4. Cleanup, discard, switch Player_turn
end

-- 3. C-STYLE ITERATOR (Inside standby_phase.lua)
local hand = Hands[Player_turn]
local size = #hand  -- Cache length (Project Standard)
for i = 1, size do  -- Strict C-style loop to avoid ipairs overhead
    local card = hand[i]
    if card and is_valid_target(card) then
        process_card(i)
    end
end
```

**How it works:**

- **Phase State & Iterator** = Explicit loop that calls phase functions sequentially using fast, direct array indexing.
- **Implicit Contract** = Each `..._phase` function resides in its own file and adheres to a procedural convention (no base class or `__index` inheritance forcing a skeleton).

---

## Synergy 5: Cross-Platform Behavior Injector

**Architectural Role:** Decoupling and Behavior Injection. Separates the core logic from the presentation/platform, while transparently injecting wrappers (ANSI colors, rate limits, logging).  
**Core Question Answered:** _"Where should this be rendered/communicated, and what cross-cutting behavior (formatting, logging) should wrap it?"_  
**Patterns Used:** Bridge + Decorator (Implicit).

**Benefits:**

- Core game logic never knows about ANSI codes, terminal specifics, or platform APIs.
- Achieved via simple `if/else` routing and closure/metatable wrapping, avoiding complex OOP hierarchies.

**Example (Echeckers: `UI.update_board.lua`):**

```lua
-- 1. BRIDGE: UI routing based on build target (simple composition/delegation)
local UI = {}
function UI.update_board(board_state)
  if BUILD == 'TUI' then
    _TUI_update_board(board_state)  -- Delegates to terminal renderer
  elseif BUILD == 'GUI' then
    _GUI_update_board(board_state)  -- Delegates to graphical renderer
  end
end

-- 2. DECORATOR: Closure wrapping adds ANSI color batching transparently
local function wrap_color(text, color_code)
  return color_code .. text .. ANSI_RESET
end

-- Usage inside _TUI_update_board:
-- local cell_text = wrap_color(card_emoji, COLOR_CACHE[biome_color])
```

**How it works:**

- **Bridge** = Simple `if/else` or table lookup routing to a specific backend (`BUILD` check).
- **Decorator** = Closure or metatable that transparently wraps the output (e.g., `wrap_color` combined with a Flyweight `COLOR_CACHE`).

---