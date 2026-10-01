# Biomass reward verification

Run from the project root with Godot outside the agent sandbox:

```sh
godot --headless --editor --path . --import --quit
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --max-fps 60 res://.scratch/biomass-reward/verify.tscn -- --visual
```

The focused fixture reuses the existing real Base/unit setup from `.scratch/unit-emergence/runtime_check.gd`. It exercises:

- Day Summary rewards of 3 and 60 (two numeric 20 + 40 entries), plus zero. The initial counter shows the pre-award balance; the label falls, counts from 0 to the award and grows. Larger rewards emit more sprites, which travel upward into the counter. Arrival geometry is sampled when each sprite arrives, accounting for the counter's pulse. The retained final award and actual balance are checked independently of the animation.
- Continue always advances immediately on its first activation, including during the pending startup or active reward, with mouse, keyboard Enter and touch plus mouse emulation. Other Summary clicks finish the reward and consume the gesture while leaving the Summary open; a subsequent Continue advances. Background/title/right-click paths preserve the final award and exact committed counter, hide particles and stop prior drop/feed sounds; the completion cue may finish once. Scene exit and resize still cancel safely, with one static award retained after resize.
- Actual Child/Adult Compost confirmation and an Adult with 30 stored Bank biomass. Credits are 6, 8 and 38 respectively, with authoritative removal and the existing zero/one-spore bin release preserved. Repeated confirmation spends/removes only once.
- Compost pause, tab departure, resize and scene exit. Pending cosmetic credit never mutates currency. An authoritative Finesse purchase costing 2 biomass during a pending gain of 6 immediately displays the correct balance of 5, without a negative or stale replay.
- Owned sound routing through the SFX bus and disposal after completion/cancellation. Audio is verified programmatically; no subjective listening audition is claimed.

`--visual` saves captures under `/tmp/biomass-reward-*.png`. The fixture is scoped to reward presentation and these integration paths, not a full gameplay suite.

Initial integration baseline, before the faster/click-to-finish follow-up: **143 checks passed, 0 failures** (`/tmp/biomass-reward-runtime.log`), with clean editor import (`/tmp/biomass-reward-import.log`). No script or parse errors occurred; known renderer shutdown texture/RID warnings remain. Awards of 3 and 60 emit 5 and 20 sprites respectively; Compost awards of 6, 8 and 38 emit 7, 8 and 16. The reward label reaches 1.3× scale, and sampled particle arrivals match the live counter icon within 0.00013 logical pixels.

Representative captures: `/tmp/biomass-reward-summary-60-flight.png`, `/tmp/biomass-reward-summary-60-complete.png`, and `/tmp/biomass-reward-compost-bank-flight.png`.

Godot LSP reports empty diagnostics for the reward presenter, BiomassChip, Day Summary and feed, TroopSelectionScreen, Sfx, Audio, and this fixture (`/tmp/biomass-reward-diagnostics.jsonl`). One fixture parameter was renamed after the runtime pass to remove a shadowing warning; behavior is unchanged. Workspace scanning also reports the pre-existing unrelated `.scratch/day-scaled-reroll/check_reroll_price.gd` reference to removed `reroll_increase()`, which was left untouched. The verification editor and game were stopped afterward.

The follow-up counter-position check passed **25 checks, 0 failures** (`/tmp/biomass-summary-position-check.log`; temporary runner `/tmp/biomass-summary-position-check.tscn`). Summary resting bounds exactly match Base for displayed Days 2, 3 and 10 with debug mode off/on: size 176×125 at Y10, X302 for Days 2/3 or X318 for Day10; debug adds 210px. The recap title begins 30px below the counter. A reward of 60 successfully flies up-left to the new target and finishes at the actual total of 67. Updated evidence: `/tmp/biomass-reward-summary-left-flight.png`, `/tmp/biomass-reward-summary-left-complete.png`, and `/tmp/biomass-reward-summary-left-debug-day10.png`. Earlier summary captures show the superseded upper-right position.

For the faster presentation and Summary input checks only (also one Child Compost completion):

```sh
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --max-fps 60 res://.scratch/biomass-reward/verify.tscn -- --visual --summary-only
```

The faster-presentation follow-up, before the later Continue behavior correction, passed **140 checks, 0 failures** (`/tmp/biomass-summary-click.log`): natural rewards of 3 and 60, pending and active skip paths, keyboard Continue, exact totals, owned audio cleanup, exit/resize and shared Child Compost. Nominal animation timing is now approximately 1.4–1.8 seconds plus any intentional start delay, about 44–46% shorter; the captured low/high cases took 1.91/2.10 seconds of wall time including screenshot work. Particle counts and final credit remain unchanged.

A separate emulated-touch check caught a paired-event advance bug. After the production gesture guard was fixed, that focused check passed **13 checks, 0 failures** (`/tmp/biomass-summary-touch-trace.log`), including the actual emulated mouse press → touch press → mouse release → touch release order. A final normal mouse Continue check passed **13 checks, 0 failures** (`/tmp/biomass-summary-mouse-check.log`). The reusable fixture now includes touch too; the earlier 140-check run did not yet include it. No script or parse errors occurred, and Godot was stopped after verification. Known renderer shutdown warnings remain.

The earlier `/tmp/biomass-reward-click-finished.png` capture shows the superseded Continue behavior. Current background-click completion is captured at `/tmp/biomass-reward-background-finished.png`, with the retained +20 award and exact balance of 27 while the Summary remains open.

The completion sound now reuses `purchase.wav` (0.748 seconds) at −8 dB with fixed pitch. A narrow native smoke check passed **33 checks, 0 failures** (`/tmp/biomass-ka-ching-check.log`; temporary runner `/tmp/biomass-ka-ching-check.tscn`). Natural non-retained effects finish visually after about 0.467 seconds of the cue, then retain the player until its audio-finished signal; early and mid-completion skips preserve one voice without replaying it. Retained Summary labels survive the sound's completion. Players and non-retained presenters free afterward, totals remain exact, and no script/parse errors occurred. This was a programmatic stream/routing/lifecycle check, not a subjective listening audition or a full gameplay rerun. The main fixture's post-finish sound wait now derives from the current stream duration so the longer tail is not mistaken for a leak.


The corrected Continue behavior has its own narrow command:

```sh
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --max-fps 60 res://.scratch/biomass-reward/verify.tscn -- --visual --continue-only
```

Latest run: **37 checks, 0 failures** (`/tmp/biomass-continue-first-click.log`). Native first-click Continue advances immediately from pending and active rewards, as do keyboard Enter and touch with mouse emulation. A background click finishes the award and stays; the next Continue advances. Every path preserves the exact committed total and frees owned presenters/sounds. Only these five scenarios ran; natural reward, Compost and audio suites were not repeated. No script or parse errors occurred; known renderer shutdown warnings remain, and Godot was stopped.
