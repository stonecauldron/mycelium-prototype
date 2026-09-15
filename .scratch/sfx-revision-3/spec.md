# SFX revision 3

Baseline: `5f7f66b`. Status: implemented and ready for listening review.

- Harvest: keep the egg-hatching direction, add substantial body and impact.
- Bow: use the user's supplied archery sample verbatim. Earlier generated bows
  repeatedly missed the requested source; this uses the explicitly allowed fallback.
- Great Bow: use that same recording with stronger low-end/body and a cue gain
  3 dB above regular Bow. Preserve the release timing and full sample content.
- Blunt impact: more violent, with a sharper attack and heavier body.
- Explosion: louder and more violent, preserving a clear blast and fuller tail.
- Run win, run loss, Great swing and Great throw: restore the exact Previous
  versions from the current player (revision 1 / `c915ad2`), including their
  original cue gains and import compression.

Use local audio processing only; no generation or additional Fal spending.
Keep all 47 Godot normalization flags, cue hooks, randomized-pitch policy,
SFX limiter and silent starter receipt. Preserve unrelated music/art changes.

Record sources and finishing recipes. Refresh the nine comparisons against the
immediately preceding version; preserve notes and all 47 contexts. Validate the
copied bow and restored hashes, imports, durations, mix and real playback.
