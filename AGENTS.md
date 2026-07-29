# Agent guidance — mycelium-prototype

Godot 4.x 2D auto-battler prototype. Prefer minimal focused diffs; match existing GDScript style (static typing, `@onready`, `%UniqueName` where used). Don't commit unless asked; push to main only when explicitly requested. When in doubt, mirror nearby base/combat patterns rather than inventing new systems.

## Layout

- **Base hub** (`assets/base/`): camera-tab zones — War Chamber (troop selection), Nursery, Riboforge.
- **Combat** (`assets/combat/combat_stage/`): battlefield stage and HUD.
- Preserve gameplay node paths and combat floor/spawn logic when changing visuals.

## Base tab transitions (`assets/base/base.gd`)

On tab select, call the destination's `on_screen_shown()` / HUD refresh at **transition start**, not after the camera tween finishes. Heavy UI regen must overlap the pan to avoid post-arrival stutter.

## Combat visuals (`combat_stage.tscn`)

- Reuse base background art from `assets/base/background/` (background, upper_foreground, lower_foreground, lanes).
- **Far backdrop** (screen-fixed, `CanvasLayer`): `TextureRect` is correct.
- **World-scrolling segments**: use `Sprite2D` under `Node2D` — not Control/`TextureRect`. Combat is world space, not Control-hosted UI like base zones.
- Segments tile across the wide battlefield; art may seam if not seamless.

## Combat fast-forward

- Top-center HUD button cycles `Engine.time_scale` through 1× / 2× / 4×.
- Preference lives on `GameState.combat_fast_forward` for the session; restore on combat enter.
- Also scale `Engine.physics_ticks_per_second` (and raise `max_physics_steps_per_frame`) with the same multiplier so each game-time physics step stays ~1/60s — plain `time_scale` alone enlarges deltas and changes collision/projectile outcomes.
- Always reset `Engine.time_scale` and physics tick settings on battle end and `_exit_tree` so non-combat scenes stay normal speed. Do **not** clear the preference when resetting scale.

## Enemy / starter composition

- Enemy specs come from `EnemyComposer.specs_for_day()` → `Array[EnemyUnitSpec]` (`type` / `tier` / `is_imago`; array order = spawn order within each weapon line).
- Scout UI lives in `scout_bubble/scout_bubble.tscn` (`ScoutBubble`); it fills `GameState.upcoming_enemy_formation`. Roster build reads that array (combat via `BattleLaunch`). Scout reroll costs `BiomassData.SCOUT_REROLL_COST` and bias-picks a different difficulty.
- Days 5 and 10 use skill-check override lists (seeded pick if multiple variants); other days use the day curve. Seeded by `GameState.run_seed` + day.
- Combat spawns from roster weapon data (`WeaponRange.RANGED`, etc.) — builders map `EnemyUnitSpec.UnitType` to starter weapon `.tres` files (`sword`, `spear`, `bow`, `shield`).
- Initial player troop / `_make_default_starters()`: one melee, one bow, one spear (common tier).

## Cursor Cloud specific instructions

Engine: **Godot 4.7.x** (project targets `4.7`, see `project.godot`). The setup installs `godot` (4.7.1-stable) on `PATH` and the matching export templates; both persist in the VM snapshot, so the startup/update script does not re-download them.

Running the game (dev mode): there is no GPU/Vulkan in this VM, so the default Forward Plus renderer fails. Run with the Compatibility (OpenGL) renderer on the pre-running X server at display `:1`:

```
DISPLAY=:1 godot --path /workspace --rendering-driver opengl3
```

This uses Mesa `llvmpipe` software rendering — it works but is low-framerate, so screen recordings of fast events (e.g. a battle that resolves in ~7s) look choppy; prefer screenshots for evidence.

Audio: no sound card exists, so ALSA `cannot find card '0'` errors print on launch and Godot falls back to the dummy audio driver. This is expected and harmless.

Web build: `make build` exports the `Web` preset to `build/web/` (templates are installed); `make run` then serves it at `http://localhost:8060` via `python3 -m http.server`.

Tests/lint: none exist — there is no test framework (no GUT/gdUnit) and no configured linter/formatter.

Git assets quirk: `*.png`/`*.svg`/etc. are declared LFS in `.gitattributes` but are actually stored as normal git blobs (`git lfs ls-files` is empty). This makes those binary files show as perpetually "modified" in `git status`. Do **not** stage/commit them — leave them untouched.
