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

- Top-center HUD button toggles `Engine.time_scale` to 2×.
- Preference lives on `GameState.combat_fast_forward` for the session; restore on combat enter.
- Always reset `Engine.time_scale` to `1.0` on battle end and `_exit_tree` so non-combat scenes stay normal speed. Do **not** clear the preference when resetting scale.

## Enemy / starter composition (`troop_selection_screen.gd`)

- Enemy day composition dict supports `"melee"`, `"spear"`, `"bow"` keys; bow uses `basic_bow.tres`.
- Combat spawns from roster weapon data (`WeaponRange.RANGED`, etc.) — composition builders must create units with the right weapons.
- Initial player troop / `_make_default_starters()`: one melee, one bow, one spear (average tier).
