# Trailer cut list — revision 8

| Timeline | Source | Source start | Duration | Treatment |
| --- | --- | --- | --- | --- |
| 0.00–1.00s | battle_a.mov | 6.50s | 1.00s |  crop [1280, 720, 420, 300] |
| 1.00–2.00s | battle_b.mov | 3.00s | 1.00s |  |
| 2.00–3.00s | battle_a.mov | 7.50s | 1.00s |  crop [1120, 630, 430, 300] |
| 3.00–4.00s | battle_elite.mov | 5.00s | 1.00s |  crop [1440, 810, 360, 270] |
| 4.00–5.50s | nursery.mov | 0.90s | 1.50s | grow crop [1536, 864, 0, 190] |
| 5.50–6.50s | nursery.mov | 3.45s | 1.00s | two-days crop [1536, 864, 0, 190] |
| 6.50–9.00s | nursery.mov | 4.50s | 2.50s |  crop [1536, 864, 0, 120] |
| 9.00–10.75s | training.mov | 1.45s | 1.75s | train crop [1440, 810, 0, 90] |
| 10.75–13.00s | training.mov | 3.85s | 2.25s |  crop [1536, 864, 192, 120] |
| 13.00–14.00s | training.mov | 6.15s | 1.00s |  crop [1536, 864, 192, 120] |
| 14.00–15.50s | formation.mov | 2.00s | 1.50s |  crop [1728, 972, 0, 80] |
| 15.50–17.00s | formation.mov | 5.50s | 1.50s |  crop [1728, 972, 0, 80] |
| 17.00–18.50s | battle_a.mov | 2.50s | 1.50s | fight |
| 18.50–19.50s | battle_a.mov | 6.20s | 1.00s |  crop [1280, 720, 400, 300] |
| 19.50–20.50s | battle_b.mov | 5.20s | 1.00s |  crop [1280, 720, 580, 300] |
| 20.50–21.50s | battle_a.mov | 7.00s | 1.00s |  crop [1120, 630, 430, 300] |
| 21.50–22.50s | battle_elite.mov | 7.00s | 1.00s |  |
| 22.50–23.00s | battle_elite.mov | 13.45s | 0.50s |  crop [1280, 720, 420, 300] |
| 23.00–24.00s | battle_b.mov | 9.00s | 1.00s |  crop [1440, 810, 340, 270] |
| 24.00–25.00s | battle_elite.mov | 10.00s | 1.00s |  crop [1280, 720, 500, 300] |
| 25.00–26.00s | battle_a.mov | 13.50s | 1.00s |  crop [1280, 720, 600, 300] |
| 26.00–27.00s | battle_b.mov | 12.00s | 1.00s |  crop [1280, 720, 500, 300] |
| 27.00–32.00s | end-card.png | — | 5.00s | Blurred capsule background, main capsule, “Fungus Vult!”, Steam logo, Fredoka wishlist CTA |

Chapter transitions overlap extra source handles; the final timeline remains exactly 32 seconds. Music begins at 8 seconds in the existing Battle track, with a smooth half-sine fade from timeline 29.0–31.8 seconds and a 0.2-second quiet tail. The picture fades during the final 0.2 seconds. Crops are `[width, height, x, y]` in a logical 1920×1080 frame; the renderer scales coordinates to the 2560×1440 lossless source. Paper captions sit 48px from the left and 28px from the bottom.

Training uses a Sword Child, Franklin II, raised from an actual lineage Spore. Dragging him into the Sword Cocoon opens the real Child → Adult / Sword → Great Sword preview. The final shot includes the confirmation at source 6.983s and ends at 7.15s, with a 0.1-second transition handle. No Day is advanced and no emerged Unit is shown. Both trailers use the same three source ranges; portrait crops are in `scripts/portrait-edit.json`.

The standalone Training MP4/GIF lasts 6.5 seconds: source 0.65–3.20s establishes the Child and drag, then 3.20–7.15s shows the preview and confirmation. It has no Day-jump caption or post-training result.

## Description loop revisions

These are standalone store-description loops and are not included in the trailer. They use paper captions below the gameplay image. Both are 10 seconds; frame-accurate source ranges and crop rectangles are in `scripts/edit.json`.

| Loop timeline | Gardening (`gardening.mov`) | Lineage (`lineage_sword.mov`) |
| --- | --- | --- |
| Opening | 0–1.30s: PLANT | 0–2.40s: close-up of the lone Sword Adult’s real death and spore effect |
| Second step | 1.30–3.60s: FERTILIZE, Reinforced Chitin drag | 2.40–3.80s: named lineage spores in Stock |
| Third step | 3.60–5.90s: MUTATE, Inky Cap drag | 3.80–5.90s: drag the same spore onto the Plot |
| Growth edit | 5.90–6.60s: 2 DAYS LATER | 5.90–6.50s: 1 DAY LATER |
| Harvest | 6.60–7.33s: harvest click | 6.50–7.23s: harvest click |
| Result | 7.33–10.00s: close-up of the mutated Child | 7.23–10.00s: close-up of Lamarck II and inherited Sword |
