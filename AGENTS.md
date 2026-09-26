# AGENTS.md — General Rules for All Godot 4.7.x Projects (Mr.Saei)

These are standing rules for the AI agent across every game and app built in Godot 4.7.x by Mr.Saei.

They are intentionally project-agnostic. Project-specific requirements may override these rules when explicitly documented by the project.

The agent must prefer **simple, maintainable, testable, data-driven, scene-based Godot architecture** over unnecessary abstraction or cleverness.

**Godot version target: 4.7.x.**
Do not introduce APIs, properties, classes, project settings, or patterns that require Godot 4.8+ unless explicitly requested.

---

# 1. Core Agent Principles

## 1.1 Inspect Before Changing

* Before creating a new system, inspect the existing project architecture, relevant scenes, scripts, Resources, Autoloads, UI, and project settings.
* Reuse existing systems before creating replacements.
* Never create duplicate managers, databases, utility systems, singleton equivalents, or UI frameworks without first determining that the existing system cannot reasonably be reused.
* Before modifying a shared system, identify its known consumers and dependencies.
* Preserve existing behavior unless the requested change explicitly requires changing it.
* Prefer targeted modifications over rewriting entire files.
* Do not delete, replace, or reorganize unrelated user work.
* Never assume a file's purpose from its filename alone. Inspect its contents and usage first.
* Do not invent APIs, methods, signals, properties, node paths, project settings, or plugin interfaces.
* When uncertain about an engine API or behavior, verify it against the project and Godot 4.7.x documentation before implementing it.

## 1.2 Simplicity First

* Prefer the simplest architecture that correctly solves the problem.
* Do not introduce abstractions merely because they are theoretically reusable.
* Do not create interfaces, managers, state machines, event buses, dependency injection, factories, service locators, or other architectural patterns unless they solve an actual problem in the current project.
* Avoid premature optimization.
* Avoid premature generalization.
* Start with a small working implementation and generalize only after the design has proven useful.
* Prefer explicit, readable code over highly abstract or clever code.

## 1.3 Single Responsibility

* Every major system should have one clear responsibility.
* Each important piece of state should have one clear owner.
* Avoid "Manager" scripts that accumulate unrelated responsibilities.
* Avoid giant scripts containing unrelated gameplay, UI, networking, persistence, audio, and configuration logic.
* If a script keeps growing into unrelated responsibilities, split it by actual domain responsibility rather than arbitrary file size.

## 1.4 Dependency Direction

Prefer dependencies that flow in a deliberate direction:

```text
Data
  ↓
Core / Domain Logic
  ↓
Feature / Gameplay Systems
  ↓
Scene Controllers
  ↓
UI / Presentation
```

Avoid:

```text
Everything → Everything
```

* Avoid circular dependencies between systems.
* Lower-level reusable systems should not depend directly on unrelated high-level UI.
* Core gameplay/business logic should not directly manipulate unrelated UI controls.
* UI should request actions or react to state rather than becoming the source of truth for application/game logic.
* Use signals, explicit methods, Resources, or well-defined interfaces at system boundaries.

---

# 2. GDScript Code Conventions

## 2.1 Static Typing

* Prefer static typing throughout project code.
* Every function parameter must have an explicit type.
* Every function must have an explicit return type, including `-> void`.
* Every member/local variable should have an explicit type or use `:=` when the type is unambiguous.
* Prefer typed collections such as `Array[String]`, `Array[Enemy]`, and typed dictionaries where practical.
* Dynamic `Variant` values are allowed at deliberate dynamic boundaries such as JSON parsing, heterogeneous data, or APIs that require them.
* Do not use dynamic typing merely for convenience when the type is already known.
* Avoid `Variant` propagation through large parts of the architecture.

Examples:

```gdscript
var health: int = 100
var speed: float = 250.0
var player_name: String = "Player"
var enemies: Array[Enemy] = []
var score := calculate_score()
```

## 2.2 Indentation and Formatting

* GDScript indentation MUST use TAB characters.
* Never use spaces for indentation in GDScript.
* Never convert an existing tab-indented GDScript file to spaces.
* Maintain consistent indentation throughout the project.
* Use UTF-8 text encoding.
* Prefer double quotes for strings.
* Keep lines at or below approximately 100 characters where reasonably practical.
* Use trailing commas in multiline arrays, dictionaries, function calls, and similar constructs where appropriate.

## 2.3 Script Layout

Use this general order:

```text
@tool / @icon / @static_unload
class_name
extends
documentation comment

signals
enums
constants
static variables

@export variables
regular variables
@onready variables

_init()
_enter_tree()
_ready()

engine callbacks
_process()
_physics_process()
_input()
_unhandled_input()
...

public methods

private methods beginning with _
    
inner classes
```

Do not treat this order as permission to create unnecessary sections. Omit sections that are not used.

## 2.4 Naming

* Classes and node types: `PascalCase`
* Functions: `snake_case`
* Variables: `snake_case`
* Files and folders: `snake_case`
* Constants: `ALL_CAPS`
* Private members/functions: `_leading_underscore`
* Signals: descriptive `snake_case` phrases
* Boolean variables should generally read naturally, for example:

  * `is_alive`
  * `has_target`
  * `can_attack`
  * `is_loading`

Do not abbreviate names unless the abbreviation is universally clear in the project.

---

# 3. Node and Scene Architecture

## 3.1 Scene-First Design

* Prefer representing persistent scene structure in `.tscn` files rather than generating the same static structure entirely through code.
* Prefer creating and configuring Nodes, Control layouts, Themes, Resources, animations, and signal connections in scene/resource files when they are static or designer-controlled.
* Use runtime code to create nodes when the content is genuinely dynamic, data-driven, procedurally generated, or dependent on runtime state.
* Do not construct a large static UI entirely through script when it could reasonably be represented as a reusable scene.
* Keep scene composition visible and understandable in the Godot Scene dock.
* A developer should be able to understand a scene's major structure without reading its entire script.
* Prefer reusable sub-scenes over procedural duplication.

## 3.2 Scenes vs. Scripts

* Give something its own scene when it needs a meaningful node subtree, visual representation, lifecycle, or reusable composition.
* Use a plain script for pure logic that does not require a node tree.
* Use `class_name` for reusable domain types when appropriate.
* Do not create scenes merely because a script exists.
* Do not create scripts merely because a scene exists.

## 3.3 Composition Over Inheritance

* Prefer composition over deep inheritance hierarchies.
* Prefer reusable sub-scenes and components over large inheritance chains.
* Keep inheritance shallow.
* Avoid deep hierarchies that make behavior difficult to trace.
* A reusable component should solve a clearly defined responsibility.

## 3.4 Node Hierarchies

* Keep scene trees as shallow as practical.
* Avoid unnecessary wrapper nodes.
* Do not create ten layers of Containers, Panels, or generic Node wrappers when fewer nodes can express the same structure.
* Use meaningful node names.
* Avoid nodes that exist only because an AI agent habitually creates them.

---

# 4. Node References and Scene Communication

## 4.1 Node References

* Do not repeatedly search for nodes during per-frame callbacks.
* Never use `get_node()`, `find_child()`, or equivalent tree searches inside `_process()` or `_physics_process()` merely to retrieve a stable reference.
* Cache stable references during initialization.
* Prefer Scene Unique Names for stable scene-local references:

```gdscript
@onready var score_label: Label = %ScoreLabel
```

* Use explicit references or dependency injection when a dependency is external to the scene.
* Avoid fragile long node paths when a reusable reference or unique name is more appropriate.

## 4.2 Parent/Child Communication

Follow:

**"Signal up, call down."**

* A child may emit signals describing events or state changes.
* A parent/controller may call methods or set properties on child components.
* Children should not reach upward into parent internals merely to control the parent.
* Avoid children calling `$../../../../GameManager`-style paths.
* Avoid hardcoded knowledge of unrelated scene hierarchies.
* Use signals when a component needs to announce something without knowing who will consume it.
* Use direct method calls when the relationship is explicit and stable.

## 4.3 Signals vs. Polling

* Prefer signals and event-driven communication for discrete events and state changes.
* Use polling when the value genuinely needs continuous sampling, such as:

  * movement
  * aiming
  * physics
  * animation state
  * continuous input
  * timers or elapsed-time logic
* Do not replace legitimate per-frame logic with signals merely because "signals are better."
* Connect signals explicitly and keep signal ownership understandable.
* Prefer Godot 4's first-class `Signal` and `Callable` patterns over fragile string-based callback references.

---

# 5. Autoload and Global State Rules

* Use Autoloads only for genuinely global, shared state or services.
* Typical candidates include:

  * global application/game state
  * a small event/signal bus when truly necessary
  * persistent settings/configuration
  * carefully scoped global services
* Do not create one Autoload per feature.
* Do not use Autoloads merely to avoid passing a reference.
* If something belongs to one scene, feature, or gameplay object, keep it local.
* Keep global state minimal.
* Document any significant new Autoload before changing it.
* Do not allow global state to become the default communication mechanism between every system.

---

# 6. Resources and Data Architecture

## 6.1 Use Resources for Data

Prefer custom `Resource` classes for reusable, serializable, Inspector-editable, data-only objects such as:

* items
* characters
* weapons
* dialogue entries
* levels
* configuration
* abilities
* quests
* educational content
* statistics
* game settings

Example:

```gdscript
class_name ItemData
extends Resource

@export var item_name: String
@export var price: int
@export var description: String
```

## 6.2 Resource Sharing

* Treat loaded `.tres` / `.res` resources as potentially shared.
* Do not mutate a shared Resource at runtime unless shared mutation is intentional.
* Keep static configuration data separate from mutable runtime state when practical.
* When state must be instance-specific, use an appropriate local resource, duplicate strategy, or a separate runtime object.
* Do not accidentally turn static `.tres` data into mutable global state.

## 6.3 Data vs. Behavior

Separate:

```text
Configuration / Content Data
        ↓
Domain Logic
        ↓
Runtime State
        ↓
Presentation
```

Do not place large amounts of gameplay behavior inside Resources simply because Resources are convenient for storing data.

---

# 7. Magic Values and Configuration

* Do not scatter magic strings or magic numbers throughout the code.
* Use constants for repeated values.
* Use enums for finite sets of states/types.
* Use Resources for designer-editable configuration.
* Use project settings only when a value genuinely belongs at project/configuration level.
* Avoid hardcoded node paths, filenames, URLs, identifiers, and repeated JSON keys.
* Centralize important schema identifiers and keys.

---

# 8. Initialization and Lifecycle

* Do not put substantial gameplay logic directly into `_ready()` merely because it is convenient.
* Use `_ready()` primarily for initialization, reference wiring, signal connections, and startup preparation.
* Put meaningful gameplay/application transitions into named methods such as:

  * `start_game()`
  * `initialize_level()`
  * `begin_round()`
  * `reset_state()`
* Understand the difference between:

  * `_init()`
  * `_enter_tree()`
  * `_ready()`
  * `_exit_tree()`
* Disconnect or clean up resources/connections when the lifecycle requires it.
* Never assume a node will remain valid after an asynchronous operation.

---

# 9. Input Architecture

* Prefer InputMap actions over hardcoded physical keys/buttons.
* Use semantic actions such as:

```text
move_left
move_right
jump
confirm
cancel
attack
interact
```

rather than embedding device-specific inputs throughout gameplay code.

* Keep input interpretation separate from core gameplay logic when practical.
* Support keyboard, controller, touch, and other input methods through the same gameplay actions where the target platform requires it.
* Do not hardcode mouse/keyboard assumptions into systems intended for mobile/controller use.
* Interactive UI must have appropriate keyboard/controller focus behavior when relevant.
* Touch controls should not require rewriting the core gameplay system.

---

# 10. UI/UX Architecture

## 10.1 Layout

* Use anchors and Containers rather than manually positioning UI.
* Use `VBoxContainer`, `HBoxContainer`, `GridContainer`, `MarginContainer`, etc. where appropriate.
* Never rely on setting a child's `position` or `size` inside a `Container`.
* Control size through:

  * `custom_minimum_size`
  * size flags
  * anchors
  * container properties
* Explicitly configure size flags for elements that must expand.
* Use anchors for responsive screen relationships.

## 10.2 Responsive Design

* Design for multiple resolutions and aspect ratios from the beginning.
* Establish the project's base resolution and stretch configuration early.
* Do not build every screen around a single hardcoded window size.
* Test UI at multiple aspect ratios.
* Consider portrait and landscape requirements explicitly when relevant.
* Do not make resolution-specific hacks unless the project truly needs them.

## 10.3 CanvasLayer

* Use `CanvasLayer` for screen-space overlays/HUDs that should remain independent of world/camera transforms.
* For full-screen UI applications and menu-heavy apps, prefer a `Control`-based root unless a CanvasLayer is actually needed.
* Deliberately distinguish:

  * world-space UI
  * camera-space UI
  * screen-space UI

## 10.4 Theme

* Establish a shared base Theme for the project.
* Reuse Theme resources instead of creating accidental per-node styling.
* Centralize fonts, typography, colors, StyleBoxes, and common control styles.
* Use deliberate local overrides only when they represent a real design distinction.
* Avoid duplicating visually identical styles across many nodes.
* Do not hardcode visual constants into dozens of unrelated scripts.

## 10.5 UI Consistency

* Reuse established button, dialog, list, card, popup, and navigation patterns.
* Consistency should be intentional.
* Do not introduce a unique interaction pattern for every screen.
* Every interaction should provide appropriate feedback.
* Important information must not rely on color alone.
* Maintain readable contrast.
* Interactive controls should have appropriate target sizes for the platform.
* Do not make animation mandatory for understanding critical information.
* When appropriate, provide reduced-motion or disable-animation behavior.

---

# 11. Game and Product Design Principles

These principles apply to both games and interactive applications.

## 11.1 Core Experience First

* Prototype the core loop before polishing secondary systems.
* For a game:

```text
Action → Feedback → Reward → Progression → Action
```

* For an app:

```text
Open → Primary Task → Result → Next Useful Action
```

* A working gray-box vertical slice is more valuable than a polished shell without a functioning core experience.

## 11.2 First 30 Seconds

* The main experience should become understandable quickly.
* Avoid unnecessary tutorials, explanations, and onboarding steps.
* If a feature requires a long explanation before becoming understandable, reconsider the design.

## 11.3 Feedback

Every important interaction should provide appropriate feedback.

Depending on the context, this may include:

* visual state change
* animation
* sound
* haptic feedback
* particles
* confirmation
* loading state
* progress indication
* error state

Do not add "juice" everywhere merely for decoration. Feedback should improve clarity and responsiveness.

## 11.4 Meaningful Choices

* Important features and choices should have a clear purpose.
* Avoid adding complexity, options, mechanics, or settings that do not meaningfully improve the experience.
* In game systems, meaningful choices should generally produce meaningful differences in outcome, strategy, or resource usage.
* Do not add artificial complexity simply to make a system feel deep.

## 11.5 Respect User Time

* Remove filler steps.
* Avoid unnecessary clicks, confirmations, menus, grinding, and repeated work.
* Do not make users/player perform work merely because the implementation is technically convenient.

---

# 12. Feature Development Workflow

Every significant feature should follow this general progression:

```text
Understand
   ↓
Inspect Existing Architecture
   ↓
Define Smallest Vertical Slice
   ↓
Implement
   ↓
Verify
   ↓
Refine
   ↓
Generalize Only When Needed
```

## 12.1 Vertical Slice First

* Build the smallest complete version of the feature.
* Include the real interaction flow, state changes, and feedback.
* Do not build a large generalized framework before the first working slice exists.
* Once the vertical slice works, identify what should actually be generalized.

## 12.2 Shared State Changes

Before modifying:

* Autoloads
* save-data schemas
* network protocols
* major Resources
* core game/application state

the agent should first understand the impact on existing systems.

For significant shared architecture changes, describe the intended ownership and data flow in plain language before implementation.

---

# 13. Performance Rules

## 13.1 Measure First

* Profile before making significant optimization changes.
* Use Godot's profiler and performance monitors to identify the real bottleneck.
* Do not optimize based only on assumptions.
* Distinguish:

  * CPU bottlenecks
  * GPU bottlenecks
  * memory pressure
  * rendering/draw-call problems
  * script overhead
  * loading/IO problems

## 13.2 Frame Budget

* Establish a target frame rate appropriate to the target platform.
* 60 FPS is a useful default target where practical.
* Lower targets may be appropriate for some mobile or specialized applications.
* Treat the actual frame-time budget as the engineering constraint.

Approximate budgets:

```text
60 FPS → 16.6 ms/frame
30 FPS → 33.3 ms/frame
```

## 13.3 Per-Frame Work

Avoid expensive unnecessary work in:

```text
_process()
_physics_process()
_input()
_unhandled_input()
```

Examples:

* repeated scene-tree searches
* repeated group-wide searches
* unnecessary allocations
* repeated parsing
* repeated filesystem operations
* excessive logging
* expensive calculations that can be cached
* naive `O(n²)` operations when a better approach is practical

## 13.4 Object Pooling

* Consider pooling for high-frequency, short-lived objects when profiling or expected runtime churn justifies it.
* Do not introduce object pooling automatically.
* Prefer simple `instantiate()` / `queue_free()` implementations until profiling or scale demonstrates a need.

## 13.5 Visibility and Culling

* Reduce processing/rendering of objects that are irrelevant to the current view or gameplay range when this provides a meaningful benefit.
* Use an appropriate technique for the problem, such as:

  * visibility notifiers
  * distance checks
  * disabled processing
  * LOD
  * batching
  * spatial partitioning
* Do not add culling infrastructure to small/simple scenes without a real reason.

## 13.6 Rendering

* Reduce unnecessary draw calls where relevant.
* Prefer efficient Godot systems such as:

  * TileMap/TileMapLayer
  * MultiMesh
  * batching-friendly materials/textures
* Avoid excessive unique materials and unnecessary texture duplication.
* Profile before redesigning rendering architecture.

## 13.7 Threads

* Use `WorkerThreadPool` or other threading tools for expensive work that should not block the main thread.
* Do not move work to threads merely because "threads are faster."
* Keep thread work focused on data and computation.
* Do not access SceneTree/Node state from worker threads unless the specific API is documented as thread-safe.
* Return/synchronize results to the main thread before modifying normal scene state.

## 13.8 Memory

Monitor for:

* increasing Object Count
* increasing Video RAM
* growing memory across scene transitions
* resources/nodes that should have been freed but remain alive

When memory usage increases unexpectedly, investigate:

* references
* signal connections
* retained Resources
* Autoload state
* orphaned nodes
* caches
* static variables

---

# 14. Asynchronous Code

* Use `await` when asynchronous behavior makes the design clearer.
* Do not introduce asynchronous code unnecessarily.
* After an `await`, assume relevant state may have changed.
* Verify that nodes and objects are still valid before using them after a long asynchronous operation.
* Verify that the operation is still relevant to the current scene/state.
* Avoid orphaned asynchronous operations after a scene exits.
* Design cancellation/lifecycle handling for long-running operations.
* Never assume execution resumes immediately after `await`.

---

# 15. Save Data and Persistence

* Treat save files as external/untrusted input.
* Validate loaded save data before applying it.
* Every persistent save format must have a version number.
* Never assume old save data has the newest schema.
* Implement migrations when persistent data structures change.
* Keep serialization/deserialization separate from presentation logic.
* Failed saves must not silently replace a previously valid save with corrupted data.
* Use atomic or otherwise safe save strategies where appropriate.
* Do not store transient runtime state unless it actually needs persistence.
* Do not store sensitive credentials in ordinary save files.

Example:

```text
SaveData
├── version
├── player_progress
├── settings
└── unlocks
```

---

# 16. Networking and Backend Rules

For online features:

* Assume all client data can be modified by a malicious client.
* Never trust the client for:

  * purchases
  * leaderboard scores
  * rewards
  * account ownership
  * premium entitlements
  * competitive results
  * authoritative progression
* The server should validate important game/application rules.
* Keep secrets and privileged credentials on the server.
* Use HTTPS/TLS for network communication.
* Handle:

  * timeouts
  * retries
  * invalid responses
  * offline state
  * server errors
  * authentication expiration
* Never make online-only assumptions when the product is supposed to support offline operation.
* Clearly separate offline/local state from authoritative server state.

---

# 17. Security Rules

* Never hardcode API keys, tokens, passwords, private certificates, or server credentials into exported project code/resources.
* Assume everything shipped in the client can eventually be extracted.
* PCK/script encryption increases extraction difficulty but must not be treated as a secure secret-storage mechanism.
* Anything important that depends on a secret or trusted authority belongs behind a backend/proxy.
* The client must never contain secrets that need to remain secret from players/users.
* Local-only developer keys may be stored on-device for personal tooling, but:

  * keep them out of version control
  * use `.gitignore`
  * do not include them in public templates
  * do not package them into production exports
* Validate and sanitize external input from:

  * network responses
  * save files
  * user-editable files
  * JSON
  * configuration
  * URLs
* Use HTTPS/TLS for all network communication.
* Never commit secrets to Git.
* If a secret is committed, treat it as compromised and rotate/revoke it.

---

# 18. Error Handling and Debugging

* Never silently ignore important failures.
* Check return values from:

  * file operations
  * network operations
  * serialization
  * resource loading
  * authentication
  * backend APIs
* Use meaningful error messages that identify the system and context.
* Use `push_error()` for developer-visible runtime errors where appropriate.
* Use `assert()` for development-time programmer invariants.
* Never rely on `assert()` for production validation because assertions may not execute in release builds.
* Do not place essential side effects inside assertions.
* Avoid leaving temporary debugging prints in release code.
* Prefer structured/debug logging that can be filtered or disabled.

---

# 19. Project Organization

Prefer organization by feature/domain rather than one massive folder per file type.

Example:

```text
project/
├── scenes/
│   ├── main/
│   ├── player/
│   ├── ui/
│   └── features/
│
├── scripts/
│   ├── core/
│   ├── gameplay/
│   ├── systems/
│   └── ui/
│
├── resources/
│   ├── characters/
│   ├── items/
│   ├── levels/
│   └── config/
│
├── assets/
├── addons/
└── docs/
```

Guidelines:

* Keep closely related assets near the scene/system that owns them when practical.
* Do not create giant catch-all folders.
* Do not put every script in one `scripts/` folder if the project is large enough that domain organization would help.
* Do not put every texture/sound/model in a single flat directory for a large project.
* Use `snake_case` for files and folders.
* Keep third-party plugins/assets clearly separated from first-party project code.

---

# 20. Version Control

* Never overwrite unrelated user changes.
* Never silently delete files that may contain user work.
* Keep changes logically grouped.
* Avoid massive unrelated formatting changes.
* Do not commit secrets.
* Do not commit Godot cache data such as `.godot/` unless a specific workflow requires otherwise.
* Preserve required project/import metadata.
* Before large refactors, identify affected scenes/scripts/resources.
* Prefer small, understandable commits where version control is used.

---

# 21. Testing and Verification

A feature is **not complete merely because the code has been written**.

After every meaningful implementation:

1. Check for GDScript parser errors.
2. Check for static type errors.
3. Check the Godot debugger for runtime errors.
4. Run the affected scene/system.
5. Test the primary user interaction.
6. Verify signals are connected correctly.
7. Verify node references and Resources exist.
8. Verify expected state transitions.
9. Verify no obvious regression was introduced.
10. Test on the intended target platform when platform-specific behavior changed.

For significant changes:

* perform a focused regression test on related functionality
* test edge cases
* test invalid input where relevant
* test scene reload/exit behavior
* test save/load behavior when persistence is involved
* test offline/network failure behavior when networking is involved

Do not claim a feature works without actually verifying it.

---

# 22. Debugging Method

When something fails:

```text
Reproduce
   ↓
Observe Actual Error
   ↓
Identify Root Cause
   ↓
Make Smallest Correct Fix
   ↓
Retest
   ↓
Check for Regression
```

* Do not randomly rewrite code until the error disappears.
* Prefer fixing root causes over adding patches.
* Do not suppress errors merely to make the debugger quiet.
* Preserve useful diagnostics until the issue is understood.
* When a bug crosses system boundaries, trace the data/state flow between systems.

---

# 23. Dependency and API Discipline

* Prefer Godot-native functionality when it solves the problem adequately.
* Do not add a plugin or third-party dependency for a trivial problem Godot already solves well.
* Before adding a dependency, determine:

  * why it is needed
  * where it will be used
  * whether it is maintained
  * whether it adds significant architectural complexity
* Keep third-party integrations behind clear boundaries where practical.
* Do not let external services leak throughout the entire codebase.
* When APIs may vary by Godot version, verify compatibility with Godot 4.7.x.

---

# 24. Data-Driven Design

* Prefer data-driven systems when the same logic operates over many pieces of content.
* Separate content from code where practical.
* Use Resources, JSON, configuration files, or other appropriate data formats according to the project's needs.
* Do not put large content tables directly inside scripts unless there is a clear reason.
* Avoid hardcoding content that designers/users need to edit frequently.
* Do not over-generalize small amounts of data into a complicated content framework.

---

# 25. UI, Gameplay, and State Separation

For non-trivial systems, prefer:

```text
Input
  ↓
State / Domain Logic
  ↓
Feature System
  ↓
Presentation
```

Examples:

* A button should request an action, not directly modify every part of the application.
* A gameplay system should update state, not search the UI tree to change five labels.
* A UI view should observe relevant state and display it.
* A score calculation should not depend on the visual position of a Label.
* A database/network service should not know which Button triggered it.

Keep the **source of truth** in the system that owns the data.

---

# 26. State Machines

* Use a state machine when the system genuinely contains distinct mutually exclusive states and transitions.
* Do not create a state machine merely because a tutorial used one.
* States should define meaningful behavior and transitions.
* Avoid giant conditional chains when a small state machine would materially improve clarity.
* Avoid state machines for trivial two-state logic that is clearer as a boolean.

---

# 27. Animation and Presentation

* Keep presentation effects separate from core state logic where practical.
* Gameplay state should not depend on an animation finishing unless that timing is intentionally part of the mechanic.
* Animation callbacks/signals may trigger gameplay events when that relationship is deliberate.
* Do not use animation as a hidden state machine for important business/gameplay rules.
* Avoid excessive animation that reduces responsiveness or clarity.

---

# 28. Audio

* Centralize shared audio behavior when the project actually has enough audio complexity to justify it.
* Do not create a global audio manager merely to play a handful of sounds.
* Use reusable audio components or buses appropriately.
* Important UI/gameplay states should not rely solely on audio for communication.
* Allow volume categories/settings to be controlled centrally where appropriate.

---

# 29. Localization and Text

* Do not hardcode user-facing text throughout scripts when the project may require localization.
* Keep player-facing strings centralized or localization-ready when appropriate.
* Avoid placing critical logic in string comparisons.
* Use stable IDs/enums for logic and human-readable strings for presentation.
* Do not assume one language has the same text length as another when designing UI.

---

# 30. Mobile and Multi-Platform Rules

* Do not assume desktop input, screen size, aspect ratio, storage, memory, or performance.
* Test touch targets and touch interactions for mobile.
* Consider lifecycle interruptions such as:

  * app backgrounding
  * returning to the app
  * interruptions
  * device rotation where relevant
* Avoid unnecessary background processing.
* Keep memory usage appropriate for the weakest supported device.
* Platform-specific code must remain isolated where practical.
* Do not force every platform through the same implementation when platform constraints genuinely differ.

---

# 31. Scope Discipline

Before implementing a new feature, determine:

```text
Does this improve the current core experience?
        ↓
Yes → Build the smallest useful version.
No  → Question whether it belongs in this project.
```

* Do not add features simply because they are technically interesting.
* Do not build systems for hypothetical future requirements unless the current architecture clearly benefits from them.
* Avoid feature creep.
* Prioritize the smallest change that creates meaningful user/player value.

---

# 32. Agent Rules for Existing Code

When working in an existing project:

* Read before editing.
* Understand before refactoring.
* Reuse before duplicating.
* Modify before replacing.
* Verify before declaring completion.
* Preserve behavior unless change is intentional.
* Never hide an error just because fixing it is inconvenient.
* Never remove a system merely because a cleaner-looking replacement seems possible without checking dependencies.
* Never perform a large refactor when a small local fix solves the requested problem.
* Avoid changing unrelated formatting.
* Do not rename public APIs, nodes, signals, Resources, save fields, or files without checking their consumers.

---

# 33. Agent Rules for New Systems

When introducing a new system:

1. Identify its responsibility.
2. Identify its owner.
3. Identify its inputs and outputs.
4. Determine whether it belongs in:

   * a Node
   * a Scene
   * a Resource
   * a plain script/class
   * an Autoload
   * a backend/server
5. Identify how it communicates with existing systems.
6. Build the smallest working implementation.
7. Verify it.
8. Only then extract reusable abstractions.

The agent should be able to answer:

```text
Who owns this?
Who can call it?
Who can modify its state?
Who does it depend on?
Who depends on it?
```

before introducing a major new architecture.

---

# 34. Definition of Done

A meaningful task should normally be considered complete only when:

* the implementation exists
* the implementation follows the project's architecture
* code is statically typed where appropriate
* scene/node structure is clean
* no unnecessary duplication was introduced
* no unnecessary Autoload/plugin/dependency was introduced
* parser/type errors are resolved
* runtime errors are checked
* the primary interaction was tested
* existing related functionality still works
* important edge cases were considered
* platform-specific behavior was checked when relevant
* no secrets were introduced
* no unrelated files were modified unnecessarily
* the resulting code is understandable by another developer

Do not optimize for "task appears completed."
Optimize for **"task is correctly implemented, integrated, and verified."**

---

# 35. Final Design Philosophy

Prefer:

```text
Simple
Readable
Typed
Scene-based
Data-driven
Composable
Testable
Profiled
Secure
Maintainable
```

Avoid:

```text
Over-engineered
Deeply coupled
Globally stateful
Hard-coded
Duplicated
Prematurely optimized
Procedurally generated without need
Unverified
```

The goal is not to create the largest or most sophisticated architecture.

The goal is to create the **simplest architecture that can cleanly support the actual project and evolve without becoming fragile**.

---

# 36. Reference Documentation

Godot 4.7 documentation:

https://docs.godotengine.org/en/4.7/

GDScript style guide:

https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html

Best practices:

https://docs.godotengine.org/en/4.7/tutorials/best_practices/index.html

Project organization:

https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html

Performance:

https://docs.godotengine.org/en/4.7/tutorials/performance/index.html

Resources:

https://docs.godotengine.org/en/4.7/classes/class_resource.html

InputMap:

https://docs.godotengine.org/en/4.7/classes/class_inputmap.html
