# Research and design

Reviewed 17 November 2026. The implementation and example assets are original. No third-party source is bundled.

## Existing tools and scope

[Studio's debugger](https://create.roblox.com/docs/studio/debugging) already provides breakpoints, stepping, watches and call stacks. [Roblox's pathfinding visualization](https://create.roblox.com/docs/characters/pathfinding) displays navigation meshes and pathfinding modifiers. These are useful for code execution and navigability; NPCRecorder adds a bounded timeline of the values and explanations an NPC system deliberately records.

[BehaviorTrees3 / BTrees](https://devforum.roblox.com/t/behaviortrees3-btrees-visual-editor-v30/836158) and [TreeAI](https://devforum.roblox.com/t/treeai-easily-create-behavior-trees-for-your-npcs/4034006) provide visual debugging tied to their behavior-tree systems. NPCRecorder requires only small recording calls, allowing a state machine, behavior tree or custom controller to supply its own state/reason text. It neither replaces those frameworks nor claims to recover uninstrumented decisions.

## Engine interfaces

- [RunService](https://create.roblox.com/docs/reference/engine/classes/RunService) defines Studio, Edit and Server/Client contexts. Edit mode can report IsClient true; recorder gating must explicitly distinguish Edit from a running Play Client.
- [ServerStorage](https://create.roblox.com/docs/reference/engine/classes/ServerStorage) keeps the published session inaccessible to clients. No debug RemoteEvent or client-to-server data channel is introduced.
- [HttpService](https://create.roblox.com/docs/reference/engine/classes/HttpService) supplies local JSON encoding/decoding. This project does not make HTTP requests.
- [WireframeHandleAdornment](https://create.roblox.com/docs/reference/engine/classes/WireframeHandleAdornment) draws paths and labels without adding collidable scene geometry. Its draw-time colors are set before each path/target group.
- [Studio plugins](https://create.roblox.com/docs/studio/plugins) supply the dock widget and toolbar. Plugin-owned adornments are cleared on close and destroyed on unload.

## Ownership and data model

Each entity has a ring buffer bounded by event capacity and age. Stored events copy and freeze scalar/vector/path values, so later caller mutations cannot change history. Snapshot ordering uses time, entity and a stable per-entity tie order; simultaneous decisions must not reorder during scrubbing.

The runtime samples the actual tracked model position and attaches the most recent explicit decision context. Publication serializes into a private ServerStorage StringValue. The inspector reads and validates a frozen snapshot, then redraws a historical marker and supplied paths. It never moves the recorded NPC or rewinds the live game.

The eight-ID, 512-event-per-ID, 24-point-path and 2-MiB JSON bounds keep the initial scope finite. They are not hardware performance benchmarks. JSON must be copied before stopping Play to preserve a trace; automatic durable storage is deliberately absent.

The guard example uses explicit corridor movement and real sight raycasts. Its route is not a PathfindingService output. Its reason strings correspond to its actual branches, avoiding a prewritten recording presented as live AI behavior.
