# Base Undo stops at rerolls and Battles

Every successful Base action can be undone within the current visit, including Training, Compost, harvests, and Seal or starter choices. Any successful Shop, Scout, or Seal reroll clears earlier history: allowing older snapshots past that boundary would restore spent Biomass or discarded offers and effectively undo the reroll. Battle launch, leaving the Base, and Run reset also discard history.

An action restores its complete model state in place because Compost and other actions can affect several units, plots, Stock, and Biomass together. Keep the same Seal offers and reroll price when undoing a choice, and keep starter and harvest outcomes deterministic when repeating an undone action, so Undo cannot serve as a free reroll.

Undo emits the opposite Biomass resource flow for events sent by the undone action, retaining each event's item type and item ID. This keeps net resource totals aligned with restored state without introducing new analytics identifiers. Events suppressed by debug mode or unavailable analytics are never recorded for reversal.
