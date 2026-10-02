# Guided Run implementation validation

Validated on 2026-10-02 with Godot 4.7, against starting commit `d6a648d08189bbbaf4f8868b2aa95bc7cd90f2c3`.

## Automated checks

- Editor import/script validation: passed.
- Public Run lifecycle: 290 checks passed. Covers default mode selection, all 15 Days, skipped features, delayed planting, limited offers, retries, Compost/lineage restoration, Seal rollback, and terminal preferences.
- Actual combat/result integration: 103 checks passed. Repeated losses on Days 1, 5, 10 and 15 remain retryable; Day 10 continues; final victory remains replayable until accepted.
- Analytics: 21 checks passed with a local collector. Guided Runs emit only start and terminal quit/completion with reached Day; normal progression, resources and in-run intents are excluded. Ordinary events remain intact.
- `git diff --check`: passed.

Commands and test boundaries are in [tests/README.md](../../tests/README.md). Tests restore the existing settings file. The combat test exits successfully but Godot reports retained audio instances/resources at shutdown; verbose inspection identified audio playback/streams, with no in-session script errors or retained gameplay snapshots.

## UI checks

Rendered at 1920×1080: checked/unchecked Guided run on Title, Victory and Game Over; staged War Chamber/Nursery controls; Day-11 Seal markers, chooser, Hide and Nursery inspection; no new onboarding text panels or tooltips. Existing item and action inspection remains available.

Early Stock inspection passed 21 additional real-window probe checks: one/four spores fit, normal item details open, dragging and Nursery actions remain unavailable, Escape/Close/outside-click dismiss, and Day 6 moves inspection into the unlocked Nursery. Escape ordering and wide-panel padding defects found by the probe were fixed.

## Review

Standards and Spec reviews ran separately. The starter Adult's Generation mismatch was fixed to match Generation II. The analytics rollback concern was superseded by the user's decision to exclude all guided gameplay events; the final contract has explicit regression coverage. Optional review suggestions about parallel authored-content tables were left as local tuning data rather than expanded into another content abstraction.

## Balance limits

Seven unforced, fixed-seed combat samples won: the Day-1 starter, then Days 5, 10 and 15 with both Mace and non-Mace rosters using normal Training Stat rules. These use attainable prepared rosters rather than a complete economic Run simulation. Playtesting is still needed for pacing, overload, formation readability, and voluntary/delayed feature use.
