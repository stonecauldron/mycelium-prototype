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

`guided_run_test` covers public mode selection, all scheduled unlocks, actual Training and expansion purchases, the guided two-Plot cap, late Nursery use, the transition to full Shop offers/locks/rerolls, lineage/Compost, snapshot restoration, curated/full-pool Seal rollback and terminal preferences. `guided_combat_test` uses actual combat and result scenes to exercise repeated defeat and retries, Continue-only victory summaries, next-Day unlock highlights and feed consumption, Day 10 continuation, and final victory. It checks that defeats and no-unlock/final Days omit highlights and that ordinary Runs retain their Nursery message. It also reports fixed-seed authored-army samples with normal Training Stats, both with and without Mace.

`guided_analytics_test` captures outgoing calls locally and verifies the guided start/exit-only contract, reached-Day reporting, and ordinary gameplay events.

`guided_hints_test` checks arrows only on each feature's unlock Day, with none from Day 12 onward, including pending Seals and empty Squads. It uses actual Training, Plot, Stock and lineage state, skips unaffordable or completed actions, and verifies read-only selection and presentation history across retries. It does not write saved preferences.

The balance samples use attainable prepared rosters; they do not simulate a player's complete economic Run. Pacing, understanding and formation readability still need playtesting.
