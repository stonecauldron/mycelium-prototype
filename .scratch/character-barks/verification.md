# Bark verification

## Agreed seam

The approved spec's Battle acceptance checks are exercised through the combat scene's public `start_battle` API, Unit damage, actual speed/menu controls, and visible bubble text. Tests use real scene instances; fixture troops can be held still to isolate reading time. Cosmetic occurrence rates may be set to certainty when checking event routing.

Red/green slices covered the named opening, fast-forward clearing, credited kills, permanent-death mourning, and victory. The remaining lifecycle cases were added as regression checks at the same seam.

## Runtime checks

Verified with Godot `4.7.stable.official.5b4e0cb0f` on macOS. Run Godot outside the agent sandbox, as required by `AGENTS.md`.

```sh
godot --headless --path . res://.scratch/character-barks/check_barks.tscn
godot --headless --path . res://.scratch/mace-school/check_combat.tscn
godot --headless --path . res://.scratch/settings-menu/runtime_check.tscn
```

- Bark acceptance scene: **0 failures**. Checks cover all four triggers, full names, Child and Adult speakers, three-second reading time, menu pause, reaction cooldown, priority, dropped busy events, speaker movement/death/offscreen cleanup, Zombie revival, uncredited/friendly kills, fast-forward suppression, Run-wide opening-pool exhaustion, speaker variation, and isolated cosmetic randomness.
- The normal-outcome check uses the actual combat scene and Day summary transition at 1× and 4×. It observes the whole celebration, verifies that dialogue ends before the existing fade, and checks restored engine timing. A fixed wall-clock sample proved unreliable because the existing celebration lead-in runs on physics ticks; the test now observes visible text throughout that lifecycle.
- Existing combat smoke: **12 scenarios, 0 failures**, covering six weapons at 1× and 4×, damage, projectiles, and shield throws.
- Existing settings/menu regression: **0 failures**, covering Base choices, menus, paused combat at 1×/2×/4×, projectiles, Zombie respawn, hitstop, and timing restoration on exit.
- Godot editor loading completed without script parse errors. There is no configured project-wide test framework or linter; these are focused runtime scenes and the existing combat/menu smoke suites.

## Visual checks

```sh
godot --path . --rendering-driver opengl3 --resolution 1440x810 res://.scratch/character-barks/check_barks.tscn -- --visual-only
```

Native captures verified the opening, the longest personalized mourning line, long Generation names, and zoom at 0.55. The automated text-fit checks passed. Screenshots are written to `/private/tmp/character-barks-opening.png`, `/private/tmp/character-barks-mourning-long-names.png`, and `/private/tmp/character-barks-mourning-zoomed-out.png`; they are temporary QA artifacts, not project assets.

The final paper position clears the existing fallen/streak callout area. Its downward tail follows the speaker's head and renders beneath those callouts. Typography, wrapping, and padding were checked against the cream paper's irregular edges.

The Compatibility renderer emitted the already-documented texture/RID cleanup errors on native shutdown (also recorded in the settings-menu work). Headless runtime checks did not emit those renderer cleanup messages.

For the actual victory transition alone:

```sh
godot --headless --path . res://.scratch/character-barks/check_barks.tscn -- --normal-outcomes
```

## Code review

Review baseline: task-start commit `38b3da2ffeec94471fa0456d403947abfabb33ef`, compared with the staged implementation before its requested commit.

- **Standards:** no findings against the repository guidance and conventions.
- **Spec:** one initial P2 finding that the paper obscured the existing fallen callout. Increased clearance and lowered tail ordering resolved it; the reviewer checked the updated implementation and native captures. No remaining findings.
