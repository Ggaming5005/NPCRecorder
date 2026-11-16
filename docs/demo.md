# Loading-yard demonstration

The example builds an original warehouse courtyard, a sage guard robot, and a terracotta intruder. All assets are native Parts and text. No external model, texture, animation, audio, or lighting configuration is required.

Put `Demo.luau` and `DemoScene.luau` in `ReplicatedStorage.NPCRecorderExamples` beside the recorder in `ReplicatedStorage.NPCRecorder`. Run `RunDemo.server.luau` from ServerScriptService, or invoke this in Edit Studio's server command context:

```lua
local r = game:GetService("ReplicatedStorage")
local demo = require(r.NPCRecorderExamples.Demo).start(
    require(r.NPCRecorder), workspace, Vector3.new(150, 0, 0)
)
-- Finish explicitly:
-- demo:Destroy()
```

`Demo.start(Recorder, parent, origin?)` returns `Recorder`, `Scene`, `Guard`, `Intruder`, and an idempotent `Destroy()` method. The default origin is `(150, 0, 0)`. Use a clean area of Workspace; unrelated collidable geometry can legitimately change the ray results.

The intruder physically follows a repeating 22-second, five-segment route around `LoadingBayWall`. The guard moves along a deliberately simple front corridor. A real Workspace raycast from the guard's eyes to the intruder determines sight; detection is omnidirectional within 43 studs. These are explicit demonstration rules, not a general NPC framework or automatic inference of AI intent.

- **Patrol:** follow the marked front-lane waypoints.
- **Chase:** a clear ray and sufficient range; move toward the target's projection onto the front corridor.
- **Search:** a ray becomes blocked or the target leaves range; move toward the last seen corridor position and look around.
- **Patrol resumes:** no clear sighting for three seconds.

Only state changes, patrol-waypoint changes, and materially moved chase destinations create records. The reason string reports the actual hit Instance name when a ray is obstructed. The thin sight-line part ends at that hit. Position samples come from the recorder's normal tracking, not a prewritten history.

Routes use explicit waypoints and corridor projection; this example does **not** call PathfindingService. Recorded `Path` values are those chosen destinations, not claimed navmesh results. `Capture()` is called after initial setup; the recorder's configured one-second publishing keeps the private snapshot current.

For a wide view from the south side, aim the Studio camera from `origin + Vector3.new(25, 35, 50)` toward `origin + Vector3.new(0, 2, 0)`. The title sign faces that camera. Let the scene run for at least one complete 22-second route before scrubbing a trace; each transition was observed from live movement and raycasts.

`demo:Destroy()` disconnects the Heartbeat and scene-lifecycle connections, destroys its recorder, and removes every scene asset. Destroying `demo.Scene` also invokes that cleanup. Destroying only a launcher script is not a cleanup mechanism.
