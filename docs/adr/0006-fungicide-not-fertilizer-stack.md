# Fungicide Extra nutrition does not occupy the Fertilizer stack

Fungicide stays a Fertilizer in the Shop, but applying it kills the current grow and leaves **Extra nutrition** on the Plot for the next harvest. That leftover is not a Fertilizer stack occupant: the next Spore can still receive Fertilizers up to current stack (base 1, Fertilizer Spreader 2). Sequential kills add +4 all stats each time with no cap. Empty-plot Fertilizer apply stays allowed after a kill.

While the Plot is empty, a Fungicide chip shows Extra nutrition (so the leftover is visible with no Spore tooltip). Once a Spore is planted, that chip goes away and Extra nutrition shows in the planted-Spore tooltip; Fertilizer capacity chips stay for the stack only.

**Considered options:** count Fungicide toward the stack (rejected — blocked the next grow's gardening); no Extra nutrition chip at all (rejected — empty dirt after a kill had no signal); a chip that stays after planting (rejected — planted tooltips already include the leftover).
