# GameAnalytics event map for Run, Day, Biomass, and intent

We send a small manual set on top of automatic sessions: two Progression trees, Biomass Resource events, and scene-qualified intent Design events. Names are a dashboard contract — do not rename without accepting a break in history.

**Progression.** `run` and `day` are separate progression01 values. Run: start on New Run, complete on Victory, fail on Game Over, score = days won (`current_day` at outcome). Day: p02 = `1`…`10`, p03 = `normal` | `elite`; start the first time that Day’s Base is shown (Day 1 after Starter package, later Days when Day Summary returns to Base); complete/fail from the Battle; score = Biomass on hand after the Battle. Closing the app is abandon (start with no complete/fail), not fail.

**Resource.** Currency `Biomass`. item_type is the action kind (`Start`, `Battle`, `Shop`, `Nursery`, `Scout`, `Seal`, `Training`, `Compost`, `Stock`, `Troop`). item_id is an authored slug (Mutation/Fertilizer filename stem, Seal `id`, weapon school) or a fallback (`Grant`, `Reward`, `Hit`, `Reroll`, `Unlock`, `Plant`, `Adult`, `Child`). No Unit display names, no spaces. Hit biomass is one source at Battle end. Squad-slot purchases use `Troop` / `Unlock`.

**Design.** `intent:wishlist:{title|victory|gameover}`, `intent:feedback:{victory|gameover}`, `intent:title:{victory|gameover}`, `intent:quit:{title|base|combat|victory|gameover}`. New Run is Run start, not a Design event.

**Out of scope for v1.** Consent prompt (see ADR-0008), Error events, Performance/FPS, choice Design events (Seal/Starter as their own events — catalog still appears on Resource item_id). No manual events while `debug_mode_active` or in the editor. Custom dimension01 = `web` | `desktop`.

**Considered options:** one nested Progression tree (rejected — GA funnels by progression01); Day start = Start Combat (rejected — that is a Battle funnel); Resource item_id = Unit names (rejected — cardinality and illegal spaces); window-close = fail (rejected — mixes wipe with walk-away).
