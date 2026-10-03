# Guided Run regression checks

Run from the repository root with Godot 4.7:

```sh
godot --headless --editor --path . --quit
godot --headless --path . res://tests/guided_run_test.tscn
godot --headless --path . res://tests/guided_combat_test.tscn
godot --headless --path . res://tests/guided_analytics_test.tscn
godot --headless --path . res://tests/guided_hints_test.tscn
```

On macOS, run Godot outside the agent sandbox (see `AGENTS.md`). These are normal scene entry points; do not replace them with `--script --check-only`, which does not establish the same autoload environment.

Run the scenes sequentially. They temporarily exercise saved guided preferences and restore the original `settings.cfg` bytes before exiting. Analytics calls are disabled or captured locally; the existing plugin still initializes during engine startup.

`guided_run_test` covers the ten-Day schedule, mode selection, actual Training and expansion purchases, the two-Plot cap, late Nursery use, the full Shop on Day 8 with exactly one guaranteed Quick Growth in its first draw, normal later rolls, Day-7 Compost/lineage, snapshot restoration, the single curated Seal choice and terminal preferences. It also checks the guided daily biomass allowances, including the increased Day-7 and Day-9 grants, full grants alongside savings, unchanged ordinary rewards, and an actual sequence of introductory purchases funded without extra biomass. `guided_combat_test` uses actual combat and result scenes to exercise repeated defeats and retries, Continue-only non-final victories, unlock highlights, and direct Victory after Battle 10 with completion recorded and the next-Run checkbox cleared. It checks the Day-8 Seal marker, guided victory invitation, and unchanged ordinary Nursery and victory text. It also reports fixed-seed authored-army samples with normal Training Stats, both with and without Mace.

`guided_analytics_test` captures outgoing calls locally and verifies the guided start/exit-only contract, reached-Day reporting, and ordinary gameplay events.

`guided_hints_test` checks arrows only on each feature's unlock Day, including Nursery/Quick Growth on Day 5, Squad expansion/Bench/Thorny on Day 6, Shield/Compost on Day 7, Plot expansion/full Shop and the only Seal on Day 8, and Spear on Day 9. It uses actual Training, Plot, Stock and lineage state, skips unaffordable or completed actions, and verifies read-only selection, history across retries, and no arrows after completion. It does not write saved preferences.

The balance samples use attainable prepared rosters; they do not simulate a player's complete economic Run. Pacing, understanding and formation readability still need playtesting.

Run `godot --headless --path . res://tests/nursery_fertilizer_test.tscn` for Nursery Fertilizer regression checks. It verifies that wait-changing Fertilizers apply to empty or growing Plots but reject harvestable Plots through direct, Stock, Shop, and drag eligibility paths without consuming items or Biomass. It also checks natural, accelerated, and legacy READY state, and preserves eligibility for other Fertilizers and Fungicide.
