# ElevenLabs game SFX

Status: Generated and installed on 2026-09-15.

## User request

“I bought 10$ of credit, generate the SFX with ElevenLabs Sound Effects V2.”
Preserve the previously selected playful organic style and the whole-game
coverage defined in [the SFX spec](../game-sfx/spec.md).

## Implementation

- Generate three takes for each of the existing 40 cues using
  `fal-ai/elevenlabs/sound-effects/v2`: tactile UI feedback, shop and nursery
  actions, combat attacks and impacts, special abilities, and outcome stingers.
- Keep the same cue filenames, bus routing, saved volume controls, randomized
  pitch, cooldowns, and gameplay/UI pause behavior. Music is separate work.
- Retain every original take and generation request locally. Store the prompts,
  durations, request IDs, model name, selected takes, and source/output hashes.
- Prepare short mono 44.1 kHz, 16-bit PCM WAVs with trimmed padding, a gentle
  35 Hz high-pass, short endpoint fades, and at least 3.1 dB peak headroom.
- Choose takes using retained event energy and quiet tails, keeping over 95%
  of the detected event energy in every selected clip. This is an objective
  timing check, not a subjective listening assessment. Provide a preview for
  listening, plus all alternate takes for later revision.
- Bundle the selected files in the game. No runtime API calls or new dependency.
- Preserve the previous synthesized generator as a comparison tool, writing
  outside the live asset directory.

## Generation and authoring

120 successful takes, totaling 92.4 requested seconds at $0.002/second:
**$0.1848 estimated generation cost**. This does not claim an exact account
balance. No additional generation is needed for offline preparation.

`plan.json` contains the authored prompts and preparation limits.
`requests.json` records the actual inputs and returned request/audio locations.
`raw/` retains all 120 MP3s. `manifest.json` records all prepared takes, selected
outputs, hashes, levels, durations, and listening-preview timestamps.

Run `python3 .scratch/elevenlabs-sfx/process_sfx.py --prepare` from the repository
root to recreate the ignored `prepared/` folder, manifest, and preview using
Python 3 and `ffmpeg`. Add `--install` to copy the selected WAVs into the game.
The script does not invoke generation or spend credits. `--download` only
retrieves missing cached source files using the recorded output URLs.

## Verification seams

- Audit all 120 decoded WAVs and source hashes; ensure all 40 selected asset
  hashes match the manifest and a repeated offline preparation is deterministic.
- Import the changed files in Godot and run the existing focused SFX/UI checks.
- Run a real combat session at 4×, observe cue playback, and inspect the SFX bus
  recording for non-silent output and clipping.
- Run the combined audio and settings regression checks once after installation.

## Verification results

- All 120 source hashes and prepared WAVs pass the format, non-silence, peak,
  duration, and zero-endpoint audit. All 40 installed files match the manifest.
- Repeating offline preparation produces identical selected WAV hashes.
- Selected clips last 55 ms–1.4 s and retain at least 96.17% of detected event
  energy before endpoint fades. Every source take is retained locally.
- Godot 4.7 import/parse check: clean.
- Focused SFX/UI runtime: 43 assertions passed, no errors or warnings.
- Real combat playback at 4×: 7 assertions passed. The stereo SFX bus recording
  has 7.64 dB peak headroom and zero clipped samples.
- Combined audio runtime: 106 assertions passed, no errors or warnings.
- Settings/combat regression: 57 assertions passed, no errors or warnings.
- Standards review: no findings. Spec review: no findings. Both independently
  verified the source/selected-file hashes and three-takes-per-cue coverage.
- Subjective listening quality is unassessed. The listening preview and all
  alternate takes are provided for that review.
