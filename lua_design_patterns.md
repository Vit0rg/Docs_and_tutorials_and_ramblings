# Lua Game Development Design Patterns

**Author**: Vit0rg  
**Created**: May 29th 2026  
**Document last updated:** June 1st 2026 | Based on `vit0rg/volley` + `vit0rg/echeckers` architecture review & GoF-to-Lua mapping.
**License**: MIT  

---

## Table of Contents

- [Introduction](#introduction)  
- [Creational Patterns](#creational)  
    - [1. Factory Method](#factory-method)  
    - [2. Abstract Factory](#abstract-factory)  
    - [3. Singleton](#singleton)  
    - [4. Prototype](#prototype)  
    - [5. Builder](#builder)  
- [Structural Patterns](#structural)  
    - [1. Adapter](#adapter)  
    - [2. Bridge](#bridge)  
    - [3. Composite](#composite)  
    - [4. Decorator](#decorator)  
    - [5. Facade](#facade)  
    - [6. Flyweight](#flyweight)  
    - [7. Proxy](#proxy)  
- [Behavioral Patterns](#behavioral)  
    - [1. Chain of Responsibility](#chain-of-responsibility)  
    - [2. Command](#command)  
    - [3. Interpreter](#interpreter)  
    - [4. Iterator](#iterator)  
    - [5. Mediator](#mediator)  
    - [6. Memento](#memento)  
    - [7. Observer](#observer)  
    - [8. State](#state)  
    - [9. Strategy](#strategy)  
    - [10. Template Method](#template-method)  
    - [11. Visitor](#visitor)  


---

## Introduction

### Origin:
> "Design patterns are bug reports against your programming language." - Peter Norvig

Peter Norvig's famous observation stems from the fact that many GoF (Gang of Four) patterns exist primarily to work around limitations of static, compiled, class-based languages like C++ and Java (circa 1994).

When a language has first-class functions, dynamic typing, flexible data structures, and runtime metaprogramming, the implementation of many patterns collapses into a few lines or becomes unnecessary.

Lua shares many of these dynamic traits (though it lacks Lisp's macros and homoiconicity). As a result, roughly 15–18 of the 23 GoF patterns become "invisible" or trivially simple in Lua, while the rest remain conceptually useful but are implemented much more lightly.

### Caveats:
- Lua does not have macros (in the Lisp sense), so there is no compile-time code transformation (no expansion at parse time).
- Code in Lua is compiled bytecode or string, not data (as a type). While Lisp has ASTs (Abstract Syntax Trees), in the form of S-expressions.
- Lua has limited reflection, using `debug.getinfo()` and global environment inspection. There is no native AST manipulation.
- Lua only supports single dispatch (via metatable `__index`), while Lisp supports true multiple dispatch.

| Pattern | Lua Workaround | Cost in Lua |
|---------|----------------|-------------|
| Builder | Manual `_self` returning methods | Verbose chaining, harder to refactor |
| Interpreter | External `LPeg` parser + visitor | Separate parser library overhead |
| Visitor | Type-string dispatch table | Extra `if` branching per visit |
| Command | Manual `table.clone` snapshots | Memory overhead for history |
| Decorator | Closure wrapping | Slight call-chain overhead |
| Proxy | `setmetatable(__call)` interception | Runtime indirection cost |
| Template Method | Higher-order function parameters | Explicit callback passing |

### Key Insights:
- In Lua, ~15 of the 23 GoF patterns "dissolve" into closures, tables, and metatables.
- The remaining patterns retain conceptual value but require 5–10x less boilerplate than traditional OOP.
- Do not implement patterns that already exist natively (Iterator → `for i=1,n`; Singleton → `require()` caching; Observer → callback tables).

| Category | Traditional Cost | Lua Idiomatic Equivalent | Status in Repos (volley / echeckers) |
|----------|------------------|--------------------------|--------------------------------------|
| Creational | Factory hierarchies + class inheritance | Function dispatch tables; options tables | ✅ Fully implemented via closures |
| Structural | Adapter classes + interface duplication | Duck typing; metatable interception | ✅ Facade + Composite present; Proxy unimplemented |
| Behavioral | Strategy interfaces + State classes | Function passing; state function tables | ✅ Strategy/Command fully adopted; Memento missing |

**Critical Note**: Do not implement patterns that already exist natively (Iterator → `for i=1,n`; Singleton → `require()` caching; Observer → callback tables).

---

## Creational Patterns

*Focus on object/entity creation in Lua game engines. Optimized for low GC pressure and fast instantiation.*

### 1. Factory Method

Defines a creation interface where concrete subclasses/functions decide which entity to instantiate.

#### 🛠️ Idiomatic Lua Implementation
Function dispatch tables or conditional closures. Replace class hierarchies with a hash table mapping string IDs to constructor functions.

#### ⚡ Performance Impact
Θ(1) table lookup + O(k) table initialization. Zero inheritance overhead. Fastest when constructors avoid `setmetatable` calls per instance.

#### 🔍 Evidence & Repo Context
`echeckers` uses direct function tables for entity spawning. `volley`'s `CONSUMABLES` and `KEYS` act as implicit factories for game items.

#### 📋 5 Usage Examples (Lua Game Dev)
**Enemy Spawner**
```lua
local function create_enemy(type, x, y)
    if type == "skeleton" then return Skeleton:new(x, y)
    elseif type == "boss" then return Boss:new(x, y) end
    return nil
end
```

**Weapon/Item Generator**
```lua
local function spawn_item(rarity)
    local pool = rarity_drops[rarity]
    local template = pool[math.random(#pool)]
    return Item:new(template.id, template.stats)
end
```

**Particle System Creator**
```lua
local function make_fx(effect_type)
    return particle_configs[effect_type]()  -- Returns pre-configured table
end
```

**Level Tile Factory**
```lua
local function get_tile(biome)
    local base = biome_templates[biome]
    return table.clone(base)  -- Shallow copy for fast reuse
end
```

**UI Widget Creator**
```lua
local function create_widget(kind)
    return ui_factories[kind](parent, config)
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Hash Table/Dictionary (`biome_templates`, `rarity_drops`) for Θ(1) lookup  
**Algorithms**: Conditional dispatch Θ(1), table cloning O(k) for k fields  
**Ref**: Hash Table Θ(1) access

#### 🛠️ Structures Needed (New Methods)
- `create_entity(config)`: Core factory function
- `register_type(id, constructor)`: Runtime registry
- `validate_config(cfg)`: Pre-instantiation sanity checks

#### ⏱️ Expected Implementation Time
- Basic: 1–2 hours
- Registry + validation + pooling: 4–6 hours

#### 🚀 Speed & Memory Performance (Lua)
**Speed**: Θ(1) lookup + O(k) table init. Fast if avoiding `setmetatable` per call.  
**Memory**: O(k) registry + O(1) per instance. Avoids GC spikes if reusing tables.

#### ✅ Pros & ❌ Cons
**Pros**: Decouples spawner from entity code, easy to add new enemies/items, hot-reload friendly  
**Cons**: Can fragment creation logic, overuse causes table allocation overhead

#### 🔗 Relations
Base for Abstract Factory, pairs with Object Pool (reuses instances), alternative to direct `new()` calls

---

### 2. Abstract Factory

Creates families of related game objects without specifying concrete classes.

#### 🛠️ Idiomatic Lua Implementation
Family resolution tables or closure capturing. A single function returns a table of related constructors, or platform/config flags route to pre-initialized backend tables.

#### ⚡ Performance Impact
Θ(1) dispatch + O(m) for m component creations. Slightly higher than Factory Method due to multi-object assembly, but avoids parallel inheritance trees.

#### 🔍 Evidence & Repo Context
Implicitly used in `volley` for platform routing (mobile/desktop input/audio). `echeckers` `BUILD` variable routes rendering backends without factory classes.

#### 📋 5 Usage Examples
**Cross-Platform Input Factory**
```lua
local function get_input_factory()
    if LOVE_OS == "android" then return TouchInputFactory()
    elseif LOVE_OS == "desktop" then return KeyboardMouseFactory() end
end
```

**Renderer Backend Factory**
```lua
local function create_render_pipeline(mode)
    if mode == "opengl" then return GLPipeline()
    elseif mode == "vulkan" then return VulkanPipeline() end
end
```

**Audio System Factory**
```lua
local function get_audio_driver()
    return platform == "mobile" and MobileAudioFactory() or DesktopAudioFactory()
end
```

**Save/Load Format Factory**
```lua
local function create_serializer(fmt)
    return fmt == "json" and JsonSerializer() or BinarySerializer()
end
```

**Network Sync Factory**
```lua
local function get_sync_strategy()
    return network_mode == "rollback" and RollbackSync() or FrameSync()
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Dictionary (factory registry), Tree (family hierarchy)  
**Algorithms**: Family resolution Θ(1), multi-object creation O(m)  
**Ref**: Hash Table Θ(1) access, Tree Θ(log n) for family navigation

#### 🛠️ Structures Needed
- `create_component_a()`, `create_component_b()`: Family methods
- `switch_backend(factory)`: Runtime hot-swap
- `validate_family()`: Ensures compatibility

#### ⏱️ Expected Implementation Time
- 4–8 hours (basic)
- 1–2 days (full registry + hot-swap)

#### 🚀 Speed & Memory Performance
**Speed**: Θ(1) dispatch, O(m) for m components  
**Memory**: O(k) factories + O(m) per family. Slightly higher than Factory Method

#### ✅ Pros & ❌ Cons
**Pros**: Guarantees compatible backends, isolates platform code, easy A/B testing  
**Cons**: Verbose table structures, harder to debug cross-family calls

#### 🔗 Relations
Built on Factory Method, pairs with Bridge (abstraction/impl split), replaces massive `if platform` blocks

---

### 3. Singleton

Ensures one instance per system, providing global access without `_G` pollution.

#### 🛠️ Idiomatic Lua Implementation
`require()` module caching or module-scoped local tables. Lua's module system guarantees a single loaded instance per path. Manual lazy-init wrappers are rarely needed.

#### ⚡ Performance Impact
Θ(1) after first load. Zero allocation on subsequent `require()` calls. Module-level state avoids `_G` lookup penalties.

#### 🔍 Evidence & Repo Context
Both repos rely on module caching for `Board`, `Events`, and `Config`. `echeckers` uses file-scoped tables as singletons; `volley` caches network state in `require`d modules.

#### 📋 5 Usage Examples
**Game Config Manager**
```lua
local _instance = nil
local function Config()
    if not _instance then _instance = { data = load_json("config.json") } end
    return _instance
end
```

**Audio Engine Hub**
```lua
local Audio = { channels = {}, mixer = nil }
function Audio.init() if not Audio.mixer then Audio.mixer = love.audio.newSource() end end
```

**Event Bus**
```lua
local Events = { _listeners = {} }
function Events:emit(name, ...) for _,cb in ipairs(self._listeners[name] or {}) do cb(...) end end
```

**Asset Cache**
```lua
local Cache = { _store = setmetatable({}, {__mode = "k"}) }  -- Weak keys for auto-GC
```

**Input State Tracker**
```lua
local Input = { keys = {}, mouse = {} }
function Input.update() -- polls love.keyboard/mouse once per frame end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Hash Table (config/data), Queue (event queue), Weak Table (cache)  
**Algorithms**: Lazy init Θ(1), lookup Θ(1), queue ops Θ(1)  
**Ref**: Queue Θ(1) enqueue/dequeue, Hash Table Θ(1) avg

#### 🛠️ Structures Needed
- `get_instance()`: Module-level cache
- `reset()`: For testing/hot-reload
- `is_initialized()`: State guard

#### ⏱️ Expected Implementation Time
- 30 mins (basic)
- 1–2 hours (thread-safe coroutines + GC-aware)

#### 🚀 Speed & Memory Performance
**Speed**: Θ(1) after init. Avoids repeated file I/O or init calls  
**Memory**: O(1) instance + O(n) data. Weak tables prevent leaks

#### ✅ Pros & ❌ Cons
**Pros**: Centralized state, avoids `_G`, easy hot-reload if reset-implemented  
**Cons**: Hidden dependencies, hard to unit test, can cause GC pressure if overused

#### 🔗 Relations
Replaced by Dependency Injection in modern Lua, pairs with Proxy (lazy access), often misused as global state

---

### 4. Prototype

Creates new entities by cloning existing tables instead of re-running constructors.

#### 🛠️ Idiomatic Lua Implementation
`table.clone()` (Lua 5.4+) or custom shallow/deep copy functions. Combine with closure overrides or metatable `__index` for variant differentiation.

#### ⚡ Performance Impact
O(k) for shallow copy, O(n) for deep. Faster than constructor chains but can spike GC if deep-nested. Avoid circular references.

#### 🔍 Evidence & Repo Context
`echeckers` uses `Table.copy()` for hand/board snapshots. `volley` clones projectile/particle configs for pooling.

#### 📋 5 Usage Examples
**Enemy Variant Spawner**
```lua
local base_orc = { hp = 100, atk = 15, sprite = "orc.png" }
local function spawn_variant(base, mods)
    local clone = table.clone(base)
    for k,v in pairs(mods) do clone[k] = v end
    return clone
end
```

**Projectile Pooling**
```lua
local bullet_proto = { speed = 500, lifetime = 2.0, damage = 10 }
function pool:acquire() return table.clone(bullet_proto) end
```

**Skill Tree Template**
```lua
local skill_base = { cost = 0, level = 1, unlocks = {} }
local function new_skill(type) return table.merge(skill_base, type_config) end
```

**Dialogue Node Cloning**
```lua
local node_template = { text = "", choices = {}, next_id = nil }
local function create_node(id, text)
    local n = table.clone(node_template); n.id = id; n.text = text; return n
end
```

**Particle Burst**
```lua
local proto = { vx = 0, vy = 0, life = 1.0, size = 4 }
function spawn_burst(count)
    for i=1,count do table.insert(active, table.clone(proto)) end
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Array/List (object fields), Tree (nested properties)  
**Algorithms**: Shallow copy O(k), deep copy O(n) traversal  
**Ref**: Array/List Θ(n) traversal, Tree Θ(n) node visitation

#### 🛠️ Structures Needed
- `clone()`: Shallow/deep copy function
- `initialize(clone, overrides)`: Post-clone setup
- `register_proto(id, table)`: Prototype registry

#### ⏱️ Expected Implementation Time
- 1–2 hours (shallow)
- 3–5 hours (deep copy + circular ref handling)

#### 🚀 Speed & Memory Performance
**Speed**: O(k) copy time. Much faster than metatable-heavy constructors  
**Memory**: O(k) per clone. Can spike with deep nested tables

#### ✅ Pros & ❌ Cons
**Pros**: Avoids init overhead, preserves runtime-tuned state, hot-swappable  
**Cons**: Deep copy complexity, reference aliasing bugs, circular graph crashes

#### 🔗 Relations
Alternative to Factory Method, pairs with Command (state snapshots), complements Memento

---

### 5. Builder

Step-by-step construction of complex game objects using fluent Lua APIs.

#### 🛠️ Idiomatic Lua Implementation
Options tables (`create{a=1, b="x"}`) or fluent metatable chaining (`return self`). Lua lacks macros, so verbose `:step():build()` chains must be written manually.

#### ⚡ Performance Impact
Θ(1) per step, O(n) final assembly. Fluent chaining adds slight call overhead vs options tables. Reusable builders minimize GC.

#### 🔍 Evidence & Repo Context
`echeckers` and `volley` prefer options tables for entity config. Fluent builders exist in UI/query systems but are avoided in hot game loops.

#### 📋 5 Usage Examples
**UI Layout Builder**
```lua
local Panel = {}
function Panel:new() return setmetatable({ children = {}, padding = 0 }, {__index = self}) end
function Panel:add(child) table.insert(self.children, child); return self end
function Panel:padding(v) self.padding = v; return self end
function Panel:build() return self end
```

**Query/Rule Builder**
```lua
local Query = {}
function Query:select(fields) self.fields = fields; return self end
function Query:where(cond) table.insert(self.conditions, cond); return self end
function Query:execute() return db:run(self) end
```

**Dialogue Tree Builder**
```lua
local Dialog = {}
function Dialog:start(text) self.root = {text=text, branches={}}; return self end
function Dialog:add_choice(text, next_id) table.insert(self.root.branches, {text, next_id}); return self end
function Dialog:finalize() save_dialog(self.root); return self end
```

**Particle Emitter Config**
```lua
local Emitter = {}
function Emitter:rate(v) self.rate = v; return self end
function Emitter:speed(min, max) self.speed = {min, max}; return self end
function Emitter:build() return ParticleSystem.new(self) end
```

**Level Generator**
```lua
local Level = {}
function Level:size(w, h) self.w, self.h = w, h; return self end
function Level:biome(b) self.biome = b; return self end
function Level:generate() return generate_procedural(self) end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: List/Array (step accumulator), Dictionary (config state)  
**Algorithms**: Fluent chaining Θ(1) per call, validation O(m), assembly O(n)  
**Ref**: Array/List Θ(1) append, Stack Θ(1) push/pop

#### 🛠️ Structures Needed
- `stepX()`: Configuration setters returning `self`
- `build()`: Final assembly & validation
- `reset()`: Clear builder state for reuse

#### ⏱️ Expected Implementation Time
- 2–4 hours (basic)
- 1 day (validation + undo/redo)

#### 🚀 Speed & Memory Performance
**Speed**: Θ(1) per step, O(n) final build  
**Memory**: O(n) intermediate state. Low GC pressure if reused

#### ✅ Pros & ❌ Cons
**Pros**: Readable construction, optional params, avoids telescoping args  
**Cons**: Verbose tables, requires separate builder object, overkill for simple entities

#### 🔗 Relations
Complements Factory Method (complex products), pairs with Command (undo steps), alternative to giant config tables

---

## Structural Patterns

*Focus on composition, hierarchy, and interface adaptation in Lua game systems.*

### 1. Adapter

Bridges incompatible Lua APIs or legacy systems into a unified interface.

#### 🛠️ Idiomatic Lua Implementation
Thin wrapper functions or duck typing. Lua's dynamic typing often removes the need entirely; only wrap when API surfaces mismatch significantly.

#### ⚡ Performance Impact
O(n) for data translation, Θ(1) for dispatch. Wrapper calls add negligible overhead if inlined or cached.

#### 🔍 Evidence & Repo Context
`volley` wraps legacy packet formats into v2 structures. `echeckers` adapts input mappings (gamepad → touch zones) via lookup tables.

#### 📋 5 Usage Examples
**Legacy Save Format**
```lua
local function adapt_old_save(old_data)
    return { version = 2, player = old_data.p, inventory = convert_items(old_data.inv) }
end
```

**Third-Party Plugin Wrapper**
```lua
local AnalyticsAdapter = {}
function AnalyticsAdapter:track(event) ExternalSDK.log(event) end
```

**Input Abstraction**
```lua
local function get_action(input_type)
    if input_type == "gamepad" then return gamepad_to_kb_mapping
    elseif input_type == "touch" then return touch_zones end
end
```

**Data Format Converter**
```lua
local function csv_to_records(raw)
    local rows = split(raw, "\n")
    for _,row in ipairs(rows) do table.insert(records, parse_row(row)) end
end
```

**Legacy DB Wrapper**
```lua
local function adapt_stored_proc_to_orm(proc_name, args)
    return db.query(proc_name, unpack(args))
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Dictionary (mapping rules), List (transformation pipeline)  
**Algorithms**: Interface translation O(k), data mapping O(n)  
**Ref**: Dictionary Θ(1) mapping, Array/List O(n) traversal

#### 🛠️ Structures Needed
- `adapt()`: Interface translation
- `translate(data)`: Format conversion
- `validate()`: Compatibility guard

#### ⏱️ Expected Implementation Time
- 1–3 hours (simple)
- 4–8 hours (complex protocol mapping)

#### 🚀 Speed & Memory Performance
**Speed**: O(n) translation, Θ(1) dispatch  
**Memory**: O(n) temp tables, O(1) adapter instance

#### ✅ Pros & ❌ Cons
**Pros**: Enables legacy integration, isolates breaking changes, reusable  
**Cons**: Adds indirection, maintenance-heavy if target API changes

#### 🔗 Relations
Similar to Bridge (different intent), pairs with Facade (simplifies complex adaptees), alternative to Proxy

---

### 2. Bridge

Separates entity abstraction (what it does) from implementation (how it renders/syncs).

#### 🛠️ Idiomatic Lua Implementation
Composition: abstraction table holds reference to impl table. Swap at runtime via simple assignment (`self.renderer = new_impl`).

#### ⚡ Performance Impact
Θ(1) delegation overhead. No inheritance traversal; direct table field lookup is extremely fast.

#### 🔍 Evidence & Repo Context
`echeckers/UI.update_board` routes to `TUI_update_board` or `CLI_update_board` based on `BUILD` flag, implementing implicit bridge.

#### 📋 5 Usage Examples
**Entity Rendering**
```lua
local Entity = { renderer = nil }
function Entity:draw() self.renderer:render(self) end
function Entity:set_renderer(r) self.renderer = r end
```

**Notification System**
```lua
local Notifier = { sender = nil }
function Notifier:send(msg) self.sender:deliver(msg) end
```

**Network Sync**
```lua
local Syncable = { strategy = nil }
function Syncable:update(dt) self.strategy:apply(self, dt) end
```

**Database Access**
```lua
local Repo = { driver = nil }
function Repo:save(entity) self.driver:insert(entity:serialize()) end
```

**UI Rendering**
```lua
local Widget = { engine = nil }
function Widget:render() self.engine:draw(self.props) end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Composition (has-a relationship), Interface registry  
**Algorithms**: Delegation Θ(1), strategy selection O(1)  
**Ref**: Hash Table Θ(1) for implementor selection

#### 🛠️ Structures Needed
- `set_impl(impl)`: Runtime swapping
- `execute()`: Delegation point
- `sync_context()`: Shared state sync

#### ⏱️ Expected Implementation Time
- 2–4 hours (basic)
- 1 day (full decoupling + config)

#### 🚀 Speed & Memory Performance
**Speed**: Θ(1) delegation overhead  
**Memory**: O(1) per abstraction + O(1) per implementor

#### ✅ Pros & ❌ Cons
**Pros**: Independent evolution, avoids class explosion, runtime flexibility  
**Cons**: More tables, slightly harder to trace execution flow

#### 🔗 Relations
Pairs with Abstract Factory, replaces inheritance hierarchies, similar to Strategy (focuses on interface vs algorithm)

---

### 3. Composite

Treats individual game objects and hierarchies uniformly.

#### 🛠️ Idiomatic Lua Implementation
Nested tables with recursive `for` loops. `__index` metatables handle leaf/composite delegation automatically.

#### ⚡ Performance Impact
O(n) traversal for operations. Deep trees increase call stack; iterative BFS/DFS preferred for >1000 nodes.

#### 🔍 Evidence & Repo Context
Scene graphs in `volley` and UI trees in `echeckers` use flat `children` arrays with uniform `update()`/`draw()` loops.

#### 📋 5 Usage Examples
**Scene Graph**
```lua
local Node = {}
function Node:add(child) table.insert(self.children, child) end
function Node:update(dt) for _,c in ipairs(self.children) do c:update(dt) end end
```

**UI Components**
```lua
local Container = { children = {} }
function Container:draw() for _,c in ipairs(self.children) do c:draw() end end
```

**Org Chart / Party System**
```lua
local Group = { members = {} }
function Group:get_power() local s=0; for _,m in ipairs(self.members) do s=s+m.power end return s end
```

**Particle Groups**
```lua
local EmitterGroup = { emitters = {} }
function EmitterGroup:emit(dt) for _,e in ipairs(self.emitters) do e:emit(dt) end end
```

**Menu System**
```lua
local Submenu = { items = {} }
function Submenu:render() for _,i in ipairs(self.items) do i:render() end end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Tree (hierarchical nodes), Array/List (children)  
**Algorithms**: Recursive traversal O(n), aggregation Θ(n)  
**Ref**: Tree Θ(n) traversal, Array/List Θ(n) sum/access

#### 🛠️ Structures Needed
- `add(child)`, `remove(child)`: Tree management
- `get_child(index)`: Navigation
- `operation()`: Uniform leaf/composite behavior

#### ⏱️ Expected Implementation Time
- 2–4 hours (basic)
- 1 day (with validation + traversal modes)

#### 🚀 Speed & Memory Performance
**Speed**: O(n) traversal for operations  
**Memory**: O(n) nodes + O(1) per child reference

#### ✅ Pros & ❌ Cons
**Pros**: Uniform interface, easy hierarchy manipulation, recursive simplicity  
**Cons**: Type safety issues (leaf vs composite methods), can overgeneralize

#### 🔗 Relations
Pairs with Iterator (traversal), Decorator (wrapping nodes), Visitor (external ops on tree)

---

### 4. Decorator

Adds behavior to entities dynamically without modifying core tables.

#### 🛠️ Idiomatic Lua Implementation
Closure wrapping or metatable `__index`/`__call` interception. Lua lacks macros, so chaining is manual and limited to ~3 layers for performance.

#### ⚡ Performance Impact
O(k) per operation (k=layers). Closure capture adds slight overhead; deep nesting degrades call speed. Pre-compute when possible.

#### 🔍 Evidence & Repo Context
`echeckers` `build_colored_text()` wraps ANSI codes. `volley` uses closure wrappers for metrics/logging. No heavy decorator chains in hot paths.

#### 📋 5 Usage Examples
**Buff/Debuff System**
```lua
local function apply_buff(entity, buff_fn)
    local old_update = entity.update
    entity.update = function(self, dt) buff_fn(self); old_update(self, dt) end
end
```

**Stream Processing**
```lua
local function compress_stream(stream)
    return { read = function() return decompress(stream.read()) end }
end
```

**Metrics Wrapper**
```lua
local function timed_service(service)
    return { execute = function(...) 
        local t=love.timer.getTime(); 
        local r=service.execute(...); 
        print(love.timer.getTime()-t); 
        return r 
    end }
end
```

**Text Formatting**
```lua
local function wrap_bold(widget)
    return { render = function() 
        love.graphics.printf("<b>" .. widget.render() .. "</b>") 
    end }
end
```

**Cache Layer**
```lua
local function memoize(fn)
    local cache = {}
    return function(...) 
        local k = table.concat({...}, ","); 
        return cache[k] or (cache[k] = fn(...)) 
    end
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Linked structure (chain of decorators), Hash Table (cache)  
**Algorithms**: Chain delegation Θ(1) per layer, cache lookup Θ(1)  
**Ref**: Hash Table Θ(1) access, Linked traversal O(k) layers

#### 🛠️ Structures Needed
- `wrap(component)`: Wrapping function
- `operation()`: Forward + extend
- `unwrap()`: Optional restoration

#### ⏱️ Expected Implementation Time
- 1–2 hours (basic)
- 3–5 hours (multiple layers + config)

#### 🚀 Speed & Memory Performance
**Speed**: O(k) per operation (k=layers). Can degrade if deeply nested  
**Memory**: O(k) wrapper tables. Cache adds O(n) storage

#### ✅ Pros & ❌ Cons
**Pros**: Open/Closed, runtime composition, avoids table mutation  
**Cons**: Many small closures, debugging chain is hard, breaks `type()` checks

#### 🔗 Relations
Alternative to inheritance, pairs with Strategy (behavior swapping), similar to Proxy (but focuses on adding behavior)

---

### 5. Facade

Provides a simplified interface to complex Lua subsystems.

#### 🛠️ Idiomatic Lua Implementation
Module exposing curated functions over internal tables/closures. Acts as a thin API surface; subsystems remain encapsulated.

#### ⚡ Performance Impact
O(m) sequential calls. Zero algorithmic overhead. Best when facade methods are inlined or pre-bound.

#### 🔍 Evidence & Repo Context
`echeckers/BoardOps` facade wraps flat board table. `volley` core module abstracts networking/socket handling.

#### 📋 5 Usage Examples
**Game Loop Manager**
```lua
local Game = {}
function Game.run() init(); while running do update(); render(); love.timer.sleep(1/60) end end
```

**Save System**
```lua
local Save = {}
function Save.quick_save() serialize(Game.state, "save.dat"); notify("Saved") end
```

**Asset Pipeline**
```lua
local Assets = {}
function Assets.load_scene(name) 
    return load_textures(name) + load_audio(name) + load_map(name) 
end
```

**Networking**
```lua
local Net = {}
function Net.send_move(player, dx, dy) 
    return rpc.call("move", {id=player, dx=dx, dy=dy}) 
end
```

**Audio Mixer**
```lua
local Mixer = {}
function Mixer.play_music(track) 
    stop_all(); set_vol("music", 0.7); play(track) 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Composition (subsystem references), Configuration map  
**Algorithms**: Sequential orchestration O(m) for m subsystems  
**Ref**: Array/List O(m) orchestration, Dictionary Θ(1) config lookup

#### 🛠️ Structures Needed
- `simplified_operation()`: Unified entry point
- `configure_subsystem()`: Optional setup
- `reset_state()`: Cleanup/rollback

#### ⏱️ Expected Implementation Time
- 1–3 hours (basic)
- 4–8 hours (error handling + rollback)

#### 🚀 Speed & Memory Performance
**Speed**: O(m) sequential calls. No algorithmic overhead  
**Memory**: O(1) facade instance + O(k) subsystem references

#### ✅ Pros & ❌ Cons
**Pros**: Reduces complexity, decouples client from subsystems, clean API  
**Cons**: Can become god table, hides subsystem capabilities, bottleneck risk

#### 🔗 Relations
Pairs with Abstract Factory (creates subsystems), similar to Mediator (but Mediator is peer-to-peer, Facade is client-to-subsystem)

---

### 6. Flyweight

Reduces memory by sharing common game assets/state across many entities.

#### 🛠️ Idiomatic Lua Implementation
Hash table cache + weak tables (`__mode="v"` or `"k"`). Memoize intrinsic state; store extrinsic state externally.

#### ⚡ Performance Impact
Θ(1) cache hit, Θ(n) cold start. Drastically reduces allocations. Weak tables prevent unbounded memory growth.

#### 🔍 Evidence & Repo Context
`volley`'s `KEYS`/`CONSUMABLES` tables cache shared configs. `echeckers` shares biome/animal definitions across board instances.

#### 📋 5 Usage Examples
**Tile Map Rendering**
```lua
local tile_cache = {}
function get_tile(type)
    if not tile_cache[type] then tile_cache[type] = load_sprite(type) end
    return tile_cache[type]
end
```

**Animation Frames**
```lua
local anim_registry = {}
function play_anim(name) return anim_registry[name] or load_anim(name) end
```

**String Interning**
```lua
local strings = setmetatable({}, {__mode = "v"})
function intern(s) 
    if not strings[s] then strings[s] = s end 
    return strings[s] 
end
```

**Network Connections**
```lua
local conn_pool = setmetatable({}, {__mode = "v"})
function get_conn(host) return conn_pool[host] or connect(host) end
```

**Particle Types**
```lua
local types = {}
function get_particle_type(config) 
    local k = serialize(config); 
    return types[k] or load(config) 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Hash Table (cache), Weak Tables (`__mode = "k"` or `"v"`)  
**Algorithms**: Cache lookup Θ(1), key generation O(k), shared state Θ(1)  
**Ref**: Hash Table Θ(1) avg access, Set Θ(1) membership check

#### 🛠️ Structures Needed
- `get_or_create(key)`: Cache management
- `apply(intrinsic, extrinsic)`: Shared + unique data
- `cleanup()`: Manual GC trigger if needed

#### ⏱️ Expected Implementation Time
- 1–2 hours (basic)
- 3–4 hours (thread-safe + eviction)

#### 🚀 Speed & Memory Performance
**Speed**: Θ(1) cache hit, Θ(n) cold start  
**Memory**: O(u) unique flyweights vs O(n) duplicates. Massive GC savings

#### ✅ Pros & ❌ Cons
**Pros**: Drastically reduces allocations, fast shared access, scalable  
**Cons**: Increases table complexity, extrinsic state management overhead

#### 🔗 Relations
Pairs with Composite (tree nodes), Factory Method (creation control), alternative to Prototype for shared resources

---

### 7. Proxy

Acts as a placeholder to control access, delay loading, or add debug/logging.

#### 🛠️ Idiomatic Lua Implementation
Metatable interception (`__index`, `__newindex`, `__call`). Forward to real object after validation/lazy init.

#### ⚡ Performance Impact
Θ(1) indirection. Runtime validation adds branch overhead. Best used for IO/async; avoid in tight physics loops.

#### 🔍 Evidence & Repo Context
Not yet implemented. Recommended for `BoardOps` validation in `echeckers` to prevent invalid moves from corrupting state.

#### 📋 5 Usage Examples
**Lazy Asset Loader**
```lua
local LazyImage = {}
function LazyImage:draw() 
    if not self.real then 
        self.real = love.graphics.newImage(self.path) 
    end 
    self.real:draw() 
end
```

**Access Control**
```lua
local SecureProxy = {}
function SecureProxy:execute() 
    if auth.check() then 
        self.real:execute() 
    else 
        error("denied") 
    end 
end
```

**Caching Proxy**
```lua
local CacheProxy = {}
function CacheProxy:get(id) 
    return self.cache[id] or (self.cache[id] = self.real:get(id)) 
end
```

**Remote API Wrapper**
```lua
local RemoteProxy = {}
function RemoteProxy:call(args) 
    return http.post(self.url, serialize(args)) 
end
```

**Debug/Logging Proxy**
```lua
local LogProxy = {}
function LogProxy:query(sql) 
    log("SQL: " .. sql); 
    return self.real:query(sql) 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Hash Table (cache), Queue (request buffering), Reference (real object)  
**Algorithms**: Interception Θ(1), lazy init O(1) amortized, cache lookup Θ(1)  
**Ref**: Hash Table Θ(1) avg, Queue Θ(1) enqueue/dequeue

#### 🛠️ Structures Needed
- `check_access()`: Permission guard
- `init_real()`: Lazy loading
- `log_call()`: Interception
- `forward()`: Delegation

#### ⏱️ Expected Implementation Time
- 1–3 hours (basic)
- 4–6 hours (security + caching + network)

#### 🚀 Speed & Memory Performance
**Speed**: Θ(1) interception overhead. Can improve via caching  
**Memory**: O(1) proxy + O(n) deferred real object

#### ✅ Pros & ❌ Cons
**Pros**: Lazy loading, access control, transparent enhancement  
**Cons**: Extra indirection, debugging complexity, can mask latency

#### 🔗 Relations
Similar to Decorator (but focuses on control), pairs with Factory (lazy creation), alternative to Singleton for global access

---

## Behavioral Patterns

*Focus on communication, state management, and algorithm routing in Lua game loops.*

### 1. Chain of Responsibility

Passes input/events along a Lua table chain until handled.

#### 🛠️ Idiomatic Lua Implementation
Array of functions with early `return`. Iterate until predicate matches; no successor links required.

#### ⚡ Performance Impact
O(k) worst-case, Θ(1) if early match. Short chains are fast; long chains degrade loop performance.

#### 🔍 Evidence & Repo Context
`echeckers` validation pipeline in `standby_phase.lua` chains move validators. `volley` uses middleware arrays for packet filtering.

#### 📋 5 Usage Examples
**Input Routing**
```lua
local function handle_input(chain, event)
    for _,handler in ipairs(chain) do 
        if handler.can_handle(event) then 
            handler.process(event); 
            return true 
        end 
    end
    return false
end
```

**Logging Levels**
```lua
local log_chain = {debug_handler, info_handler, warn_handler, error_handler}
function log(level, msg) 
    for h in log_chain do 
        if h.level >= level then h.write(msg) end 
    end 
end
```

**Approval Workflow**
```lua
local approvers = {manager, director, ceo}
function approve(amount) 
    for a in approvers do 
        if a.limit >= amount then 
            return a.grant() 
        end 
    end 
end
```

**Middleware Pipeline**
```lua
local middleware = {auth, validate, cache, handler}
function process(req) 
    for m in middleware do 
        req = m.process(req) 
        if req.halted then return end 
    end 
end
```

**Exception Recovery**
```lua
local handlers = {retry, fallback, log_and_fail}
function handle_err(e) 
    for h in handlers do 
        if h.can_fix(e) then 
            return h.fix(e) 
        end 
    end 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Linked List (handler chain), Queue (pending requests)  
**Algorithms**: Sequential traversal O(k), early exit Θ(1)  
**Ref**: Linked List Θ(n) access, Queue Θ(1) ops

#### 🛠️ Structures Needed
- `set_next(handler)`: Chain linking
- `handle_request(req)`: Processing logic
- `can_handle(req)`: Predicate check

#### ⏱️ Expected Implementation Time
- 1–3 hours (basic)
- 4–6 hours (dynamic chain + priority)

#### 🚀 Speed & Memory Performance
**Speed**: O(k) worst-case, Θ(1) if early match  
**Memory**: O(k) chain tables. Low overhead

#### ✅ Pros & ❌ Cons
**Pros**: Decouples sender/receiver, flexible ordering, open for extension  
**Cons**: Request can be unhandled, debugging chain is hard, performance degrades with long chains

#### 🔗 Relations
Pairs with Command (request encapsulation), similar to Decorator (wrapping), alternative to large `if/elseif` trees

---

### 2. Command

Encapsulates game actions as tables/funcs, enabling undo, queuing, and replay.

#### 🛠️ Idiomatic Lua Implementation
Closures capturing state + `.execute()`/`.undo()` fields. No command classes; tables or functions act as commands.

#### ⚡ Performance Impact
Θ(1) dispatch, O(n) memory for history. Closure creation is cheap; history growth requires ring buffers.

#### 🔍 Evidence & Repo Context
`echeckers` action table (`actions[input]()`) implements implicit command dispatch. Undo stack not yet implemented.

#### 📋 5 Usage Examples
**Text Editor Undo/Redo**
```lua
local InsertCmd = { 
    execute = function(e,t) e:add(t) end, 
    undo = function(e,t) e:remove(t) end 
}
```

**Input Buffering**
```lua
local cmd_queue = {}
function buffer_input(cmd) table.insert(cmd_queue, cmd) end
function process_frame() 
    while #cmd_queue > 0 do 
        table.remove(cmd_queue, 1):execute() 
    end 
end
```

**Task Queue**
```lua
local job = { 
    execute = function() fetch() end, 
    rollback = function() cleanup() end 
}
queue:push(job)
```

**Macro Recorder**
```lua
local macro = { commands = {} }
function macro:record(cmd) table.insert(self.commands, cmd) end
function macro:play() 
    for _,c in ipairs(self.commands) do 
        c:execute() 
    end 
end
```

**Transaction Manager**
```lua
local tx = { 
    execute = function() db.begin() end, 
    commit = function() db.commit() end, 
    rollback = function() db.rollback() end 
}
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Stack/Deque (undo/redo), Queue (task execution), List (macros)  
**Algorithms**: FIFO/LIFO processing Θ(1) per op, sequential O(n)  
**Ref**: Stack Θ(1) push/pop, Queue Θ(1) enqueue/dequeue

#### 🛠️ Structures Needed
- `execute()`: Action
- `undo()`: Reversal
- `can_undo()`: State check
- `serialize()`: Persistence (optional)

#### ⏱️ Expected Implementation Time
- 2–4 hours (basic)
- 1–2 days (with history + persistence)

#### 🚀 Speed & Memory Performance
**Speed**: Θ(1) dispatch, O(n) for macro/queue execution  
**Memory**: O(n) command history. Can grow large if not capped

#### ✅ Pros & ❌ Cons
**Pros**: Decouples invoker/receiver, easy undo/redo, supports queuing/logging  
**Cons**: Many small tables/closures, memory overhead for history, complex state management

#### 🔗 Relations
Pairs with Memento (state capture), Mediator (coordination), alternative to direct function calls

---

### 3. Interpreter

Parses and evaluates custom Lua game DSLs or expressions.

#### 🛠️ Idiomatic Lua Implementation
Table-based AST + recursive evaluator or external `lpeg` parser. Lua lacks homoiconicity, so DSLs require explicit tokenization/evaluation logic.

#### ⚡ Performance Impact
O(n) parse + O(n) evaluate. High overhead vs native Lua. Use only for complex rule engines; prefer table dispatch for simple cases.

#### 🔍 Evidence & Repo Context
Not present. `echeckers` card abilities use direct `card_abilities[card.type]` dispatch instead of parsing DSL strings.

#### 📋 5 Usage Examples
**Math Expression Evaluator**
```lua
local function eval(node) 
    if node.type == "add" then 
        return eval(node.left) + eval(node.right) 
    end 
end
```

**Dialogue DSL**
```lua
local function run_dialog(script) 
    for line in script:gmatch("[^\r\n]+") do 
        execute_line(line) 
    end 
end
```

**SQL-like Query Parser**
```lua
local function parse_query(str) 
    local tokens = tokenize(str); 
    return build_ast(tokens) 
end
```

**Config DSL**
```lua
local function load_config(str) 
    for k,v in str:gmatch("(%w+)%s*=%s*(.+)") do 
        config[k] = parse_val(v) 
    end 
end
```

**Rule Engine**
```lua
local function check_rule(ctx, rule) 
    if rule.op == "and" then 
        return check(ctx, rule.l) and check(ctx, rule.r) 
    end 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Tree (AST), Stack (parsing), Dictionary (context/symbols)  
**Algorithms**: Recursive descent O(n), tokenization O(n), evaluation O(n)  
**Ref**: Tree Θ(n) traversal, Stack Θ(1) push/pop, Dictionary Θ(1) lookup

#### 🛠️ Structures Needed
- `interpret(context)`: Evaluation
- `parse(tokens)`: Grammar conversion
- `evaluate(node)`: AST traversal

#### ⏱️ Expected Implementation Time
- 1–2 days (simple DSL)
- 1–3 weeks (full parser/grammar)

#### 🚀 Speed & Memory Performance
**Speed**: O(n) parse + O(n) evaluate. Dominated by AST depth  
**Memory**: O(n) tree nodes + O(k) context map

#### ✅ Pros & ❌ Cons
**Pros**: Flexible grammar, easy to extend rules, clean separation of syntax/logic  
**Cons**: Complex to build/maintain, performance overhead, overkill for simple conditions

#### 🔗 Relations
Pairs with Visitor (AST traversal), Command (executable rules), alternative to hard-coded `if/else` logic

---

### 4. Iterator

Sequential access to game collections without exposing table internals.

#### 🛠️ Idiomatic Lua Implementation
Native `for i=1,n` or generator closures returning `next, state, init`. Lua's `for ... in` is built-in; custom iterators are rarely needed.

#### ⚡ Performance Impact
Θ(1) per step. Generator closures add minimal overhead; C-style loops are faster in tight paths.

#### 🔍 Evidence & Repo Context
Both repos enforce `for i=1,n` per coding standards. `echeckers` board traversal uses index loops; `volley` uses array iteration.

#### 📋 5 Usage Examples
**List Traversal**
```lua
local function iter(tbl) 
    local i = 0; 
    return function() 
        i=i+1; 
        return tbl[i] 
    end 
end
for val in iter(my_list) do process(val) end
```

**Tree Traversal**
```lua
local function inorder(node) 
    if not node then return end; 
    inorder(node.left); 
    yield(node); 
    inorder(node.right) 
end
```

**Database Cursor**
```lua
local function db_iter(query) 
    local offset=0; 
    return function() 
        local page = fetch(query, offset); 
        offset=offset+limit; 
        return page 
    end 
end
```

**File Reader**
```lua
local function line_iter(file) 
    return function() 
        return file:read() 
    end 
end
```

**Infinite Stream**
```lua
local function gen(start) 
    local i=start; 
    return function() 
        i=i+1; 
        return i 
    end 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Stack/Queue (tree/graph traversal), Pointer/Index (position tracking)  
**Algorithms**: Sequential access Θ(1) per step, O(n) full traversal  
**Ref**: Array/List Θ(1) index access, Stack Θ(1) ops

#### 🛠️ Structures Needed
- `has_next()`: Boundary check
- `next()`: Element retrieval + state advance
- `reset()`: Restart iteration
- `remove()`: Optional deletion during traversal

#### ⏱️ Expected Implementation Time
- 1–2 hours (basic)
- 3–4 hours (complex structures + concurrency)

#### 🚀 Speed & Memory Performance
**Speed**: Θ(1) per step. O(n) total traversal  
**Memory**: O(1) iterator state. O(k) for stack-based traversals

#### ✅ Pros & ❌ Cons
**Pros**: Encapsulates traversal logic, supports multiple iterators, collection-agnostic client code  
**Cons**: Slight overhead vs direct `for i,v in ipairs`, state management complexity, concurrent modification risks

#### 🔗 Relations
Pairs with Composite (tree traversal), Visitor (external ops during iteration), alternative to direct indexing

---

### 5. Mediator

Centralizes communication between game objects, reducing direct dependencies.

#### 🛠️ Idiomatic Lua Implementation
Central callback table/module with `on()`/`emit()`/`trigger()`. No mediator class hierarchy; simple function dispatch.

#### ⚡ Performance Impact
O(k) broadcast. Θ(1) routing. Weak tables (`__mode="v"`) prevent listener leaks. Hot paths should inline handlers.

#### 🔍 Evidence & Repo Context
`volley` uses implicit event bus for networking. `echeckers` routes phase transitions via central state table.

#### 📋 5 Usage Examples
**Chat Room**
```lua
local Chat = { users = {} }
function Chat:send(user, msg) 
    for _,u in ipairs(self.users) do 
        if u~=user then 
            u:receive(msg) 
        end 
    end 
end
```

**Air Traffic Control**
```lua
local Tower = { planes = {} }
function Tower:request_landing(plane) 
    table.insert(self.queue, plane); 
    self:notify_runway() 
end
```

**UI Form Validation**
```lua
local Form = { fields = {} }
function Form:on_change(field) 
    if self:all_valid() then 
        self.enable_submit() 
    end 
end
```

**Event Bus/Router**
```lua
local Bus = { listeners = {} }
function Bus:publish(evt, data) 
    for _,cb in ipairs(self.listeners[evt] or {}) do 
        cb(data) 
    end 
end
```

**Workflow Engine**
```lua
local Workflow = { tasks = {} }
function Workflow:on_complete(task) 
    self:update_state(); 
    self:trigger_next() 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Hash Table (event mapping), List/Queue (participants)  
**Algorithms**: Broadcast O(k) for k listeners, routing Θ(1)  
**Ref**: Dictionary Θ(1) lookup, Array/List O(k) iteration

#### 🛠️ Structures Needed
- `register(component)`: Participant tracking
- `route(message)`: Central dispatch
- `notify(sender, event, data)`: Event propagation

#### ⏱️ Expected Implementation Time
- 1–3 hours (basic)
- 4–6 hours (with filtering + async)

#### 🚀 Speed & Memory Performance
**Speed**: O(k) broadcast. Θ(1) routing  
**Memory**: O(k) participants + O(m) event mappings

#### ✅ Pros & ❌ Cons
**Pros**: Reduces coupling, simplifies communication logic, centralized control  
**Cons**: Can become god table, bottleneck risk, harder to trace dependencies

#### 🔗 Relations
Similar to Facade (but peer-to-peer vs client-subsystem), pairs with Observer (event routing), alternative to direct object references

---

### 6. Memento

Captures Lua table state for save/load, checkpoints, or undo.

#### 🛠️ Idiomatic Lua Implementation
`table.clone()` or diff-based snapshots + ring buffer. Store only changed fields to cut memory by ~90%.

#### ⚡ Performance Impact
O(n) full clone, Θ(1) restore. Diff snapshots reduce to O(d) where d=changes. Ring buffers cap history growth.

#### 🔍 Evidence & Repo Context
Missing in both repos. Recommended for `echeckers` undo system. `volley` could use for rollback netcode state.

#### 📋 5 Usage Examples
**Undo/Redo System**
```lua
local function create_memento(obj) 
    return table.clone(obj) 
end
local function restore(obj, m) 
    for k,v in pairs(m) do 
        obj[k]=v 
    end 
end
```

**Game Save/Load**
```lua
local function save_game(player) 
    return { 
        pos=player.pos, 
        inv=table.clone(player.inv) 
    } 
end
```

**Transaction Rollback**
```lua
local function begin_tx(db) 
    return table.clone(db.state) 
end
local function rollback(db, snapshot) 
    db.state = snapshot 
end
```

**Config Versioning**
```lua
local function snapshot(cfg) 
    return table.clone(cfg) 
end
local function revert(cfg, snap) 
    for k,v in pairs(snap) do 
        cfg[k]=v 
    end 
end
```

**State Machine History**
```lua
local function save_state(fsm) 
    return { 
        current=fsm.current, 
        stack=table.clone(fsm.stack) 
    } 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Stack/Deque (history), Hash Table (state mapping), Array (snapshots)  
**Algorithms**: Deep copy O(n), stack push/pop Θ(1), state restoration Θ(1)  
**Ref**: Stack Θ(1) ops, Array/List Θ(n) copy

#### 🛠️ Structures Needed
- `create_memento()`: State capture
- `restore(memento)`: State restoration
- `get_history()`: Access snapshots

#### ⏱️ Expected Implementation Time
- 1–3 hours (basic)
- 4–6 hours (with versioning + memory management)

#### 🚀 Speed & Memory Performance
**Speed**: O(n) snapshot creation, Θ(1) restore  
**Memory**: O(n) per snapshot. Can grow rapidly without limits/eviction

#### ✅ Pros & ❌ Cons
**Pros**: Encapsulation preserved, easy undo/rollback, state isolation  
**Cons**: High memory usage, serialization overhead, complex state diffs

#### 🔗 Relations
Pairs with Command (undo history), Prototype (state cloning), alternative to direct state mutation

---

### 7. Observer

One-to-many dependency so Lua tables are notified of state changes.

#### 🛠️ Idiomatic Lua Implementation
Table of callbacks + weak values (`__mode="v"`). Iterate on `emit()`. No Subject/Observer interfaces required.

#### ⚡ Performance Impact
O(k) broadcast. Θ(1) registration. Weak tables auto-GC disconnected listeners. Inline handlers for 60fps events.

#### 🔍 Evidence & Repo Context
`volley` event handlers registered in tables, looped on trigger. `echeckers` UI updates trigger via callback dispatch.

#### 📋 5 Usage Examples
**Event System**
```lua
local Subject = { observers = {} }
function Subject:attach(o) table.insert(self.observers, o) end
function Subject:notify() 
    for _,o in ipairs(self.observers) do 
        o:update(self) 
    end 
end
```

**Pub/Sub Messaging**
```lua
local Pub = { subs = {} }
function Pub:publish(data) 
    for _,s in ipairs(self.subs) do 
        s:receive(data) 
    end 
end
```

**Reactive Streams**
```lua
local Observable = { observers = {} }
function Observable:next(val) 
    for _,o in ipairs(self.observers) do 
        o:on_data(val) 
    end 
end
```

**Price Ticker**
```lua
local Market = { subscribers = {} }
function Market:update(sym, price) 
    for _,s in ipairs(self.subscribers) do 
        s:on_update(sym, price) 
    end 
end
```

**File Watcher**
```lua
local Watcher = { listeners = {} }
function Watcher:on_event(evt) 
    for _,l in ipairs(self.listeners) do 
        l:handle(evt) 
    end 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: List/Set (observers), Queue (async notifications)  
**Algorithms**: Broadcast O(k) for k observers, registration Θ(1)  
**Ref**: Array/List O(k) iteration, Set Θ(1) membership

#### 🛠️ Structures Needed
- `attach(observer)`: Subscription
- `detach(observer)`: Unsubscription
- `notify(data)`: Event dispatch
- `update(data)`: Observer callback

#### ⏱️ Expected Implementation Time
- 1–2 hours (basic)
- 3–5 hours (async + filtering + backpressure)

#### 🚀 Speed & Memory Performance
**Speed**: O(k) broadcast. Θ(1) registration  
**Memory**: O(k) observer references. Queue adds O(m) buffered events

#### ✅ Pros & ❌ Cons
**Pros**: Loose coupling, dynamic subscription, scalable notifications  
**Cons**: Hard to debug event flow, memory leaks if unsubscribed, notification order undefined

#### 🔗 Relations
Pairs with Mediator (central routing), Command (event payload), alternative to polling

---

### 8. State

Allows Lua game objects to alter behavior when internal state changes.

#### 🛠️ Idiomatic Lua Implementation
Table-of-functions FSM + current state key. `states[current](context)` replaces inheritance-based state classes.

#### ⚡ Performance Impact
Θ(1) transition + Θ(1) delegation. Zero virtual table overhead. Hot-swap states instantly.

#### 🔍 Evidence & Repo Context
`echeckers` `phases[current]()` implements phase machine. `volley` uses state keys for player match flow (waiting → playing → ended).

#### 📋 5 Usage Examples
**Document Editor**
```lua
local states = { 
    draft = { save = save_local }, 
    review = { save = submit_review } 
}
function handle(ctx) 
    states[ctx.mode].save(ctx) 
end
```

**TCP Connection**
```lua
local TcpState = { 
    established = { 
        send = function(data) 
            socket:write(data) 
        end 
    } 
}
```

**Game Character**
```lua
local CharState = { 
    idle = { update = idle_anim }, 
    attack = { update = attack_frame } 
}
function update(char) 
    CharState[char.state].update(char) 
end
```

**Order Processing**
```lua
local OrderState = { 
    pending = { next = ship }, 
    shipped = { next = deliver } 
}
```

**UI Button**
```lua
local BtnState = { 
    hover = { render = draw_highlight }, 
    pressed = { render = draw_active } 
}
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Dictionary (state registry), Stack (history/undo), Enum/Constants (state identifiers)  
**Algorithms**: State transition Θ(1), behavior delegation Θ(1)  
**Ref**: Dictionary Θ(1) lookup, Array/List O(1) index access

#### 🛠️ Structures Needed
- `enter(context)`: Initialization on transition
- `exit(context)`: Cleanup on transition
- `handle(input)`: State-specific logic
- `transition_to(new_state)`: State switch

#### ⏱️ Expected Implementation Time
- 2–4 hours (basic)
- 1 day (with validation + history + async)

#### 🚀 Speed & Memory Performance
**Speed**: Θ(1) transition + Θ(1) delegation  
**Memory**: O(1) per state instance + O(k) state registry. Very low overhead

#### ✅ Pros & ❌ Cons
**Pros**: Eliminates large conditionals, explicit transitions, easy to add states  
**Cons**: Many small tables, overkill for simple flags, can fragment logic

#### 🔗 Relations
Pairs with Command (undo transitions), Strategy (algorithm swapping vs state-driven behavior), alternative to `if/else` state flags

---

### 9. Strategy

Defines a family of algorithms and lets Lua clients switch them at runtime.

#### 🛠️ Idiomatic Lua Implementation
Function dispatch tables or direct closure passing. No strategy interface; just map keys to functions.

#### ⚡ Performance Impact
Θ(1) switch. Execution speed = underlying algorithm. Pre-bind strategies at init to avoid runtime `if/elseif`.

#### 🔍 Evidence & Repo Context
`echeckers` `actions[input]()` dispatches player moves. AI selection uses `ai_strategies[difficulty]()` table lookup.

#### 📋 5 Usage Examples
**Sorting**
```lua
local sorters = { 
    quick = quicksort, 
    merge = mergesort 
}
function sort(data, type) 
    sorters[type](data) 
end
```

**Compression**
```lua
local compressors = { 
    zip = pack_zip, 
    gzip = pack_gzip 
}
function pack(data, fmt) 
    compressors[fmt](data) 
end
```

**Routing Algorithm**
```lua
local routers = { 
    dijkstra = dijkstra_path, 
    astar = astar_path 
}
function find_path(start, end, type) 
    routers[type](start, end) 
end
```

**Payment Processing**
```lua
local pay_methods = { 
    credit = process_cc, 
    paypal = process_pp 
}
function checkout(method, amount) 
    pay_methods[method](amount) 
end
```

**Image Filter**
```lua
local filters = { 
    sepia = apply_sepia, 
    blur = apply_blur 
}
function filter_image(img, type) 
    filters[type](img) 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Dictionary (strategy registry), List (algorithm parameters)  
**Algorithms**: Strategy selection Θ(1), execution depends on algorithm  
**Ref**: Hash Table Θ(1) lookup, Array/List Θ(n) data access

#### 🛠️ Structures Needed
- `set_strategy(strategy)`: Runtime swap
- `execute()`: Algorithm delegation
- `get_available_strategies()`: Discovery

#### ⏱️ Expected Implementation Time
- 1–3 hours (basic)
- 4–6 hours (with validation + metrics)

#### 🚀 Speed & Memory Performance
**Speed**: Θ(1) switch. Execution speed = underlying algorithm  
**Memory**: O(1) strategy reference + O(k) registry. Low overhead

#### ✅ Pros & ❌ Cons
**Pros**: Open/Closed, runtime flexibility, isolates algorithms  
**Cons**: Clients must know strategy differences, can overcomplicate simple logic

#### 🔗 Relations
Pairs with State (behavior vs algorithm), Factory (creation), alternative to conditional branching

---

### 10. Template Method

Defines algorithm skeleton in base table, letting Lua modules override specific steps.

#### 🛠️ Idiomatic Lua Implementation
Higher-order functions taking hook functions, or default table overrides via metatable `__index`. No abstract classes needed.

#### ⚡ Performance Impact
O(m) sequential steps. Θ(1) hook invocation. Explicit callback passing adds slight overhead vs inheritance.

#### 🔍 Evidence & Repo Context
Game loop skeletons in both repos use `setup → loop → cleanup` hooks. `volley` networking pipeline uses configurable middleware steps.

#### 📋 5 Usage Examples
**Data Pipeline**
```lua
local Pipeline = {}
function Pipeline:run() 
    self:load(); 
    self:validate(); 
    self:transform(); 
    self:save() 
end
```

**Game Level**
```lua
local Level = {}
function Level:play() 
    self:setup(); 
    self:loop(); 
    self:cleanup() 
end
```

**Report Generation**
```lua
local Report = {}
function Report:generate() 
    self:fetch(); 
    self:format(); 
    self:export() 
end
```

**API Client**
```lua
local Client = {}
function Client:request() 
    self:auth(); 
    self:send(); 
    self:parse(); 
    self:handle_errors() 
end
```

**Build Process**
```lua
local Build = {}
function Build:run() 
    self:compile(); 
    self:test(); 
    self:package(); 
    self:deploy() 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Inheritance hierarchy (metatable `__index`), Configuration map (hooks/flags)  
**Algorithms**: Sequential execution O(m) for m steps, hook invocation Θ(1)  
**Ref**: Array/List O(m) step execution, Dictionary Θ(1) config lookup

#### 🛠️ Structures Needed
- `abstract_step()`: Overridable methods
- `final_step()`: Common implementation
- `hook()`: Optional extension points
- `run()`: Template skeleton

#### ⏱️ Expected Implementation Time
- 1–3 hours (basic)
- 4–8 hours (with hooks + validation + error handling)

#### 🚀 Speed & Memory Performance
**Speed**: O(m) sequential steps. Θ(1) virtual dispatch  
**Memory**: O(1) per subclass instance. Inheritance adds minimal overhead

#### ✅ Pros & ❌ Cons
**Pros**: Code reuse, consistent flow, easy to extend steps  
**Cons**: Tight coupling via `__index`, rigid structure, hard to change skeleton later

#### 🔗 Relations
Pairs with Factory Method (creation steps), Strategy (algorithm swapping vs skeleton enforcement), alternative to composition for step customization

---

### 11. Visitor

Adds new operations to Lua object structures without modifying the objects.

#### 🛠️ Idiomatic Lua Implementation
Type-string dispatch table keyed by `card.type` or `node.kind`. Simulates double dispatch via explicit `if` or table routing.

#### ⚡ Performance Impact
O(n) traversal + Θ(1) per visit. Extra branching overhead vs Lisp multiple dispatch. Pre-compute dispatch tables to minimize cost.

#### 🔍 Evidence & Repo Context
`echeckers` could use `card_abilities[card.name](board)` for card logic. Not yet formalized; current code uses direct type checks.

#### 📋 5 Usage Examples
**AST Evaluation**
```lua
local Visitor = {}
function Visitor:visit(node) 
    if node.type == "add" then 
        self:visit_add(node) 
    end 
end
```

**File System Scanner**
```lua
local Scanner = {}
function Scanner:visit(node) 
    if node.is_dir then 
        for _,c in ipairs(node.children) do 
            self:visit(c) 
        end 
    else 
        self:count_file(node) 
    end 
end
```

**UI Theme Application**
```lua
local DarkTheme = {}
function DarkTheme:visit(widget) 
    if widget.type == "button" then 
        widget.color = "blue" 
    end 
end
```

**Report Exporter**
```lua
local PdfExporter = {}
function PdfExporter:visit(node) 
    if node.type == "table" then 
        self:render_table(node) 
    end 
end
```

**Graph Analysis**
```lua
local Centrality = {}
function Centrality:visit(node) 
    for _,n in ipairs(node.neighbors) do 
        self:accumulate(n) 
    end 
end
```

#### 🗃️ Data Structures & Algorithms Used
**DS**: Tree/Graph (object structure), Dictionary (visitor registry), Stack (traversal)  
**Algorithms**: Double dispatch Θ(1) per node, full traversal O(n)  
**Ref**: Tree Θ(n) traversal, Dictionary Θ(1) method routing

#### 🛠️ Structures Needed
- `accept(visitor)`: Double dispatch entry
- `visit_concrete_element(element)`: Visitor operation
- `get_result()`: Aggregate output

#### ⏱️ Expected Implementation Time
- 2–4 hours (basic)
- 4–8 hours (with multiple visitors + async)

#### 🚀 Speed & Memory Performance
**Speed**: O(n) traversal + Θ(1) per visit. Double dispatch adds minimal overhead  
**Memory**: O(1) per visitor + O(n) structure traversal stack

#### ✅ Pros & ❌ Cons
**Pros**: Open/Closed, separates algorithms from data, easy to add operations  
**Cons**: Breaks encapsulation (requires exposing internals), hard to add new element types, complex double dispatch

#### 🔗 Relations
Pairs with Composite (tree traversal), Iterator (sequential access), alternative to adding methods to every table

---
