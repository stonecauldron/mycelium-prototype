# Revision 3 verification

2026-09-15. Baseline `5f7f66b`; selected Previous versions from `c915ad2`.

## Audio assets

- All nine installed WAV hashes match the manifest; all sources match recorded hashes.
- Regular Bow is byte-identical to the user's original Downloads file and the
  saved reference: 96 kHz, stereo, 24-bit, 0.526 seconds. Godot imports it normally
  with normalization enabled. The source WAV has no editorial changes.
- Great Bow uses the full same recording, with bass emphasis and gentle compression.
  Its cue gain is -10 dB versus the regular bow's -13 dB. It is rendered as
  44.1 kHz mono 16-bit PCM, as documented.
- Run win, Run loss, Great swing and Great throw exactly match the `c915ad2`
  WAVs, import files and cue settings, including original gains.
- All nine preceding WAVs exactly match the baseline. All 47 normalization flags
  remain enabled. The five new/processed clips import as uncompressed PCM.
- Harvest adds a deeper body and longer shell crumble (+2 dB cue gain); Blunt
  impact adds a harder crack and longer body (+1 dB); Explosion adds soft
  saturation and delayed low rumble (+2 dB). Final durations remain within the
  existing cue limits. Full-file levels and recipes are in the manifest/plan.
- No Fal jobs, uploads, or generation charges in this revision.

## Runtime checks

Godot import completed without errors. Existing runtime suites ran sequentially
outside the macOS sandbox, with **193 assertions passed**, no failures or script errors:

- Audio infrastructure, cue bank and generic UI feedback: 106.
- Real combat and Great-weapon/projectile routing: 27.
- Settings/menu/outcome behavior, including silent starter confirmation: 60.

The 40.68-second combat recording included the crowded Great army at 100% SFX.
Peak was **-1.0 dBFS**, with **zero clipped samples**. Explosion's intentional
offline soft saturation adds body; this is separate from mixer clipping.

Logs: `/private/tmp/sfx-revision-3-{import,audio,combat,settings}.log`.
Mix: `/private/tmp/mycelium-combat-sfx.wav`.
Python compilation and `git diff --check` passed.

## Browser

Rebuilt the existing localhost player from Godot captures. The builder preserves
captured channels; both bow previews were verified as stereo FLAC. The header
no longer attributes the supplied recording to ElevenLabs.

- All 18 updated/previous controls reached their expected Playing/Played states
  with no decode/playback errors. Stop worked.
- Nine revised cues, all 47 available in the full filter.
- Default In-game levels; comparison data uses the immediately preceding version.
- Exact existing notes preserved across reload.
- Screenshot verified the updated summary and controls; the tab remains open.

Playback and measurements do not replace the user's listening review for the
subjective strength of the edited impacts. The regular bow's provenance and
verbatim content are established by matching file hashes.

## Review

Standards: 0 findings. Spec: 0 findings. Unrelated existing music/art/resource-order
changes were excluded and remain unstaged.
