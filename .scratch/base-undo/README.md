# Base Undo checks

Run the gameplay checks as a scene (on macOS, launch Godot outside the agent sandbox):

```sh
godot --headless --path . res://.scratch/base-undo/runtime_check.tscn
```

The harness drives the Base's real action handlers and checks state restoration, failed actions, multiple undo steps, all three paid reroll barriers, Training, Compost lifecycle effects and Stock eviction, Fungicide, harvests and daily bonuses, stable random outcomes, Seal offers and reroll prices, starter choices, and visit/Battle/Run boundaries. It also sends keyboard and mouse events through the viewport while a Seal chooser is open. An Analytics spy verifies inverse Biomass events without sending test events.

Render a visual check with `godot --path . --rendering-method gl_compatibility res://.scratch/base-undo/preview.tscn`; it writes `/tmp/base-undo-preview.png`.
