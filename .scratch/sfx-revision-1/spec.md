# SFX revision 1

Status: implemented and verified on 2026-09-15

## Requested sound direction

Keep ElevenLabs Sound Effects V2 through Fal, using the user's existing credit.
Replace these twelve cues: purchase (cash register ka-ching), plant (shovel
burying something), harvest (forceful loot-box reveal), slash and heavy_swing
(more impact), bow (recognizable bowstring release), hit_blunt (solid blunt
thud), explosion (powerful blast), battle_start (clear, in-tune trumpet fanfare),
battle_win (victory fanfare), run_win (larger victory fanfare), and run_loss
(sad trumpets). Keep the playful organic game character where appropriate.

Great weapons should have more pronounced attack sounds and impacts. Give Great
Sword/Spear, Hammer/Shield, Bow, Spear throws, Horn and shield blocks dedicated
heavier cues. Append new cue IDs so serialized existing projectile IDs stay valid.
Great weapon presentation must not change damage types, damage, knockback,
projectile behavior, timing or music. Great Shield keeps its authored slashing
damage while using a blunt shield bash sound. Status damage must not inherit a
Great weapon impact just because its credited killer carries a Great weapon.

## Implementation

Generate three takes for each of 20 cues (12 requested replacements, a stronger
existing Great Horn launch, seven new Great variants). Retain originals, requests,
prompts, all source takes and chosen-take metadata. Preserve complete attack bodies
and brass phrase tails: short combat cues at most 1.5 s, loot reveal 2 s, outcome
fanfares at most 4 s. No random pitch on cash-register/reward/fanfare cues.

Keep Godot import normalization enabled for every SFX and cue gain/cooldowns
controlling the crowded combat mix. Preserve overlapping random-pitch playback.
The 18-vs-24 mixed Great-army test exposed 46 clipped samples in a 39-second SFX
capture. Add a -1 dB peak limiter to the SFX bus to handle overlapping bursts
without lowering every isolated cue. Keep the Music bus unchanged.
Refresh the playable Codex browser review at http://127.0.0.1:8787/ with current
contexts, all new sounds, previous/revised comparison and existing review notes.

## Verification

Use the existing audio and combat runtime seams. Check all regular and Great
weapon attack/impact routes, Great Shield block/bashing, and status-damage isolation.
Reimport with Godot and run the audio, settings and real-combat checks. Record the
SFX mix at 4x to check clipping. Verify browser playback and note preservation.
Use the implement skill's Standards/Spec review and commit only this task's files.

## Results

- All 60 ElevenLabs V2 requests completed. Estimated generation cost: $0.1707
  for 85.35 requested seconds. All originals and thirteen previous WAVs retained.
- Twenty installed WAVs match the selection manifest; all source hashes audited.
  Selected takes retain 100% of detected event energy before endpoint fades.
- All 47 imports normalize in Godot, with non-looping QOA compression.
  Godot import and runtime logs have no script errors or warnings.
- Audio regression: 106 assertions; settings/pause regression: 57; combat: 27.
- The final mixed-army capture at 4x and SFX 100% lasts 39.47 seconds, peaks at
  -1.00 dBFS and contains zero clipped samples after the SFX limiter.
- The browser shows all 47 cues, or just the twenty revised/Great cues. All forty
  comparison playback buttons were exercised successfully; game-level/pitch controls
  work and all twelve existing review notes survive refresh. Screenshot checked.
- Standards review: no findings. Spec review: no findings, including follow-up
  review of the limiter and crowded-combat check.

Sound direction is authored in the generation prompts; take selection uses
duration, peak-normalized body and tail metrics. Subjective sound character and
musical tuning remain for the user's listening review. Current previews are
lossless captures of the Godot-normalized streams at -6 dB, with game gain applied
by the browser when selected. Previous previews preserve the previous normalized
takes. Great comparisons use the current regular cue.
