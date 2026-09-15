# Mycelium sound pack

47 effects: 45 based on **ElevenLabs Sound Effects V2** through fal.ai and two
based on the user's supplied archery recording. The regular Bow WAV is that
original 96 kHz stereo 24-bit file, copied verbatim; the other assets are
44.1 kHz mono 16-bit PCM WAV. Godot normalizes all 47 clips
during import (`edit/normalize=true`); per-cue gains in `../sfx.gd` shape the
in-game mix after import.

## Sources

Generated on 2026-09-15 using `fal-ai/elevenlabs/sound-effects/v2`. Three takes
were generated for each cue, with prompts for playful organic one-shot sounds.
The 120 original MP3s, prompts, request IDs, selected takes, and source hashes
are retained in [the authoring folder](../../../.scratch/elevenlabs-sfx/).
Requested audio totals 92.4 seconds; estimated generation cost was $0.1848 at
$0.002/second. This is an estimate, not an account billing statement.

[Revision 1](../../../.scratch/sfx-revision-1/spec.md) replaces twelve reviewed
cues, strengthens the Great Horn, and adds seven Great weapon variants. Its
60 original takes, prompts and selected-file hashes live in
`.scratch/sfx-revision-1/`; the thirteen replaced WAVs are retained in `previous/`.
The revision requested 85.35 seconds, costing an estimated **$0.1707**. Selection
retains full event bodies and trumpet phrase tails, with explicit preferred takes
for stronger peak-normalized body or longer release resonance where useful.

[Revision 2](../../../.scratch/sfx-revision-2/spec.md) replaces eleven WAVs and
raises the existing explosion by **4 dB**. It uses 44 new takes (39 lossless WAVs
and five MP3s), totaling 94 requested seconds: estimated generation **$0.188**.
Automated audio screening adds approximately **$0.48** (48 short checks), for
an estimated revision total of **$0.668**. These estimates are not a billing
statement. Prompts, requests, sources, screening results, layer recipes, and
the twelve previous WAVs are retained in `.scratch/sfx-revision-2/`.

Revision 2 combined generated string/release layers for bows and low thuds for
blunt impacts. Those bow and sledgehammer versions are superseded below.
Its eleven replacements imported as uncompressed PCM
(`compress/mode=0`), retaining Godot normalization. The original MP3 source layers
remain lossy; the finishing and Godot import stages introduce no further lossy
compression. Its four brass fanfares retained fixed pitch and played 3 dB louder.

[Revision 3](../../../.scratch/sfx-revision-3/spec.md) uses the supplied
**Epidemic Sound — Weapons, Bow, Bow, String, Draw, Release 01 (2417-2943)**
recording for both bows. Regular Bow is a byte-for-byte copy, with no source
trimming. Great Bow retains the full release with bass emphasis and gentle
compression, playing 3 dB above the regular bow. Both retain the existing random
pitch variation at runtime and Godot import normalization.

Harvest has a stronger hatching crack and body; Blunt impact has a harder attack
and longer body; Explosion adds saturated blast energy and low rumble with an
additional 2 dB of cue gain. The four selected Previous versions—Run win, Run
loss, Great swing and Great throw—are restored exactly from revision 1, including
their gains and import compression. Revision 3 uses existing/supplied audio and
costs **$0 in generation credits**. Its plan, source copies, previous WAVs and
hashes are retained in `.scratch/sfx-revision-3/`. The five newly processed/copied
assets use uncompressed PCM imports; the four restores keep their original imports.

Preparation removes low rumble, trims quiet padding, adds short fades, and
adjusts level within a peak ceiling. Selection favors complete events with
quiet tails. Revision 2 also uses open-ended automated sound descriptions to
reject mismatched candidates; these are an imperfect signal, not human audition.
Use the current sequential
[listening preview](../../../.scratch/sfx-revision-3/preview.wav) for subjective
review. Its cue order and timestamps are in `manifest.json`; the preview omits
Godot's import normalization and the game's per-cue gains and pitch variation.

From the repository root:

```sh
python3 .scratch/sfx-revision-3/build_sfx.py
```

Requires Python 3 and `ffmpeg`. This rebuilds all prepared WAVs, the selection
manifest, and preview from the saved originals without generation or credits.
Add `--install` to replace this revision's nine WAVs. To rebuild the entire pack,
prepare/install the original batch, revision 1, revision 2 (including its
`finish_sfx.py` step), then revision 3. Earlier batches
alone restore earlier takes. Gameplay uses the bundled files and requires no
network or fal.ai account.

The previous synthesized pack can still be recreated for comparison using
`.scratch/game-sfx/generate_sfx.py`. It writes to `.scratch/game-sfx/synthesized/`
so it cannot overwrite this pack.

## Sound families

- `ui_*`, `select`, `move`: wood taps, seed-shell pops, and paper movement.
- `purchase`: cash register ka-ching; `sell`, `reroll`, `lock`, `unlock`: tactile shop feedback.
- `plant`, `fertilize`, `mutate`, `harvest`, `train`, `compost`, `seal`: soil,
  shovel-and-soil planting, pops, growing bubbles, and egg-shell hatching at harvest.
- `slash`, `heavy_swing`, `charge`, `bow`, `throw`, `horn`: attack and release.
- `hit_slash`, `hit_blunt`, `block`, `ground`, `death`: distinct contact sounds.
- `explosion`, `spore`, `revive`, `acid_rain`: special combat events.
- `great_slash`, `great_swing`, `great_bow`, `great_throw`: oversized attacks/releases.
- `great_hit_slash`, `great_hit_blunt`, `great_block`: heavy contacts and shield blocks.
- `battle_start`, `battle_win`, `run_win`, `run_loss`: clear trumpet fanfares;
  triumphant wins and a descending minor-key loss phrase. Fixed pitch.

Great weapon resources enable `great_weapon_sfx`. The combat profile chooses
their melee and contact sounds; projectiles choose their heavier launch sound and
remember the contact cue at launch. Regular weapons and damage from status effects
retain their ordinary cues. Great Shield uses a blunt bash sound while preserving
its original slashing damage type. Cue gains and real-time spacing keep the mix
readable rather than changing attack timing or combat balance.
An SFX-bus peak limiter caps overlapping bursts at -1 dB; it leaves ordinary
individual cues below the threshold unchanged. The Music bus is separate.
The limiter uses Godot's [AudioEffectHardLimiter](https://docs.godotengine.org/en/stable/classes/class_audioeffecthardlimiter.html).

The [browser review](http://127.0.0.1:8787/) offers all 47 cues and nine A/B
comparisons against their immediately previous versions. It defaults to in-game
levels so the louder explosion is audible, with optional pitch variation and
saved notes. `review.html`, `review-contexts.json` and `build_review.py` in
`.scratch/sfx-revision-1/` build it from Godot captures and the previous review
data; pass `--revision-dir .scratch/sfx-revision-3`. It is a local page and
requires the review server to be running.

Replace individual WAVs at the same paths to change the sound palette while
keeping the existing gameplay hooks. Keep enum entries in `Sfx.Cue` in order:
projectile scenes serialize their selected launch cue by enum value.
