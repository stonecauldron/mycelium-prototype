# Daily reroll pricing

Status: Accepted.

## Requested rules

- Regular paid rerolls start at 2 biomass, then cost 3, 4, 5, and so on.
- Mid-run Seal rerolls start at 10 biomass, then cost 11, 12, 13, and so on.
- Each new Day resets reroll prices to their respective starting prices.
- The Day number no longer changes the starting price or Reroll Increase.
- Only one Seal pick can occur on a given Day. Its existing per-pick reset satisfies the daily pricing rule: each mid-run pick starts at 10 biomass, and further rerolls of that pick cost 11, 12, and so on.

This replaces the Day-scaled pricing decision in [ADR-0012](../../docs/adr/0012-day-scaled-reroll-price.md). That decision deliberately increased later-Day prices alongside the growing Battle reward; the requested change makes the same reroll sequence cost the same on every Day.

## Counter boundaries

The 2-biomass starting price applies to both Nursery Shop and Scout. Shop, Scout, and Seal counters are independent. For example, paying 2 for a Shop reroll leaves the first Scout reroll at 2 and the first Seal reroll at 10.

## Scope of the pricing change

Existing reroll availability and offer rules stay in effect: the opening Seal pick cannot reroll, Elite Day armies cannot be rerolled, and Shop Offer locks remain respected. Only successful paid rerolls increase the applicable counter; automatic daily offer refreshes do not consume a paid reroll. Starting a new Run resets all counters.

## Acceptance examples

- On any Day, three Shop rerolls cost 2, 3, and 4 biomass. The first Scout reroll still costs 2.
- On the next Day, the first Shop and Scout rerolls each cost 2 again.
- Three rerolls of a mid-run Seal pick cost 10, 11, and 12 biomass. The next eligible Seal pick starts at 10 again.
- An unaffordable reroll leaves both biomass and the next price unchanged.
