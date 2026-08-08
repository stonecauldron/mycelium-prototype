# Mutations (Body + Cap) replace specialty Spores

Status: ready-for-agent

Glossary: `CONTEXT.md`. Decision record: `docs/adr/0004-mutations-body-cap-not-specialty-spores.md`.

## Problem Statement

Specialty identity is sold as distinct shop Spores that each lock a full Strain (art + effect). Players cannot remix identity onto Lineage spores, the Shop conflates “buy a species” with gardening, and Fertilizers cannot stay cleanly about growth/stats when identity wants the same shelf. Players need a clear way to grow generic troops and optionally stamp Body and Cap identity through the Nursery without specialty spore SKUs.

## Solution

Remove spores from the Shop. Fresh grows are planted by paying biomass on an empty Plot (always Common for now). Identity is a separate item type — **Mutation** — with two slots on a unit/plot/lineage spore: **Body** and **Cap**. Fertilizers remain plot gardening tools and do not carry onto Lineage spores as items. Player unit art is layered Generalist body + cap sprites, tinted by slot (with fixed empty defaults), then multiplied by Tier.

## User Stories

1. As a player, I want to plant a fresh grow by interacting with an empty Plot and paying biomass, so that I do not need a generic Spore in Stock.
2. As a player, I want fresh grows to always be Common for now, so that rarity is not gated on shop spore SKUs.
3. As a player, I want the fresh plant cost and grow days to match the old Common Spore (4 biomass, 2 days) unless other modifiers apply, so that the baseline economy feels familiar.
4. As a player, I want Rotten Thumb to discount the pay-on-plot plant cost, so that the Seal still has a Nursery job after spores leave the Shop.
5. As a player, I want the Shop to stop offering Spores, so that I am not choosing between specialty spores and mutations.
6. As a player, I want the Shop to always show Fertilizer offers and Mutation offers in split rows (2 + 2), so that both economies are visible every reroll.
7. As a player, I want each Mutation shop slot to roll body or cap independently, so that the shop can show two bodies or two caps.
8. As a player, I want every Mutation to cost 3 biomass (fertilizer cost + 1), so that identity is slightly pricier than basic Fertilizers.
9. As a player, I want to buy a Mutation into Stock, so that I can apply it later.
10. As a player, I want to drag a Mutation from Shop or Stock onto a growing Plot, so that the next harvest gains that identity.
11. As a player, I want to drag a Mutation onto a Lineage spore in Stock, so that I can prep or remix heirs before planting.
12. As a player, I want applying a Mutation to a filled slot of the same kind to replace and consume the old Mutation, so that swaps are a real spend.
13. As a player, I want empty Body and Cap slots to be allowed, so that a plain Generalist-like unit is valid.
14. As a player, I want Body mutations to include Mini, Lanky, Fat, Rubber, and Zombie, so that body-led identity lives in one slot.
15. As a player, I want Cap mutations to include Death, Inky, Boom, Wall, Bank, and Brood Empress, so that specialty combat/lifecycle identity lives in the other slot.
16. As a player, I want Fertilizers to still modify growth, hatch stats, and unit-life flags on a Plot, so that gardening tools keep working.
17. As a player, I want Fertilizer Spreader to increase Fertilizer stacks only (not Mutation slots), so that identity stays two slots.
18. As a player, I want harvested Children to receive a clone of the Plot’s Body and Cap Mutations, so that plot identity becomes unit identity.
19. As a player, I want Meiosis/Triploid multi-hatches to each receive the same cloned Mutations, so that yield copies the plant rather than picking one heir.
20. As a player, I want an Adult’s Lineage spore to carry Mutations, weapon-school Trainings, mean stats, and Tier, so that bloodlines keep identity and power.
21. As a player, I want Lineage spores not to carry Fertilizer items, so that growth tools reshape the next grow instead of snowballing forever.
22. As a player, I want a Lineage spore to keep the parent’s Tier, so that rarity still matters after shop tier spores are gone.
23. As a player, I want to plant a Lineage spore from Stock onto a Plot as today, so that heirs still use the Spore planting path.
24. As a player, I want to sell Mutations from Stock back via the shop drop zone like Fertilizers, so that I can recover from bad buys.
25. As a player, I want starter package units to begin with no Mutations, so that the new Shop teaches identity.
26. As a player, I want Mutation cards in Shop/Stock to use the generic fertilizer icon for now, so that the feature is not blocked on new icon art.
27. As a player, I want every player unit to render as layered Generalist body + cap art (child pair while Child, imago pair while Adult), so that Body and Cap can tint independently.
28. As a player, I want a filled Mutation slot to tint its layer with that Mutation’s color, so that identity is readable on the unit.
29. As a player, I want an empty slot to use the fixed default layer color (child cap `#51422D`, child body `#E4C8A2`, imago cap `#472D1C`, imago body `#E4C8A2`), so that incomplete identity still looks intentional.
30. As a player, I want Tier color to multiply both layers, so that rarity still shows on the body.
31. As a player, I want Body mutations such as Mini/Lanky to adjust scale and hurtbox (not the physics body collider), so that silhouette fantasy survives shared meshes.
32. As a player, I want the body layer to own weapon mount and idle animation with the cap following, so that combat presentation stays coherent.
33. As a player, I want Cap mutation combat/lifecycle behavior to still apply in battle (and related hooks), so that Death/Boom/etc. remain meaningful after leaving specialty Spores.
34. As a player, I want Body mutation combat hooks that belong on the body (e.g. Zombie) to still apply, so that moving Zombie to Body does not strip its fantasy.
35. As a player, I want unit detail UI to show Body and Cap Mutations instead of a single Strain package as the identity story, so that I can understand remixable builds.
36. As a player, I want Plot tooltips/detail to show assigned Mutations awaiting harvest, so that I know what will hatch.
37. As a player, I want Lineage spore detail to show prepared Mutations, so that Stock prep is visible before planting.
38. As a player, I want Greenhouse and Favourite Child behavior to remain unchanged relative to growth/hatch, so that existing Seals do not break silently.
39. As a player, I want Compost and battle death of Adults to still emit Lineage spores into Stock (with Mutations), so that the lineage loop from ADR 0003 continues.
40. As a player, I want Children not to emit Lineage spores, so that only Adults continue bloodlines.
41. As a developer-agent, I want Strain treated as legacy for player Nursery identity, so that new work speaks Mutation / Body / Cap per the glossary and ADR 0004.
42. As a player, I want enemy armies to remain on their separate authored catalog, so that player Mutation redesign does not rewrite enemy composition (ADR 0001).

## Implementation Decisions

- Respect ADR 0004 and the glossary terms Mutation, Body mutation, Cap mutation, Fertilizer, Lineage spore, Shop, Stock, Plot, Tier.
- Primary behavioral seam is the Nursery system (data + screen flow it owns): planting, shop offers, stock apply/sell, plot assignment, harvest, lineage emission.
- Introduce Mutation as an item type distinct from Fertilizer and Spore; Body and Cap are the only slots; each holds at most one Mutation or empty.
- Remove specialty and tier spore offers from the Shop. Fresh empty-plot planting spends biomass and starts a Common grow without requiring a Stock Spore. Lineage spores remain plantable Spores in Stock.
- Shop layout: two Fertilizer offer slots and two Mutation offer slots each reroll; each Mutation slot rolls independently from the body/cap pools.
- Mutation biomass cost is flat 3. Mutations use the same drag/apply/sell grammar as Fertilizers where possible, with Lineage spore cards as valid drop targets for prep/replace.
- Replace on a filled slot consumes the previous Mutation (no return to Stock).
- Harvest copies the plot’s Body and Cap onto every Child produced (including multi-hatch yield multipliers). Fertilizer bake behavior at hatch stays; those items are not written onto Lineage spores.
- Lineage creation from an Adult snapshots Mutations plus existing lineage fields (name/generation, trainings, mean stats, tier).
- Starter packages do not grant Mutations.
- Player presentation switches to layered Generalist textures: child body/cap and imago body/cap under the generalist unit art set. Do not compose specialty full-body strain sprites for player units under this design.
- Layer tint pipeline: per-slot mutation tint or the specified empty defaults, then Tier multiply on both layers. Body drives scale, hurtbox, weapon mount, and animation; cap is a following layer. Body mutations must not resize the physics body collider as their silhouette tool.
- Mutation Shop/Stock cards may reuse the generic fertilizer icon temporarily.
- Cap/Body mechanical behaviors migrate from the old specialty StrainEffect / body-led strain packages onto the Mutation definitions; player “one Strain resource package” is no longer the acquisition model.
- Enemy catalog and enemy effects stay out of this Nursery identity rewrite.
- Seals: Rotten Thumb targets pay-on-plot plant cost; Fertilizer Spreader remains Fertilizer-stack only; Greenhouse and Favourite Child keep their current growth/hatch roles unless a conflict forces a tiny adapter.
- Prefer minimal focused diffs; match existing GDScript style. Do not commit binary LFS-quirk noise; do not commit unless asked.

## Testing Decisions

- Good tests assert external Nursery behavior only (costs, offer shape, slot replace/consume, harvest clones, lineage payload, multi-hatch cloning) — not private helpers or scene-tree layout.
- Module under test: Nursery seam (the data API the screen already uses for plant/shop/stock/plot/harvest/lineage).
- Appearance layering/tint is out of automated test scope for this spec unless a pure resolver is extracted later; manual/visual check is enough for art.
- Prior art: this repo has no test framework (no GUT/gdUnit). Do not add a framework in this work unless explicitly requested; if tests are added later, place them against the Nursery seam above.

## Out of Scope

- Reintroducing tiered shop Spores or a plant-time tier picker (explicitly deferred; fresh grows stay Common).
- Stackable multi-cap or multi-body identity beyond the two slots.
- Unique per-mutation body/cap mesh art (tint-on-Generalist layers only).
- New Mutation card icon set.
- Reworking enemy unit art or enemy composition to use Mutations.
- Full Seal redesign beyond Rotten Thumb / Spreader targeting called out above.
- Persist/migrate mid-run saves that assumed specialty spore stock (prototype may reset expectations).
- Adding a test framework.

## Further Notes

- Empty-slot default tints: child cap `#51422D`, child body `#E4C8A2`, imago cap `#472D1C`, imago body `#E4C8A2`.
- Body catalog: Mini, Lanky, Fat, Rubber, Zombie. Cap catalog: Death, Inky, Boom, Wall, Bank, Brood Empress.
- Former specialty full-body appearances can remain in the tree unused by player composition until a cleanup pass.
- Implementation issues, if split later, live under `.scratch/mutations-body-cap/issues/`.
