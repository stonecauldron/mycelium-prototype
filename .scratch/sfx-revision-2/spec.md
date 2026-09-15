# SFX revision 2

Status: implemented — ready for user listening review

## User request

- harvest: egg hatching, replacing the loot-box direction.
- heavy_swing and hit_blunt: more physical impact.
- bow: recognizable archery bow release; great_bow: the same recognizable action
  with greater weight than the regular bow.
- explosion: louder. Preserve the current take and raise its cue gain by 4 dB.
- battle_start: clear, in-tune trumpet fanfare.
- battle_win and run_win: more pronounced victory fanfares.
- run_loss: sad trumpets.
- great_swing: a sledgehammer.
- great_throw: regenerate without the audible artifacts.

## Approach

Continue ElevenLabs Sound Effects V2 through Fal using the user's existing credit.
Use literal Foley/brass prompts, initially with lossless PCM output. Generate three
takes per regenerated cue (eleven cues), then targeted alternatives; retain source files and prior game WAVs,
and use the existing offline preparation pipeline. Use Fal Audio Understanding as
an additional screening check, with open-ended descriptions to avoid priming it
with the desired source. This is an imperfect quality signal, not user acceptance.
Try a revised prompt if it identifies the wrong instrument/action. The final
batch has 39 PCM takes and five MP3 alternatives. One effectively silent take is
explicitly rejected. Bow releases and blunt/sledgehammer impacts use short layers
of the generated Foley to shape their source identity and weight; recipes and
source hashes are recorded in the plan and manifest. Run `finish_sfx.py` after
the shared preparation script to reproduce these four finished cues.

Retain Godot normalization, fixed pitch on the four brass cues, cue IDs, existing
hooks, Great weapon routing and the SFX limiter. Keep short effects within 1.5 s
and fanfares within 4 s. Raise explosion by 4 dB and adjust modest cue gains where
needed to give the requested sounds presence in gameplay. Preserve music and
combat mechanics.
Import the eleven replacements as uncompressed PCM to avoid further lossy
compression after normalization, particularly the artifact-sensitive bow/throw sounds.

Refresh the existing browser review, comparing each of these twelve changes with
its immediately previous version, including Great cues. Preserve all notes and
all 47 cue contexts. Default to in-game levels so gain-only edits are audible.

## Screening limits

The final four short composites were also submitted to the audio-description
model. Two responses asked for an audio file despite receiving one; the other
two described a chime and wooden knock. These checks are inconclusive and do
not establish recognizable archery or sledgehammer Foley. The compositions use
generated string/release/impact layers as documented above; user audition in the
review player remains the acceptance check for their character. No listening
quality claim is inferred from successful playback or level measurements.

## Verification

Audit source/output hashes, import normalization, duration, and non-silence.
Run the existing focused SFX/UI and crowded combat checks and inspect the recorded
mix for clipping. Verify previous/current playback, notes and all-cues filter in
the actual Codex browser. Use the implement skill's two-axis review and commit
only revision files; baseline c915ad2. Existing music, art, and weapon-resource
field-order changes are unrelated and must remain unstaged.
