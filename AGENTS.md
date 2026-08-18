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

- Enemy specs come from `EnemyComposer.specs_for_day()` → `Array[EnemyUnitSpec]` (`unit_data` only). Armies are authored `EnemyUnitData` types (Solar Sword / Rose Thorn / Peashooter / Stump plus Solar Cleaver / Durian / Log / Canopy / Seed Lobber / Acorn Knight), not shop weapons.
- Each `EnemyUnitData` authors average STR/DEX/CON/SPD (`stats`) and `show_held_weapon`. Instance stats roll ±1 via `make_stats()`; enemies do **not** use `PowerTier`. Projectiles always come from `combat.projectile_scene` even when held weapon art is hidden.
- Scout UI lives in `scout_bubble/scout_bubble.tscn` (`ScoutBubble`); it fills `GameState.upcoming_enemy_formation`. Roster build reads that array (combat via `BattleLaunch`). Scout reroll costs `BiomassData.SCOUT_REROLL_COST` and bias-picks a different difficulty (scored from authored average stats) — **disabled on elite days**. Scout shows the formation's **Battle reward** (day base × difficulty), not per-kill sums.
- Winning a battle grants a day-scaled **Battle reward**: base `10 + 5 × (day − 1)`, then ±10% from where that army's `difficulty_score` sits between seeded day min/max samples (`EnemyComposer.battle_reward_for`). Lump sum on victory; no per-kill biomass.
- Every 5th battle is elite (`GameState.is_elite_day`: days 5 and 10): harder procedural band (more units), seeded by `GameState.run_seed` + day. No scout reroll; skull hover on the base progression track previews that elite army in the scout bubble.
- War Chamber header (under the title) shows `CombatProgressTrack`: current 5-battle chapter (4 circles + elite skull) with a marker under the upcoming day.
- Days 1–2 are Solar Sword-only (`min_day` gates other types); day 3 unlocks Rose Thorn/Peashooter/Stump; day 4+ can include Solar Cleaver/Durian/Log/Canopy/Seed Lobber/Acorn Knight. Day curve scales unit count only. Run start: blocking seal pick (`SealChoiceDialog`, 3 rolled offers), then War Chamber package pick (`StarterPackages` / `StarterChoiceDialog`) — one dual-trained combo Adult (common tier) plus a hidden untrained Child. Starting biomass is 3. Mid-run seal picks still queue after days 2 / 5 / 8.

## Cursor Cloud specific instructions

Engine: **Godot 4.7.x** (project targets `4.7`, see `project.godot`). The setup installs `godot` (4.7.1-stable) on `PATH` and the matching export templates; both persist in the VM snapshot, so the startup/update script does not re-download them.

Running the game (dev mode): there is no GPU/Vulkan in this VM, so the default Forward Plus renderer fails. Run with the Compatibility (OpenGL) renderer on the pre-running X server at display `:1`:

```
DISPLAY=:1 godot --path /workspace --rendering-driver opengl3
```

This uses Mesa `llvmpipe` software rendering — it works but is low-framerate, so screen recordings of fast events (e.g. a battle that resolves in ~7s) look choppy; prefer screenshots for evidence.

Audio: no sound card exists, so ALSA `cannot find card '0'` errors print on launch and Godot falls back to the dummy audio driver. This is expected and harmless.

Export: `make help` lists targets (`build-web`, `run-web`, `build-macos`, `run-macos`, `build-windows`, `upload-web`, `upload-steam`). Templates are installed. `upload-steam` publishes to Steam Demo 5112860 only.

Tests/lint: none exist — there is no test framework (no GUT/gdUnit) and no configured linter/formatter. For parse errors, use IDE diagnostics (`ReadLints`). Do **not** use `godot --script some.gd --check-only`: that still loads autoloads/GDExtensions (GameAnalytics inits; `OS.has_feature("editor")` is false) and is not a cheap syntax check.

Local CLI (macOS): `--headless` is `--display-driver headless` + dummy renderer and **does** boot. The SIGSEGV in `SPIRVToMSLConverter` happens when Godot runs **inside the agent sandbox** (also fails to write `user://logs`). Launch Godot with sandbox disabled (`required_permissions: ["all"]`), e.g. `godot --headless --path . --quit-after 1`. If a sandboxed launch crashes, do not retry in a loop — retry unsandboxed once, or stop. Cloud play-with-window remains `DISPLAY=:1 godot --path /workspace --rendering-driver opengl3`.

Binary assets (`*.png`/`*.svg`/etc.) are normal git blobs, not Git LFS. `.gitattributes` marks them `-text` only.

## Agent skills

### Issue tracker

Issues live as local markdown under `.scratch/<feature>/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.
