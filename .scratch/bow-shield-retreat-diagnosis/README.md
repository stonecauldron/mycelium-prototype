# Bow / shield retreat diagnostic

Current tuning: both sides use 80-pixel Home slot spacing and an 80-pixel
ranged skirmish default. The existing 48-pixel returning buffer still applies.
The shared movement arrival tolerance is now 12 pixels (previously 4).
The sections below record the earlier 96-pixel tuning and its follow-up.

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
