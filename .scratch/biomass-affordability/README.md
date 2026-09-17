# Biomass affordability regression check

The stale Plant state reproduced after a paid Shop reroll and spending biomass
elsewhere. Ordinary Shop item purchases already refreshed Plant in this checkout.
`BiomassData` did not emit changes, so other controls also depended on incomplete
caller-specific refreshes. The initial full-Base check had 35 failing assertions.

`BiomassData.amount` now emits the Resource `changed` signal when its value changes.
Plant, plot and squad unlocks, Shop offers and reroll, Scout and Seal rerolls,
training confirmation, and the Base balance display subscribe to lightweight
refreshes. Plant's hint reads the current balance instead of a cached boolean.
Existing refreshes still handle transaction results and reroll price changes.

Run from the project root (outside the agent sandbox on macOS):

```sh
godot --headless --path . .scratch/biomass-affordability/runtime_check.tscn
```

The check instantiates the real Base and dialogs, invokes Shop purchase/reroll,
Scout/Seal reroll and Plant handlers, and changes the balance without refreshing
screens. It covers gains, spending, refunds, assignments, reset, no-op mutations,
increasing reroll prices, elite restrictions, the opening Seal pick, and growing
plots. Shop reroll remains interactive for rejection feedback when unaffordable.

Verified on Godot 4.7: 133 assertions pass, ending with
`BIOMASS AFFORDABILITY CHECK: 0 failures` and exit status 0.
