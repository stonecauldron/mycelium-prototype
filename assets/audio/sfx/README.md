# Mycelium sound pack

40 effects generated with **ElevenLabs Sound Effects V2** through fal.ai:
44.1 kHz, mono, 16-bit PCM WAV, 55 ms–1.4 s. Source WAVs have tapered ends and
at least 3.1 dB of peak headroom. Godot additionally normalizes all 40 clips
during import (`edit/normalize=true`); per-cue gains in `../sfx.gd` shape the
in-game mix after import.

## Sources

Generated on 2026-09-15 using `fal-ai/elevenlabs/sound-effects/v2`. Three takes
were generated for each cue, with prompts for playful organic one-shot sounds.
The 120 original MP3s, prompts, request IDs, selected takes, and source hashes
are retained in [the authoring folder](../../../.scratch/elevenlabs-sfx/).
Requested audio totals 92.4 seconds; estimated generation cost was $0.1848 at
$0.002/second. This is an estimate, not an account billing statement.

Preparation removes low rumble, trims quiet padding, adds short fades, and
adjusts level within a peak ceiling. Selection favors complete events with
quiet tails; it does not assess artistic quality. Use the sequential
[listening preview](../../../.scratch/elevenlabs-sfx/preview.wav) for subjective
review. Its cue order and timestamps are in `manifest.json`; the preview omits
Godot's import normalization and the game's per-cue gains and pitch variation.

From the repository root:

```sh
python3 .scratch/elevenlabs-sfx/process_sfx.py --prepare
```

Requires Python 3 and `ffmpeg`. This rebuilds all prepared WAVs, the selection
manifest, and preview from the saved originals without generation or credits.
Add `--install` to replace the game's WAVs with the selected takes. Normal
gameplay uses the bundled files and requires no network or fal.ai account.

The previous synthesized pack can still be recreated for comparison using
`.scratch/game-sfx/generate_sfx.py`. It writes to `.scratch/game-sfx/synthesized/`
so it cannot overwrite this pack.

## Sound families

- `ui_*`, `select`, `move`: wood taps, seed-shell pops, and paper movement.
- `purchase`, `sell`, `reroll`, `lock`, `unlock`: small tactile shop feedback.
- `plant`, `fertilize`, `mutate`, `harvest`, `train`, `compost`, `seal`: soil,
  squishy pops, growing bubbles, and brief warm chimes.
- `slash`, `heavy_swing`, `charge`, `bow`, `throw`, `horn`: attack and release.
- `hit_slash`, `hit_blunt`, `block`, `ground`, `death`: distinct contact sounds.
- `explosion`, `spore`, `revive`, `acid_rain`: special combat events.
- `battle_start`, `battle_win`, `run_win`, `run_loss`: short outcome stingers.

Replace individual WAVs at the same paths to change the sound palette while
keeping the existing gameplay hooks. Keep enum entries in `Sfx.Cue` in order:
projectile scenes serialize their selected launch cue by enum value.
