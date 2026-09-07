# In-run settings menu

Status: Implemented and verified with Godot 4.7 on macOS.

## Confirmed requirements

- Place the settings entry point in the upper-right corner of the screen.
- Show it in the Base and during combat.
- Do not show it on the main menu, day summary, victory, or game over screens.
- Use `res://assets/asset_packs/Cila - Paper UI stylized/icon/Icon 03.png` for the gear icon.
- The gear has no surrounding frame or tooltip; hover, press, and keyboard focus tint the icon itself.
- The gear opens a menu with Settings, Resume, Return to title, and Quit.
- Add extra spacing below Resume to separate the red Return to title and Quit buttons. Keep the shared in-game hover, focus, and pressed styles.
- Opening the menu pauses gameplay in both the Base and combat. Resuming preserves the selected combat speed.
- Settings remain accessible during blocking Seal and Starter package selections, preserving the unfinished choice underneath.
- Use a centered paper-style panel, opened by the gear or Escape.
- Settings contains Fullscreen and Back. Apply fullscreen immediately and remember the preference on desktop.
- Escape returns from Settings or an exit confirmation to the menu; Escape from the menu resumes gameplay.
- Clicking outside any menu panel closes the menu and resumes gameplay.
- Return to title and Quit both confirm that the current Run will be lost. Cancel returns to the paused menu.
- Exit confirmations follow the supplied reference: a compact, wide cream paper card over a green backing, maroon heading, red exit action on the left, and teal Cancel on the right. There is no close cross. Keep the existing confirmation wording; buttons use the shared in-game hover, focus, and pressed styles.
- Hide Quit on web, matching the existing title screen.

## Scope

- No audio controls until audio exists.
- No run save/load or Continue feature.
- No changes to battlefield geometry, spawning, or Base tab transitions.

## Design notes

- Both screens have room in the upper-right corner; the Base biomass counter is left-aligned beside the Day label.
- The shared `RunMenu` scene is instanced only by Base and combat, above their blocking choices and below scene transitions.
- `SettingsServer` saves desktop fullscreen separately from Run data. Web fullscreen follows the browser's actual state and is requested from the button's input event.
- Returning to the main menu during a Run would abandon it: the title screen has no Continue action and there is no run save/load.
- Combat and its world now use pausable processing. Hitstop, zombie respawn, projectile fuses, and explosion cleanup timers also pause. The menu leaves combat speed and physics settings intact on Resume; Return to title restores normal engine timing before the scene fade.
- Base run-start Seal and Starter package picks are blocking dialogs; the in-run menu must be accessible above them without dismissing the choice.
- This document records feature behavior; `CONTEXT.md` remains a domain glossary.
- ADR-0009's existing telemetry contract now includes confirmed title-return intent from Base and combat. Abandoning a Run does not mark it as a loss.

## Verification

The focused smoke scene uses actual menu mouse/key input and real Base/combat scenes:

```sh
godot --headless --path . res://.scratch/settings-menu/runtime_check.tscn
```

On macOS, run Godot outside the agent sandbox as required by `AGENTS.md`. For visual checks and fullscreen persistence, omit `--headless` and use `--rendering-method gl_compatibility`; add `-- --fullscreen-only` for the focused display check. The graphical check restores the settings file on normal exit and writes a backup to `/private/tmp/settings-menu-preferences.backup` before changing it.

- Menu mouse/keyboard navigation, outside-click dismissal, focus confinement, and exit confirmations.
- Seal and Starter package choices survive opening and closing the menu.
- Combat position, HP, Acid Rain time, projectile fuses, zombie respawns, and hitstop pause at 1×, 2×, and 4×; Resume preserves speed and physics ticks.
- Return to title releases pause and resets engine timing without clearing the combat speed preference.
- The menu is absent from title, day summary, victory, and game over scenes.
- Native screenshots inspected for Base, combat, menu, Settings, and exit confirmation.
- The supplied exit-confirmation design was checked in the native game; `-- --confirmation-only` runs its focused visual/input check, including Escape and outside-click dismissal, without changing fullscreen. Add `--button-states` to compare rendered normal, hover, and pressed states for both buttons.
- macOS fullscreen toggle, preference save, reload, and return to the original mode passed. Native fullscreen animations must finish before the next toggle in the check.
- Web and Windows builds were not launched. Godot's OpenGL renderer reports three texture cleanup errors on native process exit; the headless checks do not report them.
