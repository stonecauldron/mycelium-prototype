# First spore growth

The Nursery unlocks empty after the first battle. The first successful planting
of each run takes at most one day before modifiers, whether planted from stock
or bought on an empty plot. Greenhouse reduces that to zero days; prepared
Fertilizers then apply in their normal order. Planting still costs the usual
biomass when buying a fresh Common Spore.

Failed planting attempts do not consume the bonus. Later plantings use their
normal growth times, including after harvesting or destroying the first grow.
Resetting the run restores the bonus. Shared Spore resources remain unchanged.

Verification: run `check_first_spore.tscn` with Godot headless, plus the existing
`.scratch/remaining-time-fertilizers/check_remaining_time.tscn` regression harness.
