# Bow / shield retreat diagnostic

Current tuning: both sides use 80-pixel Home slot spacing and an 80-pixel
ranged skirmish default in every slot. Retreat and hybrid melee-approach
thresholds use the authored combat distance without a slot deduction; ranged
positioning retains its original stagger. Only active `RETREATING` uses a 24-pixel exit buffer;
finishing an attack and returning Home do not activate that buffer.
The shared movement arrival tolerance is now 12 pixels (previously 4).
The sections below record the earlier tuning and its follow-ups.

Diagnostic scene using the real combat stage, movement, collisions, and attacks.
Seed: 20260905; STR/DEX 5 and CON 99 on all units
so deaths do not end the observation early. The player units use Adult art.

Run from the repository root (outside the agent sandbox on macOS):

```sh
godot --headless --path . --fixed-fps 60 .scratch/bow-shield-retreat-diagnosis/repro.tscn
```

The default fixture is two bows followed by a shield, facing one Solar Sword.
Exit 1 / `FAIL whole_squad_retreats_with_living_shield` means the unwanted
behavior was reproduced: after the enemy gets within 100 pixels of the shield,
every living player unit moves back over 40 pixels in a one-second window.
This is a proximity marker, not a physical-contact assertion. Exit 0 means
the symptom was not observed within the 15-second observation window.

Append `--` followed by diagnostic options:

- `--minimal`: remove the second bow.
- `--no-knockback`: zero both sides' knockback in duplicated runtime profiles.
- `--fixed-anchor`: stop the player's flag once the enemy is within 500 pixels
  of the shield, after the initial march. Units remain active.
- `--short-skirmish`: reduce only bow retreat distance to 48 in runtime profiles.

Use one probe at a time with `--minimal`. These are causal probes, not proposed
gameplay changes. Trace vectors are (slot 0, slot 1, shield); in the minimal
fixture slot 1 is the shield, so the last two values repeat. Diagnostic logs
are confined to this scene. Before the September 5 range tuning, baseline and
minimal fixtures failed. Both pass with player slot spacing 96 and ranged
skirmish distance 96. The optional probes do not modify saved weapon resources.

## Player range tuning evaluation (September 5, 2026; before enemy symmetry)

The original two-bow fixture moved the units backward by approximately
79.5 / 90 / 91.7 pixels over one second before tuning. After tuning, neither
the one-bow nor two-bow fixture issued a bow retreat during the 15-second run.

Run the broader 18-second-per-case combat checks:

```sh
godot --headless --path . --fixed-fps 60 .scratch/bow-shield-retreat-diagnosis/evaluate_tuning.tscn
```

This covers all six ranged weapons behind Shield against three Solar Swords,
bow + Shield against three Solar Cleavers / Durians / Acorn Knights,
bow + Great Shield / Umbrella Shield against three Solar Swords,
and eight modified melee weapons individually against a Solar Sword.

- All six ranged + Shield cases keep firing without sustained squad retreat.
  Bow makes 3 pixels of backward adjustment; Sniper makes 1.5; the others zero.
- Great Shield also avoids sustained retreat; the bow adjusts backward 3 pixels.
- Every modified melee weapon deals damage and performs a melee attack or,
  for Lance, a charge.
- Three stress cases exceed the diagnostic's 40-pixel backward-movement limit:
  Solar Cleavers and Durians knock both player units backward (zero bow kiting
  frames), while Umbrella is knocked behind the bow and exposes it to melee.
  At the first Umbrella-case kite, the bow is 93.5 pixels from its target and
  the shield is 16.2 pixels behind the bow. This case has 184 kiting frames.

The full run reports 16 passes and 3 backward-movement findings. These findings
are not parse errors or evidence that the original untouched shield-line
scenario still fails. Isolate their dependence on knockback with:

```sh
godot --headless --path . --fixed-fps 60 .scratch/bow-shield-retreat-diagnosis/evaluate_tuning.tscn -- --edge-cases --no-knockback
```

All three then pass with zero kiting and zero backward movement. Omit
`--no-knockback` to reproduce the three findings with extra diagnostic output.

The tuning removes the original trigger in these fixtures, but preserves the
rear-unit → flag → Home coupling. The rear slot's normal retreat threshold is
96, and its returning-state threshold is 144. A shield 96 pixels ahead facing
an enemy about 48 pixels further ahead places a lone bow near that boundary,
which explains why tiny backward corrections remain possible. Later ranged
slots reach the existing 48-pixel minimum (96 while returning). Hybrid
throw/melee switching distances remain separately authored; the requested
melee reach edits change regular melee commit ranges to 126 or 174 pixels
(reach minus 18), with Lance retaining its charge behavior.

These deterministic, high-health fixtures assess movement and attack operation,
not win rates, typical run survival, or every possible battle arrangement.

## Symmetrical enemy distances (September 5, 2026)

Both sides now use the single `Troop.HOME_SLOT_SPACING` value of 96 pixels;
the separate 44-pixel enemy spacing was removed. Peashooter and Seed Lobber
inherit the 96-pixel skirmish default. Solar Cleaver, Durian, and Rose Thorn
have 144-pixel melee reach; Acorn Knight has 192-pixel reach. All ten enemies'
melee, skirmish, and projectile distances match their player weapon counterparts.
Rose Thorn retains the same 280-pixel hybrid switching setting as Spear.

Run the enemy combat checks:

```sh
godot --headless --path . --fixed-fps 60 .scratch/bow-shield-retreat-diagnosis/evaluate_tuning.tscn -- --enemy-tuning
```

All six cases pass. Peashooter and Seed Lobber behind Stump continue firing
against three player Swords without sustained retreat; their maximum backward
adjustment over one second is 6 and 7.5 pixels respectively. Solar Cleaver,
Durian, Rose Thorn, and Acorn Knight all perform melee attacks or charges and
deal damage. The original two-bow + Shield reproduction also still passes.
The earlier stress-case measurements above predate this enemy tuning.

## 80-pixel follow-up (September 5, 2026)

Reduced the shared Home slot spacing and both WeaponData / CombatProfile
skirmish defaults from 96 to 80. All ranged weapons and ranged enemies inherit
this default. The one-bow and two-bow Shield regressions both pass, as do all
six `--enemy-tuning` combat checks. Enemy ranged units make small corrections
(maximum 7.5 pixels for Peashooter and 10.5 for Seed Lobber over one second),
with no sustained squad retreat in these fixtures.

## 12-pixel arrival slack (September 5, 2026)

Increased `Unit.HOME_ARRIVE_THRESHOLD` from 4 to 12 pixels on both sides.
This is the shared `_axis_velocity` tolerance, including shield Home-following.
The original two-bow + Shield regression and all six enemy combat checks pass.

## Dedicated retreat state and 24-pixel hysteresis (September 5, 2026)

`RETREATING` now records kiting away from the current target. `RETURNING` remains
for Home/holding movement. Finishing or cancelling an attack enters `READY`;
the next combat decision chooses movement. Target replacement or loss clears
the old retreat state, so a new target must meet the normal entry threshold.

The retreat exit buffer is now 24 pixels, independently of the unchanged
48-pixel minimum personal retreat distance and chase margin. For the current
ranged default, slot 0 enters at <=80 and exits at >=104 pixels; later slots
enter at <=48 and exit at >=72 pixels. The shared 12-pixel movement arrival
tolerance still applies.

Run the focused state regression:

```sh
godot --headless --path . --fixed-fps 60 .scratch/bow-shield-retreat-diagnosis/retreat_state.tscn
```

This uses real combat-stage units and attack/AI callbacks at controlled target
distances. It covers player Bows and enemy Peashooters in slots 0 and 1: shot
completion, cancellation, Home return, retreat entry and the 24-pixel exit,
re-entry, target replacement, target loss, and reacquisition. Before the fix,
36 of 68 checks failed; after the fix, all 68 pass. The original two-bow + Shield
battle regression also passes with no consecutive whole-squad retreat frames.
All six `--enemy-tuning` battle checks pass, including ranged fire, melee attacks,
and lance charges. Neither enemy ranged fixture issues a retreat command.

## Exposed ranged units failing to enter retreat (September 5, 2026)

The dedicated retreat state removed the old post-attack entry buffer, exposing
an existing mismatch between personal retreat distances and enemy stopping
distances. A Solar Sword commits at 78 pixels (96 reach minus 18), while a
ranged unit in slot 1 or later requires a target within 48 pixels to retreat.
The sword can attack without ever meeting that retreat condition. Previously,
finishing a shot put the bow in `RETURNING`, permitting retreat below 96 pixels
in those slots. The new 24-pixel exit buffer does not affect entry.

Run real, unshielded battles, with the same seed/stats as the earlier fixtures:

```sh
godot --headless --path . --fixed-fps 60 .scratch/bow-shield-retreat-diagnosis/exposed_retreat.tscn -- --bow-sword
```

The default broader run (omit `--bow-sword`) also includes Solar Cleavers and
enemy Peashooters versus player Swords, with one or two ranged units per case.
The diagnostic exits 1 when any ranged unit takes melee damage without entering
retreat during the 18-second observation; this is a gameplay finding, not a
parse error. It records actual target distances and phases throughout combat.

- Two Bows versus one Solar Sword: slot 1 takes 15 damage, never enters retreat,
  and its nearest target distance is 76.33 pixels, above its 48-pixel trigger.
- One Bow in slot 0 does retreat, for 44 frames of the 18-second run; its entry
  threshold is 80 pixels. Retreat is therefore reduced, not globally disabled.
- Add `--no-knockback`: slot 1 still never retreats, takes 30 damage, and the
  sword stops at exactly 78 pixels. Knockback is not the cause of this failure.
- The earlier `--uniform-entry` probe gave every ranged slot an effective
  80-pixel entry threshold using runtime-only profiles. Slot 1 then entered
  retreat for 20 frames. This probe was removed once the production fix landed.
- Solar Cleaver can hit from about 123 pixels without activating even slot 0's
  80-pixel retreat trigger. Enemy Peashooters show the same slot-1 issue against
  player Swords.

The focused `retreat_state.tscn` still passes all 68 checks. Those controlled
distance checks verify transitions, but did not verify whether real enemies
would approach closely enough to activate retreat. No production behavior was
changed during this follow-up diagnosis; the probe overrides are scene-local.

## Separate combat thresholds from formation spacing (September 5, 2026)

Retreat and hybrid approach-to-melee now use the full `combat.skirmish_distance`
in every slot. Ranged defaults therefore enter retreat at <=80 pixels and exit
at >=104 pixels on both sides. Spears and Rose Thorns close for melee at 280
pixels regardless of their slot; the other hybrids use their own authored
distances. Ordinary melee return-Home and shield holding behavior are unchanged.

The existing `_preferred_skirmish_distance()` calculation is retained exclusively
for ranged positioning. `_preferred_attack_distance()` and the ranged chase
stop calculation are unchanged. A before/after snapshot of all 14 ranged/hybrid
player and enemy profiles over ten slots matched exactly, including the minimum
positioning distances in late slots. Generate that snapshot with:

```sh
godot --headless --path . --fixed-fps 60 .scratch/bow-shield-retreat-diagnosis/retreat_state.tscn -- --positioning
```

Active retreat must clear its exit distance even when the normal preferred
position is closer. A slot-9 Giant Horn still prefers 96 pixels, but its escape
destination includes enough clearance to reach 104 pixels before it resumes
normal positioning. Without this guard, the shared 12-pixel arrival tolerance
stopped it at 84.5 pixels and left it stuck in `RETREATING`.

Zombie respawn placement now uses its own `_ZOMBIE_RESPAWN_CLEARANCE` of 80
pixels; later formation-spacing changes will no longer move that spawn point.

Validation: all 87 focused retreat/hybrid/late-slot checks pass. The new uniform
threshold and hybrid approach assertions failed on the old slot-dependent code.
The exposed player Bow and enemy Peashooter cases with one and two ranged units
all enter retreat when attacked by swords, with no runtime profile overrides:

```sh
godot --headless --path . --fixed-fps 60 .scratch/bow-shield-retreat-diagnosis/exposed_retreat.tscn -- --sword-only
```

The original two-Bow + Shield battle check also passes. Long-reach melee can
still attack from outside the authored 80-pixel retreat threshold; this change
does not redefine retreat distance according to the opposing weapon's reach.
