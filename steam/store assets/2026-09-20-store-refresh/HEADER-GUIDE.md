# Store description headers

Five 1170 × 150 PNGs with transparent outer margins, cream paper ribbons, and the game's Spicy Rice title font. Lettering and capitalization match the supplied headings.

Upload these as description images, place each above its matching paragraph and loop, and use the displayed heading as its alt text. The preview sheet is for review only; upload the five individual PNGs.

| Header / alt text | PNG | Matching loop |
| --- | --- | --- |
| Grow your units | `exports/headers/01-grow-your-units.png` | `exports/loops/01-plant-and-harvest.mp4` |
| Fight the heathen | `exports/headers/02-fight-the-heathen.png` | `exports/loops/04-battle.mp4` |
| Pupate & Train | `exports/headers/03-pupate-and-train.png` | `exports/loops/02-train-and-combine.mp4` |
| Arrange your troop | `exports/headers/04-arrange-your-troop.png` | `exports/loops/03-arrange-your-squad.mp4` |
| Create powerful lineages | `exports/headers/05-create-powerful-lineages.png` | `exports/loops/05-lineage.mp4` |

Edit `scripts/headers.json` and run `python3 scripts/make_headers.py` to rebuild. The font and original paper artwork are retained under `sources/`. Rebuild the full upload archive with `python3 scripts/package.py`.

Steam supports PNG description images and recommends 1170px width for high-DPI displays. [Official guidance](https://partner.steamgames.com/doc/store/page/assets).
