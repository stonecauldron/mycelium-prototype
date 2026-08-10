# 03 — Lineage carries Mutations + Stock prep

**What to build:** When an Adult is composted or dies in battle, the Lineage spore carries that unit’s Mutations along with trainings, mean stats, and Tier — not Fertilizer items. The player can drag Mutations onto a Lineage spore in Stock to prep or replace slots (replace consumes). Planting and harvesting that heir yields Children with those Mutations. Children still do not emit Lineage spores.

**Blocked by:** 02 — Mutations in Shop → Plot → hatch → combat

**Status:** ready-for-human

- [x] Adult compost / battle death Lineage spores snapshot Body and Cap Mutations
- [x] Lineage spores do not carry Fertilizer items (baked stats may still ride mean stats)
- [x] Lineage spores retain parent Tier, trainings, and mean stats as before
- [x] Mutations can be applied/replaced on a Lineage spore in Stock (replace consumes)
- [x] Lineage spore detail shows prepared Mutations
- [x] Planting and harvesting a prepared Lineage spore yields Children with those slots
- [x] Children still do not emit Lineage spores

## Comments

- Implemented: `SporeData` Body/Cap fields + `from_fallen_unit` snapshot; Stock drag prep/replace via `NurseryData.apply_mutation_*_lineage_spore` (shop apply works even when Stock is full); `plant_spore` seeds plot slots; `SporeDetailCard` shows prepared Mutations; Children still gated by `is_adult_stage()`. Check script extended under `.scratch/mutations-body-cap/check_mutations_main.gd`.
