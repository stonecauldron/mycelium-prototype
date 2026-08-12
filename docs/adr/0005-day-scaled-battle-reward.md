# Day-scaled Battle reward replaces per-kill biomass

Combat used to grant biomass on each enemy kill from that type's authored `biomass_reward`. That tied income to army size and mid-fight drip, and fought the day curve we already use for composition. We grant a single **Battle reward** on victory instead: base `10 + 5 × (day − 1)` for the upcoming battle day, then a ±10% multiplier from where that army's `difficulty_score` sits between sampled min/max for the same day (nearest int). Scout shows that one total; per-enemy reward fields and kill popups go away. Compost, Bank Cap, seals, hit biomass, and starting biomass (3) stay as they are.

**Considered options:** keep per-kill (rejected — scales with unit count, not day); day base with no difficulty swing (rejected — Scout reroll would not affect payout); difficulty vs day midpoint only (rejected — extremes need a full 0.9…1.1 range).
