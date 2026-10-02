# Guided Run regression checks

Run from the repository root with Godot 4.7:

```sh
godot --headless --editor --path . --quit
godot --headless --path . res://tests/guided_run_test.tscn
godot --headless --path . res://tests/guided_combat_test.tscn
godot --headless --path . res://tests/guided_analytics_test.tscn
```

On macOS, run Godot outside the agent sandbox (see `AGENTS.md`). These are normal scene entry points; do not replace them with `--script --check-only`, which does not establish the same autoload environment.

Run the scenes sequentially. They temporarily exercise saved guided preferences and restore the original `settings.cfg` bytes before exiting. Analytics calls are disabled or captured locally; the existing plugin still initializes during engine startup.

`guided_run_test` covers public mode selection, all scheduled unlocks, late Nursery use, limited offers, lineage/Compost, snapshot restoration, Seal rollback and terminal preferences. `guided_combat_test` uses actual combat and result scenes to exercise repeated defeat, retries, Day 10 continuation and accepting/replaying final victory. It also reports fixed-seed authored-army samples with normal Training Stats, both with and without Mace.

`guided_analytics_test` captures outgoing calls locally and verifies the guided start/exit-only contract, reached-Day reporting, and ordinary gameplay events.

The balance samples use attainable prepared rosters; they do not simulate a player's complete economic Run. Pacing, understanding and formation readability still need playtesting.
