# Unit emergence verification

Run from the project root with Godot outside the agent sandbox.

The focused overlapping-hatch regression uses actual viewport clicks, including a second Plot underneath the previous hatch result card:

```sh
godot --headless --path . res://.scratch/unit-emergence/hatch_overlap_check.tscn
```

It verifies concurrent animations, exactly-once harvests, independent completion/cancellation, original result-card sizing, latest-harvest results, and cleanup through Undo, tab departure, pause, Shop interaction and Day advance.

The focused Cocoon continuity regression exercises the nonblocking presentation change:

```sh
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --max-fps 60 res://.scratch/unit-emergence/continuity_check.tscn
```

Latest focused run: **68 assertions passed, 0 failures**, `/tmp/cocoon-continuity-interactions.log`. It verifies that unrelated Squad/Bench card and portrait identities survive reveal start/finish, idle playback continues, formation drops and Start Battle remain available, and the retained destination stays hidden until arrival. It also covers unrelated moves, target swaps, active/pending Cocoon reuse, queued-result resumption, unlock, pause/tab/Undo cleanup, and actual Battle launch with no replay or owned audio left behind. A pending-school reuse case ensures a new delayed Child cannot be hidden by the prior result's queued presentation.

The unchanged baseline produced eight failures before the fix (`/tmp/cocoon-continuity-red.log`) and zero afterward (`/tmp/cocoon-continuity-green.log`). The observed finish frame changed from 37.431 ms to 16.677 ms; these single-run timings are diagnostic, not a performance assertion or benchmark. Both traces preserve instance IDs and idle phases: `/tmp/cocoon-continuity-red-frames.json` and `/tmp/cocoon-continuity-green-frames.json`. The reusable fixture writes its current trace to `/tmp/cocoon-continuity-frames.json`.

Godot LSP reported no diagnostics for `unit_card.gd`, `troop_selection_screen.gd`, or `continuity_check.gd` (`/tmp/cocoon-continuity-diagnostics.jsonl`), or for `cocoon_slot.gd` (`/tmp/cocoon-slot-diagnostics.jsonl`). Initial workspace scanning still reports unrelated legacy `.scratch` errors; those pre-existing fixtures are outside this regression and were left unchanged. No production settings were saved. The older 248-assertion run below predates the nonblocking Cocoon behavior; the focused run is the current evidence for that change.

The broader animation fixture is:

```sh
godot --headless --editor --path . --import --quit
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --max-fps 60 res://.scratch/unit-emergence/runtime_check.tscn
```

The fixture boots the real Base, emits its normal confirmation/plot/action button signals, and uses authoritative Training, harvest, and Compost transactions. It checks:

- Instant Child evolution and mutated Adult combo replacement in Squad and Bench, exact committed units and ordered Trainings, same-frame double confirmation, and no repeat presentation.
- Hidden queued destination cards before launch; opaque cocoon actors at normal UnitCard scale; continuous flight, full painted bounds inside the viewport, and exact final transform against the restored live destination card.
- Two delayed cocoon results, queue retention across an unrelated Nursery Undo, tab cancellation, and one-time queue draining.
- One/six-unit harvests, partial capacity, full Troop rejection, and repeated inputs. Retained actors use authored stage proportions at normal portrait scale, play their walk animation, remain opaque, and fully leave the screen to the right. Result cards appear immediately at animation start, shift toward the next Plot to the right, and retain their existing viewport-fit sizing. The previous full run below predates this card timing change.
- Adult Compost, Child Compost with no spores, and Adult Compost with full Stock. The bin squishes and stretches around its painted ground; only actual new SporeData records animate, preserving identity/tint, and their whole icons exit left. Repeated confirmation pays once.
- Anticipation dim and recovery after release; Undo, tab departure, pause, real window resize, and scene-exit cancellation. Cocoon cards and Compost bin art restore, owned sounds/dims are freed, and cancellation preserves committed results except explicit Undo.
- Reopened Seal choice, Shop lock, camera transition, and debug Day advance while hatching, with no stale result cards.
- Dedicated cue disposal, overlapping reveal-audio leases, recovery while paused, crossfade/duck composition, and unchanged Music bus settings. Cocoon cue onset plus its 15 ms transient offset aligns with release within one 60 fps frame (18 ms tolerance).

Previous full run: **248 assertions passed, 0 failures**, `/tmp/unit-emergence-runtime.log`. Editor import was clean (`/tmp/unit-emergence-import.log`). No script, parse, or node errors occurred. Known renderer-only shutdown output remains: three GL texture/RID leak messages and `RenderingServer` null teardown messages.

Evidence from real Base flows:

- `/tmp/unit-emergence-adult-arc.png` and `-arrived.png`: mutated Adult Great Bow travels into the Squad slot at scale `(1, 1)` and exactly matches the restored portrait origin `(378, 804)` in logical viewport coordinates.
- `/tmp/unit-emergence-bench-arc.png` and `-arrived.png`: upper Bench arc stays in the viewport and lands exactly at `(89, 421)`, also scale `(1, 1)`.
- `/tmp/unit-emergence-delayed-second-arc.png` and `-arrived.png`: actual delayed result lands at `(526, 804)`.
- `/tmp/unit-emergence-hatch-6-release.png`, `-walk.png`, and `-cards.png`: six full-size hatchlings, walking departure, then six result cards. Single and partial-capacity captures use `hatch-1` / `hatch-2`.
- `/tmp/unit-emergence-compost-adult-squish.png`, `-flight.png`, and `-restored.png`: bin anticipation, actual released spores, and restored scene. Child and full-Stock captures use `compost-child` / `compost-adult-full-stock`.

A short actual Base gameplay recording is `/tmp/unit-emergence-revised.mp4` (1920×1080, 60 fps, 12.35 seconds; Adult launch and settled landing → six hatchlings walking out → Adult Compost). The lightweight capture run passed **5 checks, 0 failures** (`/tmp/unit-emergence-continuity.log`), with the full runtime verification above retained separately. Its temporary runner is `/tmp/unit-emergence-continuity.gd` / `.tscn`; it takes no PNG snapshots or geometry samples during flight and holds each completed scene briefly. Contact frames `/tmp/unit-emergence-revised-landing.png` and `/tmp/unit-emergence-revised-departures.png` verify visible continuity. The fresh AVI decodes 741 frames against the recorder's 740-frame summary (one initial frame); the previous clip with repeated buffered frames is superseded. Fixture safety limits use simulation time, so slower movie encoding does not truncate effects. The movie run additionally reports two ObjectDB instances at engine shutdown; it has no script/parse errors.

Audio scheduling, ownership, and music recovery were checked programmatically; no subjective listening audition was performed. This fixture is scoped to emergence and its integration, not an exhaustive UI suite.
