# Auto Shrooms — Steam gameplay media

Produced September 20, 2026 from the current game. Revision 8 replaces Training with a Sword Child → Great Sword preview ending at confirmation, in both trailers and the standalone loop. Both end cards now use the same blurred capsule-art background recipe. The original 32-second pacing and quick Plant & Harvest sequence remain. The expanded gardening and dedicated Sword lineage loops remain separate store-description assets. The five-second wishlist end card is retained. The upload files are in `exports/`; raw captures, graphics, audio, and editable scripts are retained here. Nothing has been uploaded or published to Steam.

## Deliverables

| Asset | Location | Format |
| --- | --- | --- |
| 32-second trailer | `exports/trailer/auto-shrooms-trailer-32s.mp4` | 1920 × 1080, 60 fps, H.264/AAC, BT.709 |
| Lossless finished master | `sources/masters/auto-shrooms-trailer-32s-lossless.mov` | 1920 × 1080, 60 fps, RGB PNG/PCM |
| Portrait social trailer | `exports/social/auto-shrooms-reel-32s-1080x1920.mp4` | 1080 × 1920, 9:16, 60 fps, H.264/AAC |
| Social requirements and guide | [SOCIAL-REEL.md](SOCIAL-REEL.md) | Official sources, layout, rebuild instructions |
| Trailer poster | `exports/trailer/poster-1920x1080.jpg` | Actual end-card frame, 1920 × 1080 |
| Five description header images | `exports/headers/` | 1170 × 150 transparent PNGs; cream paper and game title font |
| Five description loops | `exports/loops/` | 1170px-wide MP4s at 30 fps; optimized GIF counterparts |
| Six screenshots | `exports/screenshots/` | 1920 × 1080 JPGs and PNG alternatives |
| Copy, alt text, placement | [STORE-COPY.md](STORE-COPY.md) | English, ready to paste |
| Readable edit timeline | [CUT-LIST.md](CUT-LIST.md) | Timecodes, source takes, and crops |
| Verification results | [validation.json](validation.json) | Export properties and capture-roster checks |

The loops last 10 seconds (Plant → Fertilize → Mutate → Harvest), 6.5 seconds (Train & Combine), 7.8 seconds (Arrange Your Squad), 8 seconds (Battle), and 10 seconds (Lineage). The battle loop uses a wide crop to retain the army while removing the HUD. Gardening and lineage use close framing with paper step labels in a footer, clear of gameplay controls; their MP4 canvases are 1170 × 658. GIFs use reduced resolution/frame rate/color counts to keep loading costs reasonable. Prefer the MP4s on Steam; do not insert both variants in the same location.

## Creative cut

The trailer opens immediately with combat, shows growing and harvesting from 4–9 seconds, Training from 9–14, Formation changes from 14–17, and a battle montage from 17–27. The last five seconds show a blurred capsule-art background behind the September 10 main capsule, “Fungus Vult!”, the official Steam logo, and “Wishlist on Steam” in Fredoka SemiBold. Action and Day-jump captions use dark ink on cream cut-paper ribbons at the bottom left, clear of the relevant controls. The music fades smoothly from 29.0–31.8 seconds, followed by a 0.2-second quiet tail. There are 23 source shots, with cuts on the Battle track's approximately 120 BPM rhythm and short transitions between chapters.

The main gameplay Squad starts with **3 Children and 7 Adults**, **4 Melee / 3 Mid / 3 Ranged**, and a **Great Shield** in the foremost slot. **Great Sword** and **Great Horn** Units receive clear footage. The roster includes Inky, Boom, Thorny, and Rubber Mutations. The trailer includes the Boom Child's real death explosion at approximately 22.5 seconds. **No Mortar Units appear in this package's captures.**

All gameplay comes from production Godot scenes. Setup uses the actual planting, harvest, lineage, and Training methods to prepare representative Units. Recorded UI actions are actual clicks and drags. Day waits are compressed with explicit captions. Battle movement, attacks, deaths, and effects proceed normally at 1×. Battles resolve through normal combat rules; the dedicated lineage cast was selected to show a natural Sword death and surviving ranged support.

## Screenshot mapping

| Delivered order | Subject | Earlier screenshot reference |
| --- | --- | --- |
| 01 | Active battle | Old `4.png` |
| 02 | Battle approach | Old `1.png` |
| 03 | Developed War Chamber | Old `2.png` |
| 04 | Nursery | Old `3.png` |
| 05 | Day summary | Old `5.png`; now an actual Day 7 victory summary |
| 06 | Child → Adult, Sword → Great Sword Training preview | New subject |

All six are new game captures. Screenshot 06 is extracted from frame 270 (4.5s) of the lossless Sword Child Training take, with the full comparison dialog visible before confirmation. Screenshot exports are resized only; no marketing overlays or synthesized gameplay were added.

## Editable sources

- `sources/takes/*.mov`: lossless RGB PNG-in-MOV recordings at native 2560 × 1440 / 60 fps, with isolated PCM game SFX.
- `sources/takes/*.quality.json`: SHA-256 verification that every decoded source pixel matches its uncompressed capture.
- `sources/masters/auto-shrooms-trailer-32s-lossless.mov`: lossless 1080p60 finished trailer with PCM audio.
- `sources/legacy-mjpeg/`: superseded first-pass AVI recordings, retained only for comparison; not used by the edit.
- `sources/takes/*.json`: recorded action times, army seeds, and complete casting/formation manifests.
- `sources/stills/`: original viewport PNGs at 2560 × 1440.
- `sources/audio/battle_bgm.mp3`: the project's existing Battle music, credited in-game to Andres D. Bubenhofer.
- `sources/graphics/`: retained capsule, official Steam SVG, original paper UI artwork, rendered captions, and the composed end card.
- `sources/fonts/`: fonts already used by the game.
- `scripts/edit.json`: editable source ranges, crops, timing, music offset, and chapter transitions.
- `scripts/capture.gd`: scene setup, real UI interaction, roster assertions, and screenshots.
- `scripts/render.py`: FFmpeg editing, mixing, loop exports, GIF optimization, and screenshot exports.
- `scripts/make_graphics.py`: regenerates paper captions and the capsule end card from retained assets. The supplied Fredoka SemiBold is a 600-weight static instance of the game’s variable font.
- `scripts/validate.py`: checks roster requirements, media specifications, and full MP4 decoding.
- `work/`: intermediate chapter movies and segment renders; these can be rebuilt.

## Rebuild

Git includes the finished exports, copy, scripts, capture manifests, validation reports, and supporting stills, graphics, fonts, and audio. Raw recordings, lossless masters, legacy footage, temporary renders, previews and their archives, ZIP bundles, logs, and Python caches are ignored and retained locally. A fresh clone does not include the footage needed to rerender the videos; restore the local recordings or capture new takes first. ZIP bundles can be regenerated from the committed exports.

From this package directory:

```sh
python3 scripts/make_graphics.py
python3 scripts/render.py
python3 scripts/validate.py
python3 scripts/package.py
```

To revise a particular chapter, edit `scripts/edit.json` and run, for example:

```sh
python3 scripts/render.py trailer --chapters 05-battle
```

To capture new source footage from the repository, run `python3 scripts/capture_all.py`. Godot must run outside the agent sandbox on this Mac. It uses native OpenGL rendering and Movie Maker for fixed 60 fps timing and audio. Picture pixels are read directly from the GPU into a temporary uncompressed RGB file and encoded losslessly into MOV; the temporary Movie Maker JPEG video is discarded. The temporary files are deleted only after a full decoded-pixel SHA-256 match. Each take can temporarily require around 20 GB of free space. Still screenshots are retained from the first production pass, except screenshot 06, which is regenerated from the current lossless Training take using `screenshot_sources` in the edit recipe. The script can also take individual scenario names: `nursery`, `training`, `formation`, `battle_a`, `battle_b`, `battle_elite`, `summary`, `gardening`, or `lineage_sword`.

Required tools: Godot 4.7, FFmpeg/FFprobe, ImageMagick, and Python 3. No new media was purchased, and no additional plugin was required. FontTools was used once to instantiate Fredoka SemiBold; rebuilding uses the retained font file and does not require FontTools.

## Capture provenance and verification

Game revision: `48acd4448eb7aaa5a46257762045e4e3918ab623`. Captured with Godot `4.7.stable.official.5b4e0cb0f` on Apple M3 using Compatibility/OpenGL. This production added capture/editing artifacts; no gameplay source was changed.

All click/drag, casting, role-order, shield, and weapon assertions passed during capture. Native Godot logs retain the pre-existing OpenGL texture-cleanup diagnostics at process exit; those occur after completed recordings. Source logs and event manifests are retained for inspection.

Source MOVs and all editing intermediates use lossless RGB PNG encoding. Final H.264 delivery files are encoded once from these masters (trailer CRF 14, loops CRF 16, slow preset), with explicit BT.709 range conversion. Final exports are checked for duration, resolution, frame rate, codecs, color metadata, and complete decoding. Fourteen roster checks passed, including the dedicated three-Unit lineage cast. The package now contains five GIFs; exact file sizes are recorded in `validation.json`. Trailer audio measures −16.1 LUFS integrated loudness and −1.0 dBFS true peak. Visual review uses the source interaction frames, final trailer timeline, screenshot contact sheet, and composited GIF frames. See `validation.json` for machine-checked results.

`auto-shrooms-steam-upload.zip` contains the delivery files and store-copy guide. Editable sources remain in this full package directory.

## Revision 2 asset references

The cream ribbon is `assets/asset_packs/Cila - Paper UI stylized/label/label 10.png`, from the same paper UI family referenced by `assets/themes/paper/`. The capsule is `steam/store assets/2026-09-10/upload/store/store_capsule_main_en.png`. The Steam mark is the [official storefront SVG](https://store.fastly.steamstatic.com/public/shared/images/header/logo_steam.svg?t=962016), retained unmodified with its registered mark; the end card includes the attribution from [Steam’s branding guidelines](https://partner.steamgames.com/doc/marketing/branding).

Revision 2 validation passed for all seven source MOVs, all forty editing MOVs, the lossless finished master, five delivery MP4s, four GIFs, and the existing six screenshot pairs. Source MOVs total 14.8 GB. See the [source quality comparison](preview/source-quality-comparison.png) and [caption/end-card review](preview/revision-2-review.jpg).

## Revision 3 ending

The end card now holds for five seconds (27–32s). Music uses a 2.8-second half-sine fade (29.0–31.8s), followed by a 0.2-second quiet tail. The complete 32-second / 1920-frame export and lossless master passed validation. The prior 30-second trailer is retained in `preview/revision-2-trailer-30s.mp4`, with its master in `sources/masters/archive/`.

## Revision 4 description loops

`01-plant-and-harvest` now shows **Plant → Fertilize → Mutate → Harvest**. Real UI drags apply Reinforced Chitin and Inky Cap to the same growing Plot; the resulting Child carries both. The two-Day growth edit is labeled.

`05-lineage` follows the same **Lamarck → Lamarck’s spores → Lamarck II** chain. A lone Sword Adult, Lamarck, fights ahead of two Bow Units (one Child and one Adult) in a dedicated Battle. He dies naturally and the supporters win; the emitted spore is retained through the actual summary and Base transition, dragged onto a Plot, and harvested after a labeled one-Day edit. Capture assertions verify the incremented Generation, inherited Sword Training, and Rubber Body. Death and the descendant’s name are shown close up.

Both additions have 10-second MP4 and GIF versions. Their exact clips, crops, and step captions are editable in `scripts/edit.json`; rebuild individually with `python3 scripts/render.py gardening-loop lineage-loop`. Original lossless captures and action manifests are `sources/takes/gardening.*` and `sources/takes/lineage_sword.*`.

Revision 4 verification passed: nine pixel-exact 1440p60 source MOVs, 52 lossless editing intermediates, 15 roster checks, six MP4s, five GIFs, and six screenshot pairs. Gardening GIF: 1.44 MB; lineage GIF: 4.29 MB with 128 colors. Both new loops are exactly 10 seconds. See [gardening steps](preview/gardening-steps.png) and [lineage steps](preview/lineage-steps.png).

## Revision 5 — dedicated Sword lineage battle

The lineage loop now uses a three-versus-three encounter: one player Sword Adult, two Bow supporters behind, one enemy Solar Sword, and two Rose Thorns. The enemy formation comes from the normal Day 2 composer (Run seed 26). The Sword Adult is grown using Triploid Cells and trained normally; damage and death are produced by ordinary combat, with no forced kill. The small cast is the user-requested exception to the main footage’s ten-Unit composition. It still includes one Child out of three and no Mortar.

The previous shield-based lineage take is retained in `sources/takes/archive/revision-4/`, with the earlier loop in `preview/revision-4-lineage.mp4`. The replacement follows the Sword Adult’s actual spore through harvest as Lamarck II.

Revision 5 validation passed: nine active lossless source MOVs, 14 roster checks, six MP4s, five GIFs, and six screenshot pairs. The replacement lineage loop is exactly 10 seconds; its GIF is 2.69 MB. The earlier shield lineage source is archived separately.

## Revision 7 — restore the original trailer pacing

The trailer again uses the original quick Plant & Harvest sequence at 4–9s. Expanded gardening and lineage are excluded from the trailer and remain standalone ten-second MP4/GIF description loops. The restored export and lossless master are exact copies of the verified 32-second version, retaining the longer end card and smooth music ending. The editable recipe and chapter intermediates match that cut.

The superseded 40-second trailer is archived as `preview/revision-6-trailer-40s.mp4`, its master under `sources/masters/archive/`, and its edit recipe and documentation under `preview/revision-6-*`. Only the restored 32-second trailer is included in the upload ZIP.

Revision 7 verification passed: 32 seconds / 1920 frames at 1080p60, full MP4 decoding, source-action checks for the original grow sequence, and six matching lossless chapter intermediates. SHA-256 confirms the restored MP4 and lossless master are identical to their original verified files. The five standalone loop pairs and six screenshot pairs remain intact.

## Portrait social version

A separate 1080×1920 / 60 fps reel follows the original 32-second cut, with shot-specific crops and a portrait end card. It uses the original quick grow sequence and does not include the expanded gardening or lineage loops. The approved music/SFX timing and five-second ending are retained.

The social MP4 and cover are in `exports/social/`, with a lossless master under `sources/masters/`, editable framing in `scripts/portrait-edit.json`, and `scripts/render_portrait.py` to rebuild. Official Meta, TikTok, and YouTube requirements, source links, and editorial interface margins are documented in [SOCIAL-REEL.md](SOCIAL-REEL.md). The social download is `auto-shrooms-social-reel.zip`; the Steam upload ZIP keeps its original set of deliverables.

Portrait verification passed: 1920 frames at 1080×1920 / 60 fps, complete decoding, H.264/AAC format and file-size checks, fast start without edit lists, caption and CTA margins, and an unchanged PCM soundtrack. The initial social MP4 was 24.38 MB; current export measurements are in `social-validation.json`. That initial portrait release retained the revision 7 landscape files; revision 8 below supersedes both trailers.

## Revision 8 — Sword Child Training and matching end cards

The new lossless `training.mov` shows Franklin II, a Child carrying an inherited Sword, entering the Sword Cocoon. The real comparison dialog previews a Great Sword Adult. The edit ends immediately after the player confirms; no Day jump or emerged Unit follows. The standalone loop is 6.5 seconds, with updated MP4 and GIF files. Both 32-second trailers use matching new Training source ranges at 9–14s. The original quick Grow section and five-second ending remain.

The landscape end card uses the portrait version’s blurred capsule-art background recipe, with aspect-specific framing. The capsule, tagline, Steam logo, and Fredoka CTA retain their existing layout. The landscape soundtrack was remixed with the new Training SFX; the portrait master copies that PCM mix exactly.

Rebuild the changed assets with:

```sh
python3 scripts/capture_all.py training
python3 scripts/make_graphics.py
python3 scripts/render.py trailer training-loop --chapters 03-train 06-end-card
python3 scripts/render_portrait.py --chapters 03-train
python3 scripts/validate.py
python3 scripts/validate_portrait.py
python3 scripts/package.py
python3 scripts/package_social.py
```

Capture assertions verify Child + Sword, the Great Sword preview, successful confirmation, and no time advance or emergence. Validators check that both trailers stop just after confirmation, use identical Training ranges, and retain their 32-second pacing. The previous Training capture is in `sources/takes/archive/revision-7/`; affected exports, recipes, and documentation are in `preview/archive/before-sword-child/`, with prior masters under `sources/masters/archive/`. The other four standalone loops are unchanged. Screenshot 06 was subsequently updated as described below.

Revision 8 landscape and loop verification passed: nine lossless source MOVs, 14 roster checks, six Steam MP4s, five GIFs, and six screenshot pairs. The Training GIF is 2.71 MB. The landscape trailer measures −16.1 LUFS with −1.0 dBFS true peak; its last 0.1 seconds are silent.

### Training screenshot follow-up

Screenshot `06-training-combo` now shows Franklin II’s complete Child → Adult and Sword → Great Sword comparison. Its native 2560×1440 source PNG is `sources/stills/training-great-sword-preview.png`, extracted from frame 270 of the lossless Training capture. The delivered JPG and PNG remain 1920×1080. The gallery contact sheet and Steam upload ZIP are refreshed; other screenshots retain their previous files. Rebuild with `python3 scripts/render.py screenshots`.

## Store description header images

Five PNG banners use the requested headings: “Grow your units”, “Fight the heathen”, “Pupate & Train”, “Arrange your troop”, and “Create powerful lineages”. Each is 1170×150 with transparent outer margins, a cream cut-paper ribbon, and dark Spicy Rice lettering fitted to each ribbon. Desktop and phone-width previews are `preview/description-headers.png` and `preview/description-headers-mobile.png`.

The images are in `exports/headers/` and included in the Steam upload ZIP. `auto-shrooms-description-headers.zip` contains just the five PNGs and placement guide. Edit `scripts/headers.json` and run `python3 scripts/make_headers.py` to rebuild; `HEADER-GUIDE.md` and `STORE-COPY.md` map them to the existing loops. No trailers or gameplay loops changed.
