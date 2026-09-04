# Seed Lobber / Shield knockback regression

Run from the repository root with Godot 4.7:

```sh
godot --headless --path . .scratch/seed-lobber-shield-repro/seed_lobber_shield_repro.tscn
```

This diagnostic scene uses the real CombatStage, Shield, Seed Lobber projectile,
AOE damage, and character physics. It pins marching and the launch aim so one
projectile hits the grounded unit from its right. No gameplay scripts are mocked.
Exit 0 means recovery passed; exit 1 means a regression; exit 2 means no hit occurred.

The original failure was low-force knockback that never became airborne:
120 × 0.25 gives horizontal speed 30 and upward speed 15. Gravity cancels the
vertical impulse before movement, so an airborne-history recovery guard never
cleared knockback. The unit slid backward at 30 px/s indefinitely.

Recovery now checks actual floor contact after movement. The default replay
stops after 0.5 px, instead of remaining in knockback for all 240 observed frames
and moving 120 px. The test also checks that airborne knockback is not cleared
prematurely, the unit finishes grounded with zero horizontal velocity, and exactly
one hit occurred.

Append `-- --variant=NAME` for the controls:

- `great_shield`: lower knockback multiplier.
- `boundary_grounded` / `boundary_airborne`: effective force 32 / 33 at 60 Hz.
- `strong_knockback` / `unshielded`: normal airborne knockback and landing.
- `celebration` / `celebration_strong`: both victory-celebration recovery cases.
- `no_knockback`: no knockback state entered.
- `with_ally`: HOLD_LINE remains active.
- `fixed_anchor`: fixed Home independent of flag movement.

Append `-- --ff=2` or `-- --ff=4` to check combat fast-forward.
