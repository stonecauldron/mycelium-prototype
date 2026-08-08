# 02 — Mutations in Shop → Plot → hatch → combat

**What to build:** The player can buy Body and Cap Mutations from the Shop, hold them in Stock, sell them back, and apply them to a growing Plot (replace consumes the previous Mutation in that slot). Harvested Children receive clones of the Plot’s Body and Cap (including multi-hatch yields). Mutation combat/lifecycle hooks work in battle. Starters begin with empty slots. Mutation cards may use the generic fertilizer icon. Plot and unit UI show Body/Cap. Shop is 2 Fertilizer + 2 Mutation slots; each Mutation slot rolls body or cap independently; Mutation cost is 3. Fertilizer Spreader stays fertilizers-only.

**Blocked by:** 01 — Pay-on-plot Common grows; spores leave the Shop

**Status:** ready-for-human

- [x] Body catalog (Mini, Lanky, Fat, Rubber, Zombie) and Cap catalog (Death, Inky, Boom, Wall, Bank, Brood Empress) exist as Mutations
- [x] Shop always offers 2 Fertilizer + 2 Mutation slots; Mutation slots roll body/cap independently; Mutation cost is 3
- [x] Mutations can be bought into Stock, sold back via shop drop zone, and dragged from Shop/Stock onto a growing Plot
- [x] Applying a Mutation to a filled slot of the same kind replaces and consumes the old Mutation
- [x] Empty Body and Cap slots are allowed; starter units have none
- [x] Harvest clones plot Mutations onto every Child (including Meiosis/Triploid)
- [x] Cap and Body mutation hooks apply in battle / lifecycle as appropriate
- [x] Plot and unit UI surface Body/Cap; Mutation cards may use the generic fertilizer icon
- [x] Fertilizer Spreader does not add Mutation slots

## Comments

- Implemented `MutationData` + Body/Cap catalogs under `assets/base/nursery/mutations/`; Nursery shop is 2 Fertilizer + 2 Mutation (cost 3); buy/sell/stock/plot apply+replace; harvest clones onto every Child; combat/lifecycle dispatch via `RosterUnitData.call_mutation_effects` / `call_lifecycle_effect`; plot/unit UI show Body/Cap; Mutation cards reuse fertilizer icon. Lineage stock prep is ticket 03; layered art is ticket 04.
