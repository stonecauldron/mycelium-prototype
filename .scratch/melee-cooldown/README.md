# Cosmetic melee cooldown motion

Adds recovery, a guarded sway and anticipation during the existing cooldown.
The body, cap and held weapons receive rendering-server offsets after animation
updates. Scene-node transforms remain unchanged, including RemoteTransform2D
followers, weapon launch mounts, hurtboxes and hitboxes. The shadow stays planted.
Variation uses the unit's existing process tiebreak; it never draws from the RNG.

## Verification

Run from the project root (outside the agent sandbox on macOS):

```sh
godot --headless --path . --fixed-fps 60 --quit-after 16000 res://.scratch/melee-cooldown/check_cosmetics.tscn
godot --headless --path . --fixed-fps 60 --quit-after 16000 res://.scratch/melee-cooldown/check_cosmetics.tscn -- --baseline
cmp /private/tmp/melee-baseline.trace /private/tmp/melee-cosmetics.trace
```

Validated with Godot 4.7 on 2026-09-05:

- Both player ages and all ten enemy appearances preserve every Node2D transform
  and RNG state across mirrored/scaled poses and 0.03 / 0.75 / 3-second cooldowns.
- Six matchups at 1x / 2x / 4x produce byte-identical traces with cosmetics enabled
  and disabled: 12,960 physics samples covering health, damage, targets, movement,
  attack timers, collision transforms, projectile origins/trajectories and RNG.
- Enabled runs exercised 6,408 unit pose samples; disabled runs exercised zero.
- Editor import and completed checks report no script errors.

The baseline disables only Unit's new presentation `_process`; physics, authored
animations and attack callbacks run normally in both passes.

## Pose preview

```sh
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1920x1080 res://.scratch/melee-cooldown/check_cosmetics.tscn -- --preview
```

This writes `preview.png` here and exits. The preview was visually inspected for
body/cap alignment, weapon preparation, fixed shadows and enemies without held art.
