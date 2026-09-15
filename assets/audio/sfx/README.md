# Mycelium sound pack

40 original synthesized effects: 44.1 kHz, mono, 16-bit PCM WAV, 55 ms–1.5 s.
All clips have tapered ends and approximately −3.1 dBFS peak headroom before
the quieter per-cue gains in `../sfx.gd`.

## Sources

Created specifically for this project using the Python standard library.
No recordings, downloaded samples, or third-party audio are incorporated.
The source is [generate_sfx.py](../../../.scratch/game-sfx/generate_sfx.py).
Its random generator is seeded and independent of gameplay randomness.

From the repository root:

```sh
python3 .scratch/game-sfx/generate_sfx.py
```

This rebuilds the WAVs and writes a sequential listening preview plus a timing,
peak, and RMS report in `.scratch/game-sfx/`. The preview presents clips louder
than their in-game mix to make auditioning quiet UI sounds easier.

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
