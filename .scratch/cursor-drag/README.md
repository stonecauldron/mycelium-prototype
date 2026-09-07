# Cursor drag diagnostic

Run from the repository root with Godot 4.7 (outside the agent sandbox on macOS):

```sh
godot --headless --path . .scratch/cursor-drag/repro.tscn --quit-after 120
```

This drives a real UnitCard with mouse events and executes the production cursor
script with an Input recorder. The recorder models the macOS embedded game view:
image registrations update a cache, and entering the view applies that cache to
the displayed cursor. It does not capture or inspect the OS cursor.

Godot 4.7's behavior is in
[LayerHost::cursor_set_custom_image and NOTIFICATION_MOUSE_ENTER](https://github.com/godotengine/godot/blob/4.7-stable/platform/macos/editor/embedded_process_macos.mm).

The original implementation failed with `drag cursor shape 7 still displays
hand_point.png`: replacing images after the pointer entered left the editor's
displayed cursor unchanged. Registering point/open/closed on fixed shapes at
startup avoids this path; dragging only changes the default shape for empty space.

The diagnostic checks the closed hand for both drop-result shapes and the
empty-space default, cancellation restoring the point/open mapping, and SVG
textures importing at 64 x 64. Exit 0 passes; exit 1 reports a failed check.
