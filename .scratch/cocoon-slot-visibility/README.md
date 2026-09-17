# Cocoon slot visibility regression check

Run from the repository root with Godot 4.7, outside the agent sandbox on macOS:

```sh
godot --headless --path . res://.scratch/cocoon-slot-visibility/repro.tscn
```

The check drives actual mouse drags from squad and bench slots into a cocoon.
It verifies that the source unit disappears while the training confirmation is
open, cancellation restores it, confirmed training keeps it out of troop slots,
and training completion brings it back. The unconfirmed preview leaves the
roster data unchanged.

Before the fix, both source-slot checks failed: drag-end restored the source
card while the modal was still open. The War Chamber now omits the unit's card
until the preview is cancelled or training is confirmed.

Exit 0 passes; exit 1 reports failed checks; exit 2 is the timeout safeguard.
