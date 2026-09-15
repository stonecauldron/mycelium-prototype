# Audio infrastructure

Status: Implemented and verified on 2026-09-15.

## Confirmed behavior

- Build the playback infrastructure and settings; audio files will be added later.
- SFX and Music are separate volume groups. Multiple SFX can play simultaneously.
- Add SFX and Music sliders to the existing in-run Settings page: 0–100%, default 100%, apply immediately, persist across launches. Zero mutes that group.
- SFX are non-positional. Gameplay SFX pause with gameplay; UI SFX can play while the menu is open.
- Both SFX helpers randomize each playback's pitch by ±10% by default, including reused voices. An optional fractional variation controls the range; zero gives normal pitch. Audio uses its own random generator so sound playback does not alter gameplay rolls. Music pitch remains unchanged.
- Music loops, continues while paused, and keeps normal pitch and speed during fast-forward and hitstop.
- Provide two configurable music slots with dedicated players: Base and Battle. The foreground track plays at full volume; the background track plays at 20%. Normal transitions preserve both playback positions.
- Music playback survives scene replacement.
- Title and Base bring the Base track forward. Combat brings the Battle track forward, keeping that mix through day summary, victory, and game over. Returning to Base or title reverses their levels.
- Battle music first starts on entry into a Battle or result screen; thereafter both songs keep looping. Direct Battle/result entry starts Base music in the background too.
- Empty track slots are valid and remain silent while the other assigned track follows its foreground/background level. Explicitly stopping music fades out and stops both tracks.
- Retain mouse and keyboard navigation in Settings, including left/right adjustment of sliders.

## Implementation

- An authored Godot bus layout routes SFX and Music into Master.
- A persistent audio autoload exposes Base/Battle track slots and helpers for gameplay SFX, UI SFX, music selection, and stopping music.
- Keep SFX playback bounded and reusable. Gameplay effects are cleared when their scene is replaced so old battle sounds cannot resume in the Base.
- Blend to the requested mix over 0.5 seconds measured in real time, including during pause, fast-forward, and hitstop. Repeated or interrupted changes retain the same two music voices and playback positions.
- Store normalized audio volumes in the existing settings file; load and apply them before scene audio starts. Missing values default to full volume.
- Keep settings access in Base and combat, as established by the settings-menu feature.
- Verify routing, live volume changes and persistence, SFX overlap and pause behavior, music looping/continuity/mixing, and actual Settings mouse/keyboard navigation. Use temporary generated audio for checks; ship no placeholder audio.

## Starting point

- `SettingsServer` already stores preferences in `user://settings.cfg`, separately from Run data.
- `RunMenu` is shared by Base and combat and pauses gameplay while open.
- The existing settings-menu scope exposes settings only in Base and combat.
- There are no existing audio players, bus layouts, or sound/music files to migrate.

## Documentation

The authoring guide explains how to assign the two tracks and trigger SFX. The glossary names the two game-specific music roles. These choices are straightforward to reverse, so they do not warrant an ADR.

## Verification

- Godot 4.7 editor initialization/import completed without script errors.
- The focused runtime check passed 74 assertions covering independent bus volumes, mute/unmute, persistence, defaults and invalid values, SFX overlap/pause/scene cleanup, randomized/custom/fixed pitch and gameplay RNG independence, music loops, persistent track positions, 100%/20% mixing, interrupted transitions and stops, first-entry behavior, scene selection, and actual Settings mouse/keyboard input.
- The existing settings/combat runtime check passed all 57 assertions, including pause/resume at 1×/2×/4× and reset of engine timing on return to title.
- The native UI check passed and its rendered Settings panel was inspected. It used the Dummy audio driver; sound samples were generated in memory for verification.
- The native OpenGL run reports the existing three-texture cleanup diagnostics on process exit. The final headless audio check has no warnings or errors.
- Web and Windows playback were not launched.
- Independent Standards and Spec reviews found no issues.

Authoring instructions: [Adding audio](../../assets/audio/README.md).
