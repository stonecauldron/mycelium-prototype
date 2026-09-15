# Revision 2 verification

Date: 2026-09-15. Baseline: `c915ad2`.

## Assets and authoring

- Eleven replacement WAV hashes match the final manifest. All four layered
  recipes independently reproduced the installed hashes in Spec review.
- All 43 accepted source hashes and layer-source hashes match. One of the 44
  generated takes was effectively silent and is explicitly rejected.
- The twelve previous WAVs exactly match the baseline commit. Explosion's
  current WAV is unchanged; its authored gain rises from -8 to -4 dB.
- All 47 imports normalize. The eleven replacements use uncompressed PCM.
- Selected durations are 140 ms–2.934 s, with source WAV peaks at -3.1 dBFS.
  Final trimming retains all energy above the pipeline's active-event threshold;
  explicit layer envelopes intentionally shorten source resonance.
- Generation: 94 requested seconds at $0.002/second = estimated $0.188.
  48 short audio-description requests add approximately $0.48, totaling $0.668.
  These are estimates, not a billing statement.

## Engine and mix

Godot ran outside the macOS sandbox as required by AGENTS.md. Import completed
without script errors. The existing suites completed sequentially:

- Audio infrastructure, cue bank, UI feedback and music: **106 passed**.
- Real combat, Great routing and owner/status edge cases: **27 passed**.
- Settings menu and result screens: **57 passed**.

Total: **190 passed**, no failures or script errors. The combat test recorded
40.59 seconds, including the crowded Great army at 100% SFX volume. Peak was
**-1.0 dBFS**, with **zero clipped samples**. Settings were restored by the
existing test cleanup. Python compilation and `git diff --check` passed.

Logs: `/private/tmp/sfx-revision-2-{import,audio-runtime,combat,settings}.log`.
Mix: `/private/tmp/mycelium-combat-sfx.wav`.

## Browser review

Rebuilt `http://127.0.0.1:8787/` from all 47 Godot-imported resources. The twelve
revised cues compare against their immediately previous versions, including
Great cues. Verified in the actual Codex browser:

- All 24 updated/previous buttons reached their expected Playing/Played state
  without decode/playback errors; Stop worked.
- Default level is In-game levels, exposing the explosion's +4 dB change.
- Revised filter contains 12 cues; All sounds contains 47.
- The exact existing change-request text survived reload unchanged.
- The screenshot showed the refreshed summary, contexts and labeled controls.
- The tab remains open as a deliverable.

The player uses lossless previews of normalized Godot captures. Playback success
does not establish artistic quality. Source-identity screening is inconclusive
for the final very short composites (see spec and final-audio-analysis.json);
the user's listening review remains the acceptance check for their character.

## Code review

- Standards: **0 findings**.
- Spec: **0 implementation findings**; listening limitation acknowledged.

Reviews excluded existing music assignments/files, art changes and Great
resource field-order edits. These remain outside this revision.
