# Guided Run implementation validation

Validated on 2026-10-02 with Godot 4.7, against starting commit `d6a648d08189bbbaf4f8868b2aa95bc7cd90f2c3`.

## Automated checks

- Editor import/script validation: passed.
- Public Run lifecycle: 444 checks passed. Covers default mode selection, all 15 Days, skipped features, Mace on Day 4, Shield on Day 8 and Plot/Squad expansion on Day 9, every Cocoon on Day 13, actual Training and expansion purchases, the two-total-Plot guided cap through Day 15, the ordinary four-Plot limit, and terminal preferences. Day-12 full-Shop purchases, locked offers, rerolls and daily rolls restore exactly across retries. Seal choices follow Days 11/13/15, with a curated first pick and full eligible pool from Day 13; selected nonintroductory Seal effects and offers restore correctly. Existing delayed planting and Compost/lineage restoration also pass.
- Actual combat/result integration: 351 checks passed. Repeated losses on Days 1, 5, 10 and 15 remain retryable; victories show only normal Continue, and hidden retry handlers cannot alter a victory. Real summaries cover the revised next-Day unlock highlights (including Mace/progression, Shield/Thorny for Day 8, both expansions for Day 9, Full Shop, and Spear/full Seal pool), feed consumption, and no-unlock/defeat/final exclusions. Ordinary Day-1 victory retains exactly one Nursery message. Day 10 continues to Day 11, and final Continue completes the Run.
- Analytics: 21 checks passed with a local collector. Guided Runs emit only start and terminal quit/completion with reached Day; normal progression, resources and in-run intents are excluded. Ordinary events remain intact.
- Graphical guidance: 89 checks passed. Arrows introduce functionality only on its unlock Day through Day 11; Days 5 and 10 stay quiet, and Days 12–15 remain quiet even with pending Seals or an empty Squad. Covers actual Training, Nursery/Stock sources, both capacity unlocks, affordability, completed actions, skipped introductions, read-only hint selection, and inspection history across retries and new Runs.
- `git diff --check`: passed.

Commands and test boundaries are in [tests/README.md](../../tests/README.md). The latest four-scene suite passed all 905 checks with no script/runtime failures, and settings bytes were restored exactly. Combat exited successfully but repeated an intermittent shutdown warning about six ObjectDB instances and one resource still in use.

Unlock-only arrow follow-up: removed recurring Battle, Formation, Scout, and Nursery suggestions, including the post-Compost planting prompt. An early Day-12 cutoff also suppresses later Shop, School and Seal introductions. Separate Standards and Spec reviews found no issues. Static presentation review confirms an empty hint immediately hides the current arrow, while existing guided-mode checks keep legacy coaching suppressed; normal drag feedback remains available.

Shield timing follow-up: Training is rejected before Day 8 and charges its normal price on Day 8. The Shield arrow is available on Day 8 after the Mutation opportunity. Actual Day-7 and Day-8 victories confirm Shield/Thorny appear for Day 8 and only capacity unlocks appear for Day 9.

## UI checks

Rendered at 1920×1080: checked/unchecked Guided run on Title, Victory and Game Over; staged War Chamber/Nursery controls; Day-11 Seal markers, chooser, Hide and Nursery inspection; no new onboarding text panels or tooltips. Existing item and action inspection remains available.

Follow-up layouts verified: New Run stays on the other buttons' centerline, with the Guided run checkbox anchored independently to its right on all three menus. Checked/unchecked screenshots and 27 layout/click checks passed; toggling the checkbox does not activate New Run. Victory summaries show only Continue; defeat summaries retain their retry actions. Both omit the preparation-reset explanation.

Daily unlock summary follow-up: eight rendered summaries verified next-preparation-Day icons and labels, including Nursery, Shop, Compost/Seals, no-unlock Days, defeat, and final victory. A busy summary passed 14 focused layout/input checks: bounded paper beside the recap, readable Unit names, wheel scrolling through the last result row, and exactly one Continue activation. The result paper keeps a 24px gap from the recap and a 28px gap above the actions at 1920×1080. Existing preference bytes were unchanged.

Revised schedule follow-up: 26 UI checks passed for Mace visibility on Day 4, hidden/visible Shield and Plot expansion across Days 8–9, all four Shop offers with actual locking and paid reroll on Day 12, all five Cocoons and the full-pool chooser on Day 13, and Seal markers on 11/13/15. Day-8/11/12 victory summaries show the correct 3/1/2 unlock rows. A Shop source arrow overlapped the newly exposed Reroll control; moving first-slot and Reroll arrows to the left fixed it. The final focused recapture passed 12 checks for source-to-Plot guidance, clear arrow placement, native right-click locking, and paid reroll preserving locked offers. Preferences were unchanged.

Summary scrolling correction: reproduced the retained biomass label moving 0px while its row moved −64px. The completed amount now lives inside the scrolling row; scrolling an active/pending reward settles it there, keeping the completion sound intact. All 44 focused checks passed across Days 8–9: matching label/row movement, clipping, wheel/pan over labels and icons, first scrollbar drag, duplicate prevention, reaching the final row, and Continue on first click. Six Nursery UI checks also passed for the guided two-Plot cap: buying the second Plot on Day 9 leaves exactly two tiles with no third purchase or expansion hint. Preferences were unchanged.

Graphical guidance follow-up: 16 captures and 11 interaction checks passed. Checked Battle, Child-to-Bow, progression, Nursery navigation, Plant, Shop/Stock-to-Plot, Compost, and actual lineage-Spore targets. Arrows clear adjacent headings and use painted texture bounds for Plots and other image targets. Pause, Seal hide/reopen, Shop-to-Stock source changes, and rich-inspector overlap behave correctly; covered hints pause their timers and resume after inspection. Guidance adds no text or required action.

Early Stock inspection passed 21 additional real-window probe checks: one/four spores fit, normal item details open, dragging and Nursery actions remain unavailable, Escape/Close/outside-click dismiss, and Day 6 moves inspection into the unlocked Nursery. Escape ordering and wide-panel padding defects found by the probe were fixed.

## Review

Standards and Spec reviews ran separately. The starter Adult's Generation mismatch was fixed to match Generation II. The analytics rollback concern was superseded by the user's decision to exclude all guided gameplay events; the final contract has explicit regression coverage. Optional review suggestions about parallel authored-content tables were left as local tuning data rather than expanded into another content abstraction.

## Balance limits

Seven unforced, fixed-seed combat samples won: the Day-1 starter, then Days 5, 10 and 15 with both Mace and non-Mace rosters using normal Training Stat rules. These use attainable prepared rosters rather than a complete economic Run simulation. Playtesting is still needed for pacing, overload, formation readability, and voluntary/delayed feature use.
