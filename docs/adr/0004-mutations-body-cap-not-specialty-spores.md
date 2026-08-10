# Mutations (body + cap) replace specialty spores for player identity

Player specialty identity used to be sold as distinct shop Spores that each locked a full Strain (art + effect). That blocked combining identities with Lineage and conflated species packages with Nursery gardening. We split identity into **Mutations** — typed Body and Cap slots — separate from **Fertilizers**, removed spores from the Shop, and plant fresh Common grows by paying biomass on a Plot. Lineage spores carry Mutations (and trainings / mean stats / tier), not Fertilizer items. Unit art is layered Generalist body + cap sprites tinted by slot (with fixed empty-slot defaults), then multiplied by Tier; Body owns mount/animation and may adjust scale/hurtbox, not the physics body collider.

We rejected stackable “strain-effect fertilizers” (unbounded chips, muddy Fertilizer meaning) and keeping specialty spore SKUs alongside mutations (two acquisition channels). Shop offer rows stay split (Fertilizer vs Mutation); mutation cost is fertilizer cost + 1; Rotten Thumb discounts pay-on-plot planting; Fertilizer Spreader stays fertilizers-only.

## Amendment — capacity 1 (plots only)

Plots (and thus harvested units) currently hold **at most one** Mutation — Body **or** Cap. Mutations apply on empty or planted plots; they are **not** prepared onto spores in Stock. Death spores may still snapshot the parent's mutation; planting merges spore + plot (same slot overwrites, different slots merge) then clamps to one by preferring the spore's mutation. Dual Body+Cap remix and mutation-capacity seals remain deferred. Typed `body_mutation` / `cap_mutation` fields and layered art stay.
