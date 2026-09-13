# Unique items within a Shop roll

Status: Implemented.

## Intent

Prevent duplicate items among offers generated in the same Shop roll when enough distinct items are available in the selected pool. Retained locked offers are outside that group, so the visible Shop may contain duplicates across rolls. If the selected pool has no unused item, allow duplicates to keep its slots filled and preserve the Mutation category odds.

## Settled decisions

- Uniqueness applies to both Fertilizer and Mutation offers.
- A duplicate means the exact same catalog item. Sharing a category is allowed: two different Body mutations or two different Cap mutations may appear together.
- Only newly generated offers participate in duplicate prevention. Locked offers are retained and do not exclude their item from new offers.
- Apply the rule on initial fill, paid rerolls, and daily refreshes.
- Each roll starts fresh. Previous appearances, purchases, and items already held in Stock do not exclude an item.
- Preserve the existing 50/50 Body/Cap choice for each new Mutation, then choose uniformly among unused items in that category when available. Two different Body mutations or two different Cap mutations remain possible.
- If the selected pool has no unused item, choose uniformly from that full pool, allowing a duplicate rather than leaving a slot empty. For Mutations, preserve the rolled Body or Cap category even when the other category still has unused items.

## Selection rule

For each generation batch, start with no selected items. For a new Fertilizer offer, draw uniformly from Fertilizers not yet selected in this batch. For a new Mutation offer, choose Body or Cap with equal probability, then draw uniformly from items not yet selected in that category. Record each generated item's catalog identity for the rest of this batch.

If the selected pool has no unused item, draw from the complete selected pool instead. Retained offers, including locks, are never added to this batch's exclusions. Discard the exclusions after the batch. Choose from finite candidate lists so pool exhaustion cannot cause an unbounded retry loop.

The authored pools are required to contain valid items. The duplicate fallback handles exhaustion of unused candidates, not missing or broken catalog assets.

## Current behavior and scope

- The Shop has two Fertilizer slots and two Mutation slots.
- The catalog contains 17 Fertilizers, four Body mutations, and seven Cap mutations. Shop items have no rolled rarity or stat variants.
- Fertilizers currently draw uniformly. Each Mutation currently chooses Body or Cap with equal probability, then an item uniformly within that category.
- Buying an offer clears its slot; it stays empty until the next reroll. Reopening the Nursery does not refill purchased offers.
- Locks survive paid rerolls and daily refreshes. Existing duplicate locks remain valid under the chosen roll boundary.
- This feature concerns offer selection. Offer counts, prices, reroll pricing, purchases, Stock, and lock controls retain their existing behavior.

Implementation entry points: `assets/base/nursery/nursery_data.gd` owns the catalog and offer generation; `assets/base/shop/shop_inventory.gd` owns initial fill, reroll iteration, and locks. Nursery normalization can also replace legacy or wrong-category offers; replacements generated together must use the same uniqueness boundary.

## Acceptance examples

- With the current catalog, an initial roll cannot contain two copies of the same Fertilizer or two copies of the same Mutation.
- A roll may contain two different Body mutations or two different Cap mutations.
- Locking Fat and rerolling the other Mutation slot may produce another Fat.
- Two locked copies of Fat remain untouched by rerolls.
- With both Fertilizer offers unlocked and at least two distinct Fertilizers in the catalog, their newly rolled items must differ even when Mutation offers are locked.
- An item purchased on the previous roll, or already held in Stock, may appear again.
- Clearing a purchased offer does not immediately generate a replacement.
- If a future Fertilizer catalog contains only one item, both unlocked Fertilizer slots offer that item rather than leaving one empty.
- If a future Body catalog contains only Fat and both new Mutation slots roll Body, both offer Fat even when unused Cap items remain.

## Verification

- Check initial generation, paid rerolls, daily refreshes, partially locked rolls, and fully locked rolls against the acceptance examples.
- Check candidate exhaustion with a reduced pool and verify that generation completes with filled offers in the selected category.
- Verify that Mutation category selection retains its 50/50 choice and that same-category pairs remain possible.
- Use the project's existing validation approach; adding a test framework is outside this feature.

## Confirmation

The user confirmed the complete design, then authorized implementation with the implement skill.

## Implementation and checks

`NurseryData` tracks selected catalog paths in a fresh list for each initial fill or reroll, shared with any normalization replacements in the same operation. Item generation filters the chosen pool against that list and falls back to the full chosen pool on exhaustion. `ShopInventory` retains its existing lock and purchase behavior.

The standalone check scene exercises the Nursery interface without introducing a test framework:

```sh
godot --headless --path . .scratch/unique-shop-rolls/check_shop_rolls.tscn --quit-after 300
```

On macOS, run Godot outside the agent sandbox as described in `AGENTS.md`. A successful run prints `shop_rolls_check` with zero failures; reaching the frame limit without that result is not a pass.

The initial-fill and reroll regression checks each reproduced duplicate offers before their respective fixes. The expanded scene covers initial fill, rerolls, every lock position, duplicate and fully locked offers, purchases, Stock and appearance history, new Runs, daily refreshes, legacy normalization, category odds, and exhausted pools. Pool exhaustion is exercised by filling the selected pool within one generation batch before requesting another offer.

Validation on Godot 4.7: the Shop scene passed 15,433 assertions with zero failures; the existing Fungicide and Remaining Time check scenes passed; editor startup and script checks reported no errors. Independent standards and spec reviews found no actionable issues.

## Documentation

The glossary defines **Shop roll** in `CONTEXT.md`. No ADR is needed for this local, readily reversible selection rule; this specification records its behavior and trade-offs.
