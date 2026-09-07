# Lance close-range attack diagnosis

Investigation only; no production gameplay changes. The fixture uses the real
combat stage, Unit AI, physics, hitboxes, and damage callbacks. It places one
Adult Lance 60 pixels from one Solar Sword, seeds RNG with 20260905, and gives
both STR/DEX 5 and CON 99 to keep them alive through ten seconds of combat.

Run outside the agent sandbox on macOS:

```sh
godot --headless --path . --fixed-fps 60 .scratch/lance-melee-diagnosis/repro.tscn
```

Exit 1 / `FAIL windup_without_damage` reproduces the reported symptom. Two
baseline runs returned the same result: four charge windups, zero rushing
frames, zero ordinary melee frames, zero damage dealt, and 25 damage taken.
The diagnostic asserts actual enemy HP loss as well as attacker damage credit.

## Cause

`Unit._process_combat()` unconditionally calls `_start_lance_windup()` for
`LANCE_CHARGE` before checking the target distance. There is no close-range
ordinary melee fallback, despite the Lance's `MELEE_LUNGE` attack style and
192-pixel melee reach.

The windup lasts the authored attack interval: two seconds for Lance.
`take_damage()` ends either charge phase on an incoming hit, including during
windup. `_end_lance_charge()` calls `_finish_attack()`, which also assigns the
full two-second attack cooldown. The damage hitbox is only enabled when
`_begin_lance_rush()` is reached. Solar Sword's authored interval is 1.5 seconds;
in this close duel it repeatedly interrupts the windup before any rush begins.

## Causal probes

Append `--` and one option to the command above. Changes apply only to this
diagnostic's runtime instances.

- `--trace`: logs charge state, remaining windup, and hitbox activity at incoming
  hits. The first hit arrived with 1.933 seconds left and the hitbox inactive.
  Later interrupted windups had 1.633 and 0.350 seconds left.
- `--no-knockback`: disables only enemy knockback. Still fails with four
  windups, zero rushes, and zero damage dealt (30 taken). Displacement is not
  required to reproduce the failure.
- `--passive-enemy`: disables enemy physics/AI. Passes: two windups, 235 rush
  frames, and 12 damage dealt. The close target can be hit when windup completes.
- `--melee-stance`: uses the roster's supported stance override to select
  `PRESS_FORWARD` for the Lance. Passes: zero windups, 48 melee frames, and
  24 damage dealt against the active enemy. The existing melee hitbox and damage
  path work; ordinary melee is simply never selected by lance engagement AI.

These probes distinguish the cause; their damage totals are not balance or DPS
measurements. The passive target's motion differs, so the melee-stance probe is
the stronger confirmation that melee can connect against an active close foe.

## Proposed correction

Select the existing ordinary melee attack when a lance target is already
within `_get_melee_engage_range()` (currently 174 pixels), retaining charge
behavior for targets farther away. Also consider switching a pending windup
to melee when the enemy closes during that windup, so a newly close target
does not leave the lance waiting for an interruptible charge.

The reproduction is retained as a failing regression candidate for that change.
Acorn Knight uses the same lance engagement branch, so a shared correction would
also affect it; this fixture directly tests the player Lance only.
