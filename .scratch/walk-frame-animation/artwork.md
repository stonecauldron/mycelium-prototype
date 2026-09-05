# Mushroom walk frames

Generated with the built-in ImageGen tool from the existing child and adult body PNGs. Original idle art is retained. Runtime assets:

- `assets/units/generalist/gen_child_walk.png`
- `assets/units/generalist/gen_imago_walk.png`

Each sheet contains four poses. `AtlasTexture` regions register their torso and foot positions; `WalkFrames` scales each region to the original body bounds. Both runtime sheets are RGBA PNGs with transparent backgrounds. The original generation backgrounds were removed with built-in ImageGen background extraction; no shader or custom material is used.

The existing AnimationPlayer drives both the original squash/bob tracks and the discrete frame track. A full left/right stride takes 0.72 seconds and contains two of the original 0.36-second bounces. Idle restores the original sprite and resets the frame layer. Caps and held weapons continue following the original Sprite transform.

## Adult generation prompt

Use case: precise-object-edit. Production 2D game sprite sheet. Make FOUR walking frames of the attached capless mushroom body, 2 by 2 grid on a UNIFORM PURE MAGENTA (#FF00FF) background for game-engine chroma-key removal. Absolutely no checkerboard. Keep the SAME body, exactly matching its WHITE fill, small olive neck nub, short tapered arms, simple flat untextured style. NO cap, eyes, face, weapons, shadows, texture or gradients. Only change lower stubby feet between frames: 1 left forward / right back, 2 left planted / right foot lifted, 3 right forward / left back, 4 right planted / left foot lifted. Keep torso and arms identical and registered. Each cell exactly same scale and position: fill about 80% of its cell, fully visible with margins. Four poses read as short waddling walk in place to the right with clear alternating tiny legs. Source dark exterior/negative-space silhouette details must be nearly black; do not thicken outlines or redesign the body. Flat white stays opaque. Grid is exactly two equal columns and rows, no text, no dividers. Solid pure #FF00FF backdrop in all surrounding space and between arms and legs.

## Adult refinement prompt

Use case: precise-object-edit. Image 1 is the EDIT TARGET: four frames of an adult mushroom walk on solid magenta. Image 2 is the original character STYLE REFERENCE. Make TWO corrections to image 1 and preserve its 2x2 layout, exact cell registration, size and colors. First, the thin outlines on image 1 are wrong: add a HEAVY near-black outline around the ENTIRE silhouette including arms and feet, matching the bold thick black outline of image 2. Outline should be approximately 14 pixels thick when a character is about 410 pixels tall; flat uniform near-black. No shadows. Keep white fill and olive neck nub. Second, the upper-right and lower-right walking poses must lift OPPOSITE feet: UPPER RIGHT frame = SCREEN-LEFT foot planted low, SCREEN-RIGHT foot raised and bent forward with sole about 45 pixels above the baseline. LOWER RIGHT frame = SCREEN-RIGHT foot planted low, SCREEN-LEFT foot raised and bent forward with sole about 45 pixels above baseline. Upper-left and lower-left remain opposite contact poses. Keep the arms, neck and torso the same across all frames, keep the small stubby rounded leg shapes. No cap, face, eyes, weapon or labels. Retain the perfectly solid pure MAGENTA #FF00FF background everywhere outside the character, including gaps between the feet, for runtime chroma key. No checkerboard. Do not resize or rearrange the 2x2 sheet or move the torso registrations. Crisp flat game sprite artwork.

## Child generation prompt

Use case: precise-object-edit. Production 2D game sprite sheet. Make FOUR walking frames of the attached CHILD mushroom BODY, 2 by 2 equal grid on a UNIFORM PURE MAGENTA (#FF00FF) background for game-engine chroma-key removal. No checkerboard. Keep the exact same very simple squat little WHITE body and thick nearly black outline, rounded narrow top, chubby torso, two stubby rounded feet, one tapered arm pointing left and a shorter arm right. It is CAPLESS and FACELESS: do not add a cap, hat, eyes, face, neck nub, weapons or props. Only change the lower legs/feet: top-left left foot forward / right foot back contact; top-right left planted / right foot lifted; bottom-left right foot forward / left foot back contact; bottom-right right planted / left foot lifted. Obvious alternating tiny feet form a restrained waddling walk in place to the right. Upper torso and arms stay IDENTICAL in every frame, same scale, same centerline and height registration. Each complete body fills about 75 percent of its equal cell, feet on the same baseline. Flat WHITE fill and simple clean dark outer edge match source exactly: no shading or texture, no scene, no shadows, no dividers or labels. Keep all surrounding space and spaces between limbs uniform #FF00FF. One square sprite sheet, exactly 2 columns by 2 rows.

## Final background-extraction prompts

Applied separately to each existing walk sheet using the built-in ImageGen tool. The adult prompt additionally specifies preserving the olive neck nubs.

Use case: background-extraction. Remove ONLY the solid magenta background from this sprite sheet and return a PNG with REAL TRANSPARENCY in its alpha channel. The exterior and all gaps between arms/legs must be alpha 0, not painted white or a checkerboard. Preserve every original sprite pixel, original colors, pure white opaque body fills, thick black outlines, all four exact poses, exact positions, full 1254x1254 canvas size, and identical frame registration. Do not redraw, rescale, reposition, change the artwork, or create new poses. Clean magenta contamination from antialiased edges. Output a genuinely transparent RGBA PNG cutout of this exact existing sheet.

## Adult outline weight adjustment

Compared the right torso border at the same displayed body size: the idle source measured approximately 12 pixels, while the original walk sheet measured approximately 7.4 after its scene scale. Used built-in ImageGen to strengthen the adult walk outlines, followed by background extraction to retain real RGBA transparency. Updated the atlas rectangles and normalization scale for the revised art. The shader remains removed.

Outline edit prompt:

Use case: precise-object-edit. Image 1 is the EDIT TARGET, an existing transparent adult mushroom walk spritesheet. Image 2 is the original idle adult BODY, provided ONLY as an outline-weight reference. Make one controlled pixel-preserving edit to Image 1: THICKEN the near-black outer outline on all four walking bodies by about 60%, from roughly 15 pixels to roughly 24 pixels on the torso at this sheet's native resolution. The walking frames are scaled to half their native size in-game, so the resulting border must match the 12-pixel border of the original idle source. Apply this stronger, clean near-black border consistently to torso, arms, feet and the olive neck nub. Thicken INWARD into the fills, keeping each existing external silhouette and bounding box fixed, so there is no growth into neighboring atlas regions. Preserve all four exact poses, white opaque body fills, olive fill, black details, sheet dimensions of EXACTLY 1254x1254, exact position of every frame, and all frame registration. Do not redraw or redesign the characters, move them, resize, change anatomy, add caps/faces, or add any other marks. Keep the surrounding background and gaps between limbs genuinely transparent with a REAL RGBA alpha channel; no magenta, white background or painted checkerboard. Output the same sprite sheet with only a moderately heavier black outline, clean antialiased edges and intact transparency.

The image edit returned an opaque checkerboard. An intermediate background substitution to solid magenta and the background-extraction prompt above produced the final transparent sheet. Only the final RGBA result is used by the game.

## In-engine preview and checks

```sh
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --resolution 1440x810 res://.scratch/walk-frame-animation/preview.tscn -- --screenshot
```

Add `--keep-open` after `--` to keep the preview open with the mirrored, tinted units animated. `preview.png` shows the original idle alongside all four poses. The preview checks frame advancement and looping, retained bounce/squash, repeated walk requests, idle restoration, unchanged colliders, and background removal in the rendered output.
