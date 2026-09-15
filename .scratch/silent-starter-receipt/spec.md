# Silent starter receipt

Receiving the confirmed starter at the beginning of a run must trigger no sound.
Remove the reward cue and suppress the confirm button's automatic press cue.
Keep card selection/hover feedback and Nursery harvesting intact. Update the
existing listening review's Harvest context and preserve notes/audio files.

Baseline: `621fba4`. Verify the actual button signal grants units without emitting
UI cues, and that ordinary dynamically created buttons still play their cue.

Implemented and verified: settings runtime 60/60, focused SFX runtime 43/43;
no failures or script errors. The wired starter Confirm signal emits no new
UI cues and still seeds the troop. Ordinary dynamic-button clicks remain audible.
The live browser now labels the cue Harvest, describes Nursery-only use, and
preserves the exact existing notes. Audio assets are unchanged.

Standards review: 0 findings. Spec review: 0 findings.
