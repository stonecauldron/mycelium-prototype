# Budgeted procedural enemy armies

Status: Implemented; initial costs and budget ranges are ready for playtesting.

## Behavior

Each Day defines an Army-budget range. Initial generation rolls an allocation from that range, chooses an Army pattern and eligible distinct enemy types, then finds the largest affordable headcount matching the rounded pattern shares. Costs are authored combat estimates; they are independent of instance stat rolls and the player's squad.

- One-trick pony: 90/10 headcount shares across up to two types.
- Hybrid: 70/30 across up to two types.
- Generalist: 33/33/34 across up to three types.
- If fewer types are eligible, normalize the remaining shares. Small armies may round the minority type away.
- The allocation is an upper bound. Leftover points are allowed; no filler types or extra validation/scoring system is added.
- Keep the existing composition weights, shuffle within Range classes, and Ranged → Mid → Melee Home order.
- Initial armies and advance elite previews remain deterministic from the Run seed and Day. Scout and combat share the cached enemy army; individual STR/DEX/CON still roll ±1 at combat launch.

## Type eligibility

- Day 1: Solar Sword only.
- Days 2–3: Solar Sword, Rose Thorn, and Peashooter.
- Day 4: all four Regular types, adding Stump.
- Elite Day 5: Strong enemies only, excluding Durian, with at most one distinct type. Durian unlocks on Day 6.
- Elite Day 10: Strong enemies only, with up to three distinct types.
- Days 6–9: Regular types plus at most two distinct Strong types. Zero Strong types is allowed; the restriction limits distinct types, not individual enemies.

Selecting two Strong types on a mixed Day removes the other Strong types from the remaining picks. A Strong type may dominate a pattern, with its higher cost reducing army size. Elite budgets create the difficulty spike; their Strong-only pool establishes the army's character.

## Current enemy costs

Edit `composition_cost`, `is_strong`, and `min_day` on each `assets/units/enemies/<type>/<type>_unit.tres`. Existing stats, combat profiles, visuals, and selection weights are unchanged. These costs are starting estimates informed by current combat traits, not simulated balance results.

| Enemy type | Category | Unlock Day | Cost | Starting rationale |
| --- | --- | ---: | ---: | --- |
| Solar Sword | Regular | 1 | 6 | Weak basic frontliner; baseline cost |
| Rose Thorn | Regular | 2 | 10 | Ranged throw with melee follow-up |
| Peashooter | Regular | 2 | 10 | Sustained ranged threat |
| Stump | Regular | 4 | 12 | Slashing resistance and charge blocking, offset by low offense |
| Solar Cleaver | Strong | 5 | 24 | Heavy area melee attack |
| Durian | Strong | 6 | 30 | Area blunt damage bypasses shield-style slashing resistance |
| Log | Strong | 5 | 24 | Heavy slashing resistance and charge blocking, with very low offense |
| Canopy | Strong | 5 | 22 | Projectile interception and charge blocking; limited offense |
| Seed Lobber | Strong | 5 | 24 | Ranged area explosions |
| Acorn Knight | Strong | 5 | 26 | Charge pressure, checked by charge blockers |

Original Strong costs were restored on 2026-09-23; Seed Lobber, Durian, and Acorn Knight were individually retuned on 2026-09-24.

Canopy intercepts colliding shots; Lobber-style delayed radius explosions bypass its interception. Enemy costs should be adjusted from playtesting alongside Day budgets.

## Current Day-budget ranges

Edit `_DAY_BUDGET_RANGES` in `assets/base/troop_selection/enemy_composer.gd`; `budget_range_for_day()` is also used by reward calculation. Values are inclusive integer allocations. Day 6 returns to mixed armies and resumes the budget ramp after the first elite battle.

| Day | Minimum | Maximum |
| ---: | ---: | ---: |
| 1 | 12 | 18 |
| 2 | 22 | 30 |
| 3 | 28 | 40 |
| 4 | 40 | 56 |
| 5 — elite | 82 | 111 |
| 6 | 90 | 120 |
| 7 | 108 | 144 |
| 8 | 132 | 176 |
| 9 | 168 | 216 |
| 10 — elite | 240 | 312 |

Day 5's bounds were reduced from 108–144 to 97–130 on 2026-09-23, then by another 15% on 2026-09-24 in response to player losses, rounding each bound to the nearest whole point: 82–111. Its mean allocation is now 96.5 rather than 113.5 points (a 14.98% reduction), or 23.41% below the original 126-point mean. The effect on player win rate still needs playtesting.

The minimum is a minimum **allocation**, not a minimum amount that must be spent. Rounding can produce an army whose actual cost is below it. Day 1's allocations can buy two or three Swords; with uniform integer allocation, the three-Sword army occurs only at 18 points.

## Scout and Battle rewards

Scout keeps its existing price progression (2, 3, 4… biomass, reset daily) and is available on every non-elite Day, including Day 1. Rerolls generate eight candidate armies with varied budget allocations, including both ends of the Day range, and exclude the current type-count composition. A shuffle alone is not a new army; including the endpoints ensures Day 1 can reroll between two and three Swords.

Keep the existing easier/harder bias, now measured by actual Enemy cost against the midpoint of the authored Day range. At or above the midpoint, cheaper candidate armies receive more weight; below it, more expensive armies receive more weight. The bias is a preference, not an absolute direction guarantee. If no distinct candidate exists, the generator retains the current army.

Battle reward remains `round((10 + 5 × (day − 1)) × lerp(0.9, 1.1, t))`, granted on victory. `t = clamp((actual_army_cost − day_minimum) / (day_maximum − day_minimum), 0, 1)`; a flat range uses `t = 0.5`. Unspent budget earns no reward, and reward does not depend on Run seed or individual stat rolls. A cost below the Day minimum gets the minimum multiplier.

The sampled difficulty bounds and unused authored-override hook have been removed. See [ADR 0015](../../docs/adr/0015-budgeted-enemy-armies.md) for the trade-off and the amendment to ADR 0005.

## Verification

Run the actual Godot scene harness from the repository root:

```sh
godot --headless --path . --quit-after 120 .scratch/budgeted-enemy-generation/check_enemy_generation.tscn
```

On local macOS, run outside the agent sandbox as required by `AGENTS.md`.

Passed on 2026-09-13 with Godot 4.7: **138,694 assertions, zero failures**. Coverage includes 128 Run seeds for every Day, deterministic repeats, individually checked budget allocations, type eligibility, mixed-Day armies with zero, one, or two distinct Strong types, affordable pattern fitting, reroll bias and actual composition changes, and reward bounds independent of stats or Run seed. Integration checks instantiate Scout, exercise its paid Day-1 reroll and elite preview, build the actual enemy roster, transfer it through BattleLaunch, and compare Scout's reward against combat's cached-army and roster-fallback calculations.

These checks establish generation and integration correctness. Battle difficulty and matchup balance remain playtesting work.
