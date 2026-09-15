# Mycelium sound pack

47 effects generated with **ElevenLabs Sound Effects V2** through fal.ai:
44.1 kHz, mono, 16-bit PCM WAV, 55 ms–2.83 s. Source WAVs have tapered ends and
at least 3.1 dB of peak headroom. Godot additionally normalizes all 47 clips
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

Preparation removes low rumble, trims quiet padding, adds short fades, and
adjusts level within a peak ceiling. Selection favors complete events with
quiet tails; it does not assess artistic quality. Use the revision's sequential
[listening preview](../../../.scratch/sfx-revision-1/preview.wav) for subjective
review. Its cue order and timestamps are in `manifest.json`; the preview omits
Godot's import normalization and the game's per-cue gains and pitch variation.

From the repository root:

```sh
python3 .scratch/elevenlabs-sfx/process_sfx.py --source-dir .scratch/sfx-revision-1 --prepare
```

Requires Python 3 and `ffmpeg`. This rebuilds all prepared WAVs, the selection
manifest, and preview from the saved originals without generation or credits.
Add `--install` to replace only this revision's twenty WAVs with the selected
takes. To rebuild the entire current pack, prepare/install the original batch
first, then this revision; installing the original batch alone restores old takes.
Normal
gameplay uses the bundled files and requires no network or fal.ai account.

The previous synthesized pack can still be recreated for comparison using
`.scratch/game-sfx/generate_sfx.py`. It writes to `.scratch/game-sfx/synthesized/`
so it cannot overwrite this pack.

## Sound families

- `ui_*`, `select`, `move`: wood taps, seed-shell pops, and paper movement.
- `purchase`: cash register ka-ching; `sell`, `reroll`, `lock`, `unlock`: tactile shop feedback.
- `plant`, `fertilize`, `mutate`, `harvest`, `train`, `compost`, `seal`: soil,
  shovel-and-soil planting, pops, growing bubbles, and a forceful treasure reveal.
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

The [browser review](http://127.0.0.1:8787/) offers all 47 cues, twenty A/B
comparisons, game/review levels, optional pitch variation and saved notes.
`review.html`, `review-contexts.json` and `build_review.py` in the revision folder
build it from Godot captures and the previous review data. It is a local page and
requires the review server to be running.

Replace individual WAVs at the same paths to change the sound palette while
keeping the existing gameplay hooks. Keep enum entries in `Sfx.Cue` in order:
projectile scenes serialize their selected launch cue by enum value.
