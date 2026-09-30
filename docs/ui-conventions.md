# UI conventions

Use the vocabulary in [CONTEXT.md](../CONTEXT.md). Presentation previews describe an action; authoritative game rules still decide whether it can execute. See [expected action rejections](adr/0014-explain-expected-action-rejections.md).

In Training comparisons, emphasize nonzero changes with larger result Attack/HP icons and numerals (130% size), 24px signed changes, and 24px text with proportionally enlarged icons for changed STR/DEX/CON rows. Unchanged values retain their normal size. Reset the emphasis when a refreshed preview no longer changes a value.

Fit Training portraits using painted sprite bounds, excluding transparent image padding. Both sides share a fitting multiplier and idle animation phase so changing Weapons does not change an Adult's apparent body size. Preserve authored Child-to-Adult proportions, center the bodies above their combat chips, and keep both held Weapons inside their portrait areas when the dialog resizes.

Training comparisons and Unit detail cards share the same weapon equation: two paper Training slots in their stored order, separated by `+`, then `=` and the resulting Weapon icon. Label unfilled slots `Empty`. The comparison's before side uses the current Unit; its after side uses the preview Unit, including replaced Trainings. Highlight each result slot whose displayed Training changes with blue-bordered paper; unchanged slots, the before side, and Unit detail cards keep green borders. Keep Weapon tags below the equation and the result Weapon details available on hover in the comparison.

In Training comparisons, keep Weapon tags' rounded shape and tint their fill with the light gain/loss palette: green for added tags on the result side, red for removed tags on the before side. Changed range or scaling shows the old tag in red and the new tag in green. Enlarge changed tags with 20px text (normally 16px), proportionally larger icons and padding. Shared tags keep their neutral appearance and normal size. Compare the tag's gameplay meaning, including scaling Stats, rather than its position or caption.

## Elite Battle previews

Hovering the chapter's elite skull temporarily previews that Elite Day in Scout. Clicking the skull pins the preview so the player can move onto enemy portraits and inspect their tooltips. Keep the selected skull highlighted while the actual upcoming-day marker stays in place. A paper **Back to Next Battle** button replaces Scout's reroll control while pinned; clicking the selected skull again also returns to the upcoming army.

Previewing never changes the cached upcoming enemy army, reroll cost, biomass, or the Battle that Start Battle launches. Returning restores that army and its reward, with normal reroll availability. When the Elite Day is already next, show the actual upcoming army without a redundant Back control. Leaving the War Chamber or refreshing it for a new Day clears the pinned preview and releases offscreen keyboard focus.

## Biomass hover previews

The Base biomass counter normally shows the actual balance. Hovering an action that changes biomass enlarges its paper chip and shows the projected balance: **current balance + signed change**. A small cream paper tab shows the signed change. Leaving the action restores the actual balance and normal chip size. Hovering never spends, grants, reserves, or refunds biomass.

For example, with 3 biomass, a cost of 8 previews a balance of **−5** and a change of **−8**. Do not clamp the projection to zero or hide it just because the action is unaffordable. A negative projection is hypothetical; the existing affordability check still prevents the purchase.

| Change | Presentation |
| --- | --- |
| Gain | Green, with a `+` sign on the change. |
| Loss | Red, with a `−` sign on the change. |
| Zero | Neutral result; omit the change tab. |

Use the same gain/loss palette as Training through `StatDisplay.change_color`: gain `Color(0.12, 0.45, 0.18, 1)` and loss `Color(0.7, 0.15, 0.12, 1)`. Biomass result numerals on green paper use the light variants (gain lightened by 0.65, loss by 0.45). Outlined Attack/HP numerals in Training use stronger variants (gain lightened by 0.35, loss by 0.2). Signed changes use the base ink colors on cream paper. Signs carry meaning independently of color. Color reflects the action's change, not whether the resulting balance is above or below zero.

### Action coverage

- Preview current costs for Shop purchases, paid rerolls, fresh planting, Plot/Squad unlocks, and Evolve/Train confirmation.
- Preview Compost's complete direct biomass payout, including the unit's Bank balance, and Stock sale value. Do not substitute a generic stage payout for a known unit's outcome.
- Drag targets preview the action for the current dragged item or unit: School training, Compost, Stock sales, and Shop purchases dropped into Stock or onto a Plot. Applying an already owned Stock item does not purchase it again.
- Stock sales accept drops and preview biomass only over the visible Sell button's paper area, including its hover scale. The surrounding Shop panel and offers are not sale targets.
- Start Battle previews only the upcoming army's **Battle reward**, labeled **“On victory”**. It is conditional income, not an immediate grant or a forecast of all biomass effects during battle. Scout's future Elite Day previews do not change this action's projection. See [Battle rewards](adr/0005-day-scaled-battle-reward.md) and [army budgets](adr/0015-budgeted-enemy-armies.md).

### Integration and lifetime

Bind the actionable Control with `BiomassPreview.bind(control, delta_callable, optional_context_string)`. Resolve prices and outcomes from current authoritative data in the callable, including reroll increases and Seal modifiers. Return `null` when the action or drag is inapplicable; an unaffordable but otherwise applicable action still has a cost preview. Child controls for free actions, such as Shop locks, must not inherit a purchase preview.

The counter resolves the hovered Control and its ancestors each frame. It refreshes when the balance, action, price, or drag payload changes, and restores when the source is hidden, freed, exited, or no longer applicable. Keep the preview input-ignoring so it cannot steal hover or block the action. A preview must not alter action validation, confirmation requirements, or transaction behavior.
