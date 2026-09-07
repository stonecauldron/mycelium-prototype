# Lance close-range attack regression

Fixed September 7, 2026: Lance and Acorn Knight use ordinary melee when the
target is close, including when it closes during charge windup. Distant targets
retain charge behavior.

The original fixture uses the real combat stage, Unit AI, physics, hitboxes,
and damage callbacks. It places one
Adult Lance 60 pixels from one Solar Sword, seeds RNG with 20260905, and gives
both STR/DEX 5 and CON 99 to keep them alive through ten seconds of combat.

Run outside the agent sandbox on macOS:

```sh
godot --headless --path . --fixed-fps 60 .scratch/lance-melee-diagnosis/repro.tscn
```

Exit 1 / `FAIL windup_without_damage` reproduces the reported symptom. Before
the fix, repeated baseline runs returned four charge windups, zero rushing
frames, zero ordinary melee frames, zero damage dealt, and 25 damage taken.
The diagnostic asserts actual enemy HP loss as well as attacker damage credit.
After the fix it passes with 48 melee frames, 24 damage dealt, and 10 taken.

## Original cause

`Unit._process_combat()` unconditionally called `_start_lance_windup()` for
`LANCE_CHARGE` before checking the target distance. There was no close-range
ordinary melee fallback, despite the Lance's `MELEE_LUNGE` attack style and
192-pixel melee reach.

The windup lasts the authored attack interval: two seconds for Lance.
`take_damage()` ends either charge phase on an incoming hit, including during
windup. `_end_lance_charge()` calls `_finish_attack()`, which also assigns the
full two-second attack cooldown. The damage hitbox is only enabled when
`_begin_lance_rush()` is reached. Solar Sword's authored interval is 1.5 seconds;
in this close duel it repeatedly interrupts the windup before any rush begins.

## Causal probes before the fix

Append `--` and one option to the command above. Changes apply only to this
diagnostic's runtime instances. The results below record the original diagnosis.

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

## Fix and regression coverage

Attack selection now falls through to the existing ordinary melee path when a
lance target is within `_get_melee_engage_range()` (currently 174 pixels).
Windup also checks this distance: when the target closes, it clears the pending
charge phase/timer and starts a melee strike while retaining `ATTACKING`.
The normal attack cooldown begins after the melee strike. It does not incur
the cancelled-charge cooldown before attacking.

Run the focused regression:

```sh
godot --headless --path . --fixed-fps 60 .scratch/lance-melee-diagnosis/fallback.tscn
```

It uses real stage units with fixed body positions, real AI selection and attack
callbacks, and live tweens, physics overlaps, and damage. For both player Lance
and enemy Acorn Knight it covers a close target, a target behind the attacker,
the exact melee boundary, a target closing during windup, a distant target
allowing the rush to begin, and a shield stopping the charge with reduced damage.
It asserts one actual hit and damage credit, the cooldown after melee, and
hitbox cleanup. Rushing continues after an unshielded hit.

Before the fix, 48 of 96 checks failed. After the fix, all 96 pass. The original
active duel also passes, as do all 87 checks in
`.scratch/bow-shield-retreat-diagnosis/retreat_state.tscn`.
