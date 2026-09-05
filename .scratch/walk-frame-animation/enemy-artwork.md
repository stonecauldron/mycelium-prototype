# Enemy walking frames

Scope: Stump, Durian, Log and Acorn Knight. The other enemy designs have no exposed legs and retain their existing animation.

Four frames use a 0.72 second loop, with each frame held for 0.18 seconds. The pre-existing 0.36 second bob and squash repeats twice per stride. Idle keeps the original texture. Frame sheets use PNG alpha; no shader or runtime color key is used.

Stump and Log use the successful ImageGen transparent outputs. The user explicitly approved local image processing for Durian and Acorn Knight after ImageGen background extraction returned opaque or altered art. `prepare_enemy_walk.py` removes magenta from the original generated sheets and suppresses edge spill without redrawing their poses. `wire_enemy_walk.py` records the atlas setup and matching to each original sprite's visible bounds.

Visual and behavior checks: run `enemy_preview.tscn` with `-- --screenshot`; it writes `enemy-preview.png` and checks frame changes, looping, repeated walk requests, idle reset, mirrored/equipped variants, unchanged collision/mount transforms, absence of shaders and legless-enemy scope.

## stump

Source reference: `assets/units/enemies/stump/stump.png`

Final sheet: `assets/units/enemies/stump/stump_walk.png`

Generation prompt:

Use case: precise-object-edit. Production game sprite sheet: make FOUR WALK FRAMES of the exact stump enemy in the reference image. Subject: short dark-brown tree stump with a diagonally cut oval top showing golden concentric tree rings, two small round black eyes on the front, one small branch extending up to the RIGHT ending in a single olive leaf, and two short dark-brown rounded feet underneath. Keep the branch, leaf, oval top rings, cylindrical body and face exactly consistent across all four poses. Animate ONLY the visible legs/feet, with a restrained walk in place. Do NOT add any limbs or remove any body parts. Preserve the source's exact muted palette: #472D1C, #080907, #DAAA6C, #5E6744, #442B1B, #462C1C. Preserve bold nearly black hand-drawn outlines, approximately 14–18 pixels on a character around 480 pixels high, matching the reference at the same rendered body size. Flat solid fills, no added shading, gradients, texture or highlights. Do not brighten or saturate the colors. No weapons, props, ground shadows or scene. Exact layout: 2 columns by 2 rows, four equal square cells, each complete character around 75–80 percent of its cell height with comfortable margins. Keep the stationary upper body and its centerline, scale and top anchor identical across every frame. Top-left = screen-left foot forward/screen-right foot back, contact pose. Top-right = screen-left foot planted low, screen-right foot clearly lifted and bent into a passing step. Bottom-left = screen-right foot forward/screen-left foot back, opposite contact. Bottom-right = screen-right foot planted low, screen-left foot clearly lifted and bent, opposite passing pose. Keep the existing short leg anatomy and foot colors; do not turn the feet into human legs. Upper body stays unchanged. Every pose fully contained within its cell. Use a uniform PURE MAGENTA #FF00FF background outside the sprites and between limbs for a subsequent alpha extraction step. Absolutely no checkerboard, labels, dividers or typography. One square sprite sheet for this enemy only. Match the exact reference design; change only the stepping feet.

## durian

Source reference: `assets/units/enemies/durian/durian.png`

Final sheet: `assets/units/enemies/durian/durian_walk.png`

Generation prompt:

Use case: precise-object-edit. Production game sprite sheet: make FOUR WALK FRAMES of the exact durian enemy in the reference image. Subject: large muted olive-green spiky durian fruit, angry slanted black eyes, tiny black angular rind marks, brown tilted stalk at the top left and two short brown rectangular legs below the spiny fruit. Keep the fruit silhouette, spikes, rind markings, stalk and eyes exactly consistent across all four poses. Animate ONLY the visible legs/feet, with a restrained walk in place. Do NOT add any limbs or remove any body parts. Preserve the source's exact muted palette: #7F7F53, #080907, #472D1C, #6A6A46, #7E7E52, #090A08. Preserve bold nearly black hand-drawn outlines, approximately 14–18 pixels on a character around 480 pixels high, matching the reference at the same rendered body size. Flat solid fills, no added shading, gradients, texture or highlights. Do not brighten or saturate the colors. No weapons, props, ground shadows or scene. Exact layout: 2 columns by 2 rows, four equal square cells, each complete character around 75–80 percent of its cell height with comfortable margins. Keep the stationary upper body and its centerline, scale and top anchor identical across every frame. Top-left = screen-left foot forward/screen-right foot back, contact pose. Top-right = screen-left foot planted low, screen-right foot clearly lifted and bent into a passing step. Bottom-left = screen-right foot forward/screen-left foot back, opposite contact. Bottom-right = screen-right foot planted low, screen-left foot clearly lifted and bent, opposite passing pose. Keep the existing short leg anatomy and foot colors; do not turn the feet into human legs. Upper body stays unchanged. Every pose fully contained within its cell. Use a uniform PURE MAGENTA #FF00FF background outside the sprites and between limbs for a subsequent alpha extraction step. Absolutely no checkerboard, labels, dividers or typography. One square sprite sheet for this enemy only. Match the exact reference design; change only the stepping feet.

## log

Source reference: `assets/units/enemies/log/log.png`

Final sheet: `assets/units/enemies/log/log_walk.png`

Generation prompt:

Use case: precise-object-edit. Production game sprite sheet: make FOUR WALK FRAMES of the exact log enemy in the reference image. Subject: two stacked dark-brown tree-log cylinders: a broad heavy lower cylinder with an oval golden ringed cut surface, a smaller narrower upper log with golden rings on top, two angry slanted black eyes on that upper log, and one small olive leaf extending from its top right. Two short wide dark-brown blocky feet protrude underneath the lower log. Keep both logs, their cut-surface rings, eyes and leaf exactly consistent across all four poses. Animate ONLY the visible legs/feet, with a restrained walk in place. Do NOT add any limbs or remove any body parts. Preserve the source's exact muted palette: #472D1C, #080907, #261307, #DAAA6C, #5E6744, #452C1B. Preserve bold nearly black hand-drawn outlines, approximately 14–18 pixels on a character around 480 pixels high, matching the reference at the same rendered body size. Flat solid fills, no added shading, gradients, texture or highlights. Do not brighten or saturate the colors. No weapons, props, ground shadows or scene. Exact layout: 2 columns by 2 rows, four equal square cells, each complete character around 75–80 percent of its cell height with comfortable margins. Keep the stationary upper body and its centerline, scale and top anchor identical across every frame. Top-left = screen-left foot forward/screen-right foot back, contact pose. Top-right = screen-left foot planted low, screen-right foot clearly lifted and bent into a passing step. Bottom-left = screen-right foot forward/screen-left foot back, opposite contact. Bottom-right = screen-right foot planted low, screen-left foot clearly lifted and bent, opposite passing pose. Keep the existing short leg anatomy and foot colors; do not turn the feet into human legs. Upper body stays unchanged. Every pose fully contained within its cell. Use a uniform PURE MAGENTA #FF00FF background outside the sprites and between limbs for a subsequent alpha extraction step. Absolutely no checkerboard, labels, dividers or typography. One square sprite sheet for this enemy only. Match the exact reference design; change only the stepping feet.

## acorn_knight

Source reference: `assets/units/enemies/acorn_knight/acorn_knight.png`

Final sheet: `assets/units/enemies/acorn_knight/acorn_knight_walk.png`

Generation prompt:

Use case: precise-object-edit. Production game sprite sheet: make FOUR WALK FRAMES of the exact acorn knight enemy in the reference image. Subject: acorn knight with a tall pointed golden-tan acorn head, a short cream highlight along the upper-left edge of that head, two round black eyes, a dark brown overlapping acorn-cup armored collar, large rounded muted gray-olive body, and two short gray-olive boot-like feet at the bottom. Keep the pointed head, highlight, face, armored collar and rounded body exactly consistent across all four poses. Animate ONLY the visible legs/feet, with a restrained walk in place. Do NOT add any limbs or remove any body parts. Preserve the source's exact muted palette: #080907, #6A6B59, #BC8F54, #382316, #52533E, #BC8031. Preserve bold nearly black hand-drawn outlines, approximately 14–18 pixels on a character around 480 pixels high, matching the reference at the same rendered body size. Flat solid fills, no added shading, gradients, texture or highlights. Do not brighten or saturate the colors. No weapons, props, ground shadows or scene. Exact layout: 2 columns by 2 rows, four equal square cells, each complete character around 75–80 percent of its cell height with comfortable margins. Keep the stationary upper body and its centerline, scale and top anchor identical across every frame. Top-left = screen-left foot forward/screen-right foot back, contact pose. Top-right = screen-left foot planted low, screen-right foot clearly lifted and bent into a passing step. Bottom-left = screen-right foot forward/screen-left foot back, opposite contact. Bottom-right = screen-right foot planted low, screen-left foot clearly lifted and bent, opposite passing pose. Keep the existing short leg anatomy and foot colors; do not turn the feet into human legs. Upper body stays unchanged. Every pose fully contained within its cell. Use a uniform PURE MAGENTA #FF00FF background outside the sprites and between limbs for a subsequent alpha extraction step. Absolutely no checkerboard, labels, dividers or typography. One square sprite sheet for this enemy only. Match the exact reference design; change only the stepping feet.



Verification: Godot 4.7 rendered the complete gallery successfully; 272 checks passed with zero failures. The rendered PNG was visually inspected against each original idle sprite.
