# Enemy spawn separation and cap facing

Status: Implemented.

Battle startup places the enemy front half a viewport width beyond the player's
frontmost occupied Squad slot, measured at normal 1x camera zoom. The enemy
anchor moves with its units so Homes remain correct. Larger armies extend the
right boundary, camera limit, and existing background tiles as needed. Sandbox
restarts reset the boundary and camera limit before recalculating the gap.

Child and Adult cap followers copy the complete body transform. Previously,
copying global scale without rotation split the reflected transform incorrectly
when facing left, inverting the cap independently of the body.

## Verification

Run outside the agent sandbox on macOS, per `AGENTS.md`:

```sh
godot --headless --fixed-fps 60 --path . .scratch/enemy-spawn-facing/check_spawn_facing.tscn
```

The original reproduction reported a -1008 px front gap for 12 players versus
24 enemies and inverted Child/Adult caps after turning. The corrected check
covers 1v1, 1v23, 12v24, 10v36, 24v24, sparse Squad slots 0/9, sandbox restarts,
arena/background coverage, Home alignment, repeated turns while idle/walking,
leaning/scaling, and a live enemy attacking from behind the squad.

Optional visual check (writes `/private/tmp/enemy-spawn-facing-preview.png`):

```sh
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 1280x720 .scratch/enemy-spawn-facing/check_spawn_facing.tscn -- --preview
```
