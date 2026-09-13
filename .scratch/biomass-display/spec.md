# Standardise biomass amounts

All six design decisions are settled. Implementation was authorised by the user's subsequent invocation of the implement skill.

## Display contract

- Compact: `[sign when needed]N [icon]`.
- Full: `[sign when needed]N [icon] biomass`.
- Remove `kg` from every player-facing biomass amount and zero padding from the Base and combat HUD balances.

All numerical prices, rewards, balances and economy rules remain unchanged by this presentation work.

## Settled decisions — round 1

- **Q1 — Units:** remove `kg` from every player-facing biomass amount. Numerical values are unchanged. The Biomass glossary definition is now simply the Run's spendable resource.
- **Q2 — Surface mapping:** use fixed choices by UI role, not dynamic omission based on width. Compact `N [icon]` for HUD balances, Shop prices, action buttons, Bank Cap balance chips and floating gains. Full `N [icon] biomass` for descriptions, tooltips, compost outcomes and Day Summary entries, including descriptions on narrow Shop cards.
- **Q3 — Signs:** unsigned balances and prices, `+` on standalone gains including sale proceeds, and `−` on actual losses. A prose verb such as “gain” or “yielded” supplies direction without a redundant sign.

## Settled decisions — round 2

- **Q4 — Special layouts:** enforce number-then-icon order in the HUD and Bank Cap balance as well. Keep the HUD's `BIOMASS` heading above an unpadded `N [icon]` row, replacing its large leading image. Bank Cap uses a horizontal `N [icon]` balance on both Unit cards and Unit details. Other mutation badges retain their existing layouts.
- **Q5 — Icon and colour scope:** use the existing small biomass icon (`assets/base/biomass_small_icon.png`) for every amount, sized to the surrounding text. Retain contextual colours, including green compost gains and gold combat popups. Keep each number and its icon together when text wraps.
- **Q6 — Description clarity:** describe Bank Cap as “Stores 10 [icon] biomass at battle start. Pays out on death.” For Phosphorus Mining, Radioactivity and Rotten Thumb, replace “capped at 1 biomass” with “minimum cost: 1 [icon] biomass”. These are wording corrections to match existing mechanics.

## Representative output

- HUD balance: `BIOMASS` heading, then `3 [icon]`.
- Shop price: `2 [icon]`; Plot action: `Plant: 4 [icon]`.
- Standalone sale proceeds: `SELL +2 [icon]`; Spore sale tooltip: `Sell: +2 [icon] biomass`.
- Scout reward and floating gain: `+10 [icon]`.
- Bank Cap stored balance: `0 [icon]` or `10 [icon]`, without a gain sign on the balance.
- Compost confirmation: `+2 [icon] biomass`.
- Day Summary total: `+10 [icon] biomass`.
- Death report: `…died and yielded 10 [icon] biomass`.
- Golden Mould: `At the start of each day, gain 8 [icon] biomass`.

Amounts above illustrate formatting; actual values continue to come from existing rules.

## Existing behaviour relevant to the design

- Before this interview, the glossary defined Biomass as the Run's spendable resource, “shown in kg”. The glossary has now been updated per Q1; existing game displays still use the old formats.
- HUD balances have four-digit zero padding and a `kg` suffix.
- Prices generally place the number before the icon; Scout rewards and the Training confirmation button place the icon first.
- Bank Cap balances use a number overlaid on an icon.
- Day Summary earnings, compost outcomes and death reports use three different `kg` phrasings.
- Bank Cap, Sickle, Scythe and four Seal descriptions express amounts with the word `biomass` and no inline biomass icon.
- Current Fertilizer effect descriptions contain no biomass amounts; their Shop prices and the Phosphorus Mining Seal description are relevant surfaces.

## Documentation

The glossary now defines Biomass simply as the Run's spendable resource. Keep presentation rules and implementation scope in this specification. Historical economy ADRs record their original decisions; this display change does not retune their prices. This reversible presentation decision does not warrant a new ADR.

## Implementation coverage after design confirmation

- Shared HUD scene plus the Base and combat balance formatters.
- Fertilizer/Mutation Shop price rows, Shop/Scout/Seal reroll controls, Plot planting and unlocking, Squad slot unlocking, and Training confirmation.
- Shop sell overlay and Spore price tooltips. Sale proceeds follow the gain-sign rule even when the label says “Sell”.
- Scout Battle reward preview and floating combat biomass gains.
- Bank Cap balance on both Unit cards and Unit details; other mutation identity displays retain their current behaviour.
- Composting bin tooltip, compost confirmation outcome, Day Summary total and biomass-bearing death reports.
- Bank Cap, Sickle, Scythe and biomass-related Seal descriptions, including owned-Seal tooltips and reused descriptions on other surfaces.
- Shared Fertilizer/Mutation description rendering must support the same convention, although no current Fertilizer effect description contains a biomass amount.

`StatDisplay` already supports inline stat images in rich text and wrapping Shop descriptions, but does not yet recognise biomass. Seal descriptions/tooltips, compost text and Day Summary prose currently use plain labels. These paths all need coverage; editing resource strings alone is insufficient.

## Verification after implementation

- Check zero, ordinary balances, and balances of four or more digits without padding or truncation.
- Check compact and full displays, unsigned prices/balances, signed sale and reward amounts, and prose whose verb already supplies direction.
- Inspect narrow Shop descriptions and tooltips for wrapping, baseline alignment and preserved stat icons/colours.
- Inspect both Base and combat HUDs, Bank Cap on Unit cards/details, and each action-button family.
- Confirm no player-facing biomass amounts retain `kg`, and all existing prices/rewards/balance calculations are unchanged.

## Implementation and verification result

Implemented on 2026-09-13. `BiomassDisplay` owns amount formatting and the shared icon; `StatDisplay` inserts full biomass amounts into both rich text and Shop flow layouts. Existing compact rows retain their scene structure where possible. HUDs and Bank Cap now follow number-then-icon order, with Bank balances retaining their outlined white text for contrast against the Base artwork.

- Godot 4.7 editor import/parse check and headless game boot passed.
- `git diff --check` passed. Production `.gd`, `.tres` and `.tscn` files contain no remaining `kg`, old HUD padding constant, or “capped at 1” wording.
- Captured and inspected production UI instances: HUD balances 0/3/1000/10000, Shop and detail descriptions, selected/unselected Seals, owned-Seal text, Spore sale price, compost tooltip/outcome, Training confirmation, sale overlay, floating gain, Day Summary, Base, Nursery and combat HUD. Amount/icon wrapping and existing stat colours remain intact.
- Standards review: no findings. Spec review: no findings. Review baseline: `9ce8b251efca64a67591c9ee860c32f6cd23b412`.
- No automated test suite is configured. This change used the agreed production-scene visual checks rather than introducing a new test framework.
- The OpenGL preview emits three stat-texture cleanup errors on exit. The identical errors were reproduced using `StatDisplay.white_icon` from the review baseline; they are not introduced by this change. No script errors occurred in the completed preview run.

Reproduce the visual checks with:

```sh
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 1920x1080 --quit-after 2400 .scratch/biomass-display/preview.tscn
```

On local macOS, run Godot outside the agent sandbox as described in `AGENTS.md`. The fixture writes its eleven captures to `/private/tmp/biomass-*.png` and exits; it does not run or validate a complete Battle.
