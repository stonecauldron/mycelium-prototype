# 01 — Pay-on-plot Common grows; spores leave the Shop

**What to build:** The player plants a fresh Common grow by interacting with an empty Plot and paying biomass (baseline 4 / 2 days). Spores no longer appear in the Shop; offers are Fertilizers only for this slice (four Fertilizer slots). Rotten Thumb discounts the pay-on-plot plant cost. Lineage spores remain plantable from Stock. Existing Fertilizer gardening, Greenhouse, and Favourite Child keep working. Specialty identity is unavailable until the next ticket.

**Blocked by:** None — can start immediately.

**Status:** ready-for-human

- [x] Empty Plot interaction starts a Common grow after paying biomass (no Stock Spore required)
- [x] Fresh plant cost and days match old Common Spore baseline unless other modifiers apply
- [x] Rotten Thumb discounts pay-on-plot plant cost (not legacy spore-shop pricing)
- [x] Shop offers no Spores; reroll fills Fertilizer-only slots
- [x] Lineage spores can still be planted from Stock onto Plots
- [x] Fertilizer apply/growth/hatch bake, Greenhouse, and Favourite Child still behave as before this change

## Comments

- Implemented: `GameState.try_plant_fresh_common` + `SealModifiers.fresh_plant_cost` (Rotten Thumb); Nursery shop generates Fertilizer-only offers and purges legacy Spore SKUs; empty Plot click pays to plant; Stock lineage plant path unchanged.
