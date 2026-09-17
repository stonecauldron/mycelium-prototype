# Starter confirmation sound

Status: implemented

User request: starter confirmation should play the same sound as choosing a Seal.
Reuse `Sfx.Cue.SEAL` after the starter units are granted. Keep the starter button's
generic press cue suppressed so confirmation emits only the intended cue.
Card selection and Nursery harvest keep their existing sounds.

Update the existing confirmation regression assertion and live review contexts.
Preserve unrelated title/settings work already in the working tree.

Verification: the current shared working tree passed all 73 settings/menu checks,
including exactly the SEAL cue on the wired starter Confirm signal and successful
unit receipt. No failures or script errors. Review data was rebuilt with the new
shared cue description; no audio assets changed. Browser tabs were closed, so no
browser playback check was needed for this unchanged recording.

Standards: 0 findings. Spec: 0 findings. Only this request's hunks are staged;
concurrent title/settings edits remain outside the commit.
