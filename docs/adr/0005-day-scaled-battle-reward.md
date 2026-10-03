# Day-scaled Battle reward replaces per-kill biomass

Status: The sampled difficulty measurement below is superseded by [ADR 0015](0015-budgeted-enemy-armies.md). The ordinary Run's Day base is capped by the amendment below; the ±10% swing and victory payout remain unchanged. Guided Runs use the introductory allowances described in ADR 0015.

Combat used to grant biomass on each enemy kill from that type's authored `biomass_reward`. That tied income to army size and mid-fight drip, and fought the day curve we already use for composition. We grant a single **Battle reward** on victory instead: base `10 + 5 × (day − 1)` for the upcoming battle day, then a ±10% multiplier from where that army's `difficulty_score` sits between sampled min/max for the same day (nearest int). Scout shows that one total; per-enemy reward fields and kill popups go away. Compost, Bank Cap, seals, hit biomass, and starting biomass (3) stay as they are.

**Considered options:** keep per-kill (rejected — scales with unit count, not day); day base with no difficulty swing (rejected — Scout reroll would not affect payout); difficulty vs day midpoint only (rejected — extremes need a full 0.9…1.1 range).

## Amendment — 2026-10-03

Ordinary Runs cap the Day base at 25 biomass: `min(10 + 5 × (day − 1), 25)`. Days 1–3 retain bases of 10, 15, and 20; Days 4–10 use 25. The difficulty adjustment applies after the cap, giving payouts of 23–28 from Day 4 onward after rounding. This limits late-Run income growth while preserving Scout's reward differences. Guided allowances are unchanged.
