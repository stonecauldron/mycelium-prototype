# Flag bearer walk frames

Created with the built-in ImageGen tool from the mushroom character in `assets/combat/flag_bearer/flag.png`. Final runtime asset: `assets/combat/flag_bearer/flag_bearer_walk.png`, a 1254 × 1254 RGBA PNG with real transparency. No shader or custom material is used.

`flag_bearer_visual.tscn` uses four registered atlas frames under `Shroom/WalkFrames`. Its existing AnimationPlayer drives the frame changes over a 0.72-second stride, repeating the original 0.36-second body bounce and banner sway twice. The banner remains its original separate `Shroom/Flag` sprite. Idle hides the walk layer, restores the original body, and resets the frame index. The flag controller, collisions, and hurtbox are unchanged.

## Generation prompt

Use case: precise-object-edit. Create a four-frame WALK spritesheet for the FLAG BEARER mushroom from the attached source. Reference: only the complete mushroom CHARACTER at the BOTTOM of the source image (below y=669) is the subject. The separate banner and pole above it must NOT appear anywhere in the output; the game already draws that flag separately. Preserve this exact character: broad domed muted terracotta-red mushroom cap, thick nearly black contour, two small vertical black oval eyes, short beige neck, rounded beige torso, arms held curled together across the chest gripping an imaginary pole, and two tiny rounded feet. Head, eyes, cap and folded arms must remain stationary and IDENTICAL in all four frames; only lower feet change to walk in place. Bold flat artwork matching source, no shading, gradients or texture. Keep the black outline weight consistent with the source: about 18 px on a character roughly 480 px tall, uniformly bold around cap, arms, body, and feet. Layout: one square image, EXACTLY 2 columns by 2 rows, four equally sized cells. Each complete character occupies about 75 percent of its cell, with identical size, central registration, cap top and planted-foot baseline. Top-left: screen-left foot forward, screen-right foot back, contact pose. Top-right: screen-left foot planted, screen-right foot clearly raised by a small step. Bottom-left: screen-right foot forward, screen-left foot back, opposite contact pose. Bottom-right: screen-right foot planted, screen-left foot clearly raised by a small step. Small soft stubby feet, do not add long human legs or shoes. Use uniform pure bright MAGENTA #FF00FF behind and between the four characters for subsequent background extraction, no checkerboard, no labels, dividers or shadows. Keep all poses fully inside their cells. Only this mushroom character, no flag, banner, pole, sword, shield or accessories.

## Background extraction prompt

Use case: background-extraction. Remove ONLY the solid magenta background from this sprite sheet and return a PNG with REAL TRANSPARENCY in its alpha channel. The exterior and all gaps between arms/legs must be alpha 0, not painted white or a checkerboard. Preserve every original sprite pixel, original colors, terracotta cap, beige body and arms, black eyes, thick black outlines, all four exact poses, exact positions, full 1254x1254 canvas size, and identical frame registration. Do not redraw, rescale, reposition, change the artwork, or create new poses. Clean magenta contamination from antialiased edges. Output a genuinely transparent RGBA PNG cutout of this exact existing sheet.

## Verification

```sh
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1440x810 res://.scratch/walk-frame-animation/flag_preview.tscn -- --screenshot
```

The in-engine preview passed 158 checks covering idle/walk transitions, alternating poses and looping, repeated walk requests, the original bounce/squash and flag sway, preserved banner attachment and collider transforms, combat reset, team tinting, and transparent rendering. `flag-preview.png` shows the original idle and four walk poses in both directions; the last column animates if `--keep-open` is supplied after `--`.
