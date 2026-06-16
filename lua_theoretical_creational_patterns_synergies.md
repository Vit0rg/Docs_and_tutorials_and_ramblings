# Lua Theoretical Creational Patterns Synergies

**Author:** Vit0rg  
**Created:** June 16th 2026  
**Document last updated:** June 16th 2026 | Inspired on GoF-to-Lua mapping and `vit0rg/volley` + `vit0rg/echeckers` architecture review.  
**License:** MIT

## Table of Contents

- [Introduction](#introduction)
- [Synergy 1: Zero-Allocation Spawner](#synergy-1-zero-allocation-spawner)
- [Synergy 2: Dynamic Configuration Assembler](#synergy-2-dynamic-configuration-assembler)
- [Synergy 3: Decoupled Instantiator](#synergy-3-decoupled-instantiator)
- [Synergy 4: Global State Guardian](#synergy-4-global-state-guardian)
- [Synergy 5: Cross-Platform Family Provider](#synergy-5-cross-platform-family-provider)

---

## Introduction

- In traditional Object-Oriented Programming (OOP), Creational Patterns exist to manage the complexity of object instantiation, hiding construction logic and decoupling the system from concrete classes.
- However, in Lua, the concept of a "class" is an illusion built on metatables, and tables are inherently flexible, dynamic, and prototype-based.

- Therefore, **Creational Patterns in Lua do not manage class hierarchies; they manage memory, configuration, and routing**.
- When synergized correctly, these patterns dissolve into lightweight Lua primitives (closures, table constructors, `require` caching, and metatables), eliminating OOP boilerplate while aggressively protecting the runtime from Garbage Collector (GC) spikes and tight coupling.

- This document outlines the 5 core theoretical synergies for **Creational Patterns** in Lua game development, strictly adhering to zero-overhead array manipulation (no `table.insert`/`table.remove`).

---

## Synergy 1: Zero-Allocation Spawner

**Architectural Role:** Memory Management and Entity Instantiation. Creates high volumes of similar objects without triggering GC pauses.  
**Core Question Answered:** _"How do I create many similar objects at runtime without allocating new memory or triggering the Garbage Collector?"_  
**Patterns Used:** Prototype + Object Pool + Flyweight (Creational + Creational + Structural).

**Benefits:**

- Eliminates table allocation churn in tight loops (e.g., particles, projectiles, temporary effects).
- Shares immutable configuration data across all instances.
- Maintains a clean, simple API for the caller.

**Example (Game Dev: Projectile/Particle System):**

```lua
-- 1. FLYWEIGHT: Shared, read-only configuration (allocated once at init)
local PROJECTILE_CONFIGS = {
  arrow = { speed = 500, damage = 10, sprite = "arrow.png", mass = 0.5 },
  fireball = { speed = 300, damage = 25, sprite = "fire.png", mass = 2.0 }
}

-- 2. OBJECT POOL: Pre-allocated reusable entity tables
local projectilePool = {}
local activeProjectiles = {}

-- 3. PROTOTYPE + FACADE: The spawner API
local function spawnProjectile(type, x, y, direction)
  -- Pull from pool (O(1) pop), or create new if exhausted (Prototype fallback)
  local p = projectilePool[#projectilePool]
  if p then
    projectilePool[#projectilePool] = nil
  else
    p = {}
  end

  -- Apply Flyweight config + extrinsic state
  local config = PROJECTILE_CONFIGS[type]
  p.x, p.y, p.vx, p.vy = x, y, direction * config.speed, 0
  p.damage, p.sprite = config.damage, config.sprite
  p.active = true

  -- O(1) append (replaces table.insert)
  activeProjectiles[#activeProjectiles + 1] = p
  return p
end

local function despawnProjectile(p)
  p.active = false
  -- Return to pool for reuse (zero GC, O(1) append)
  projectilePool[#projectilePool + 1] = p
end
```

**How it works:**

- **Flyweight** = Data sharer that avoids duplicating static config (`PROJECTILE_CONFIGS`).
- **Object Pool** = Memory saver that recycles tables instead of creating new ones, using O(1) index manipulation.
- **Prototype** = The fallback mechanism; if the pool is empty, a new table is created.
- **Facade** = `spawnProjectile` hides the pooling and prototyping complexity behind a single, clean function call.

---

## Synergy 2: Dynamic Configuration Assembler

**Architectural Role:** Complex Object Construction. Builds objects with many optional, conditional, or interdependent properties without telescoping constructors or massive parameter lists.  
**Core Question Answered:** _"How do I construct complex, multi-variant objects cleanly without passing 10+ arguments or writing repetitive initialization code?"_  
**Patterns Used:** Builder + Strategy + Facade (Creational + Behavioral + Structural).

**Benefits:**

- Highly readable, fluent, or declarative object construction.
- Isolates validation and default-filling logic from the core game loop.
- Avoids the "telescoping constructor" anti-pattern entirely.

**Example (Game Dev: UI Layout or Quest Builder):**

```lua
-- 1. BUILDER: Fluent API returning `self` for chaining
local QuestBuilder = {}
QuestBuilder.__index = QuestBuilder

function QuestBuilder:new()
  return setmetatable({
    title = "Untitled",
    objectives = {},
    reward = { gold = 0, xp = 0 },
    strategy = nil
  }, self)
end

function QuestBuilder:setTitle(title) self.title = title; return self end

-- O(1) append (replaces table.insert)
function QuestBuilder:addObjective(desc)
  self.objectives[#self.objectives + 1] = desc
  return self
end

function QuestBuilder:setReward(gold, xp) self.reward = {gold=gold, xp=xp}; return self end

-- 2. STRATEGY: Swappable validation/completion logic
function QuestBuilder:setCompletionStrategy(strategyFn)
  self.strategy = strategyFn
  return self
end

-- 3. FACADE: Final assembly and validation
function QuestBuilder:build()
  if #self.objectives == 0 then error("Quest must have at least one objective") end
  -- Return a clean, sealed table (no builder methods)
  return {
    title = self.title,
    objectives = self.objectives,
    reward = self.reward,
    checkCompletion = self.strategy or function() return false end
  }
end

-- Usage: Declarative and readable
local myQuest = QuestBuilder:new()
  :setTitle("Slay the Dragon")
  :addObjective("Find the cave")
  :addObjective("Defeat the boss")
  :setReward(500, 1000)
  :setCompletionStrategy(function(q) return #q.objectives == 0 end)
  :build()
```

**How it works:**

- **Builder** = The fluent table methods that accumulate state and return `self`.
- **Strategy** = Injected behavior (e.g., `setCompletionStrategy`) that defines _how_ the object behaves, decoupled from its data.
- **Facade** = The `:build()` method, which validates the accumulated state and returns a clean, finalized object, hiding the builder's internal mechanics.

---

## Synergy 3: Decoupled Instantiator

**Architectural Role:** Routing and Selection. Maps a runtime key (string, enum, config) to a specific creation function without the caller knowing the concrete implementation.  
**Core Question Answered:** _"Which specific entity or subsystem should be instantiated based on runtime context, without the caller knowing the concrete type or requiring massive `if/elseif` chains?"_  
**Patterns Used:** Factory Method + Lookup Table + Mediator (Creational + Lua Primitive + Behavioral).

**Benefits:**

- Replaces verbose conditional branching with Θ(1) hash dispatch.
- Completely decouples the requestor from the creator.
- Hot-reload friendly: new types can be registered at runtime by adding to the lookup table.

**Example (Game Dev: Enemy Spawner or Item Drop):**

```lua
-- 1. LOOKUP TABLE + FACTORY METHOD: Registry of creation functions
local enemyFactories = {
  skeleton = function(x, y) return { type = "skeleton", hp = 50, x = x, y = y } end,
  boss = function(x, y)
    local b = { type = "boss", hp = 500, x = x, y = y }
    -- Boss-specific init logic
    return b
  end
}

-- 2. MEDIATOR: Centralized creation hub with validation
local Spawner = {}
function Spawner.spawn(type, x, y)
  local factory = enemyFactories[type]
  if not factory then
    warn("Unknown enemy type: " .. tostring(type) .. ", falling back to skeleton")
    factory = enemyFactories.skeleton
  end
  return factory(x, y)
end

-- Usage: Caller knows nothing about 'skeleton' or 'boss' internals
local newEnemy = Spawner.spawn("boss", 100, 200)
```

**How it works:**

- **Lookup Table** = The `enemyFactories` dictionary enabling Θ(1) routing.
- **Factory Method** = The anonymous functions stored in the table, each encapsulating the specific creation logic for a type.
- **Mediator** = The `Spawner` module, which centralizes the lookup, provides fallback safety, and acts as the single point of contact for all spawning requests.

---

## Synergy 4: Global State Guardian

**Architectural Role:** Lifecycle Management and Safe Global Access. Provides a single source of truth for shared resources while preventing unauthorized mutation and memory leaks.  
**Core Question Answered:** _"How do I provide global access to a shared resource (like config, audio, or network) while controlling its lifecycle, preventing leaks, and avoiding `_G` pollution?"_  
**Patterns Used:** Singleton + Proxy + Weak Tables (Creational + Structural + Lua Primitive).

**Benefits:**

- Avoids the pitfalls of raw `_G` usage (namespace pollution, unpredictable mutation).
- Enables lazy initialization (resource is only created when first accessed).
- Prevents memory leaks via weak references.

**Example (Game Dev: Asset Cache or Global Config):**

```lua
-- 1. SINGLETON: Module-level closure ensures only one instance exists
local _instance = nil

-- 2. PROXY + WEAK TABLES: Controlled access and auto-GC
local function getAssetCache()
  if not _instance then
    -- Weak values allow the GC to collect assets if no other references exist
    local cache = setmetatable({}, { __mode = "v" })

    _instance = setmetatable({}, {
      __index = function(t, key)
        return cache[key]
      end,
      __newindex = function(t, key, value)
        -- Validation/Interception before assignment
        if type(value) ~= "table" and type(value) ~= "userdata" then
          error("Cache only accepts tables or userdata")
        end
        cache[key] = value
      end
    })
  end
  return _instance
end

-- Usage:
local cache = getAssetCache()
cache["hero_sprite"] = loadSprite("hero.png") -- Intercepted and validated
print(cache["hero_sprite"]) -- Retrieved via __index
```

**How it works:**

- **Singleton** = The `_instance` variable scoped to the module, guaranteeing a single shared state.
- **Proxy** = The metatable with `__index` and `__newindex`, which intercepts reads/writes to add validation, logging, or lazy loading.
- **Weak Tables** = The `{ __mode = "v" }` on the internal cache, ensuring that if the game unloads a scene, the cached assets are automatically garbage-collected, preventing leaks.

---

## Synergy 5: Cross-Platform Family Provider

**Architectural Role:** Subsystem Swapping. Guarantees that a family of related components (e.g., input, rendering, audio) are instantiated together and remain compatible, without hardcoding platform checks throughout the codebase.  
**Core Question Answered:** _"How do I guarantee that a family of related components (e.g., TUI vs. GUI, or Desktop vs. Mobile input) are instantiated together and remain compatible, without scattering `if platform` checks everywhere?"_  
**Patterns Used:** Abstract Factory + Bridge + Module Caching (Creational + Structural + Lua Primitive).

**Benefits:**

- Isolates platform-specific or mode-specific code into dedicated modules.
- Guarantees compatibility (e.g., a TUI renderer only gets a TUI input handler).
- Leverages Lua’s native `require` caching to act as a zero-boilerplate Singleton factory.

**Example (Game Dev: TUI vs. GUI Backend Selection):**

```lua
-- 1. ABSTRACT FACTORY: The interface contract (conceptual)
-- Expected: { createRenderer(), createInputHandler(), createAudioDriver() }

-- 2. MODULE CACHING + BRIDGE: Runtime selection via require
local BUILD = "TUI" -- Set by build script or config

local function getPlatformFactory()
  if BUILD == "TUI" then
    return require("platforms.tui_factory")
  elseif BUILD == "GUI" then
    return require("platforms.gui_factory")
  else
    error("Unknown BUILD target: " .. BUILD)
  end
end

-- Usage in main.lua (Composition Root):
local factory = getPlatformFactory()

-- The rest of the game only talks to the abstracted interfaces:
local renderer = factory.createRenderer()
local input = factory.createInputHandler()

-- Example of Bridge in action inside the factory:
-- platforms.tui_factory.lua
return {
  createRenderer = function()
    return { render = function(state) _TUI_draw(state) end }
  end,
  createInputHandler = function()
    return { poll = function() return _TUI_read_key() end }
  end
}
```

**How it works:**

- **Abstract Factory** = The conceptual contract that the returned module must fulfill (providing a family of related creation methods).
- **Module Caching** = Lua’s native `require` acts as the factory registry and Singleton manager, ensuring the factory module is only loaded and executed once.
- **Bridge** = The factory returns objects that delegate to specific backend implementations (`_TUI_draw`, `_TUI_read_key`), separating the game's abstraction from the platform's implementation.

---

## ✅ Final Takeaway: The Lua Creational Philosophy

In static OOP languages, Creational Patterns are about **managing types and inheritance**.  
In Lua, Creational Patterns are about **managing memory, configuration, and routing**.

By synergizing these patterns, you achieve:

1. **Zero GC Spikes**: Prototype + Pool + Flyweight recycles tables using O(1) index manipulation instead of creating them.
2. **Clean APIs**: Builder + Strategy + Facade replaces 10-argument function calls with readable chains.
3. **Extensibility**: Factory + Lookup + Mediator allows new entity types to be added by simply inserting a row into a table.
4. **Safety**: Singleton + Proxy + Weak Tables provides global access without the dangers of raw `_G` mutation or memory leaks.
5. **Portability**: Abstract Factory + Bridge + `require` caching allows entire subsystems to be swapped at build or runtime with zero game-logic changes.
