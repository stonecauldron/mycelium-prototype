# Attack-speed stopwatch artwork

Generated with the built-in image-generation tool on 2026-10-01, with a transparent background, then cleaned and exported with ImageMagick. Final source asset: [`assets/ui/attack_speed_icon.png`](../../assets/ui/attack_speed_icon.png), **128 × 128 pixels** (Sword: 128 × 128; Heart: 128 × 120). Godot uses the source size directly. Numerals are rendered by `StatChip`, not baked into the artwork.

The user's stopwatch image was a concept reference; this is newly generated artwork matching the game's existing black-outlined sword and heart chips.

## Initial generation prompt

Create exactly one original stopwatch icon for a whimsical hand-drawn 2D mushroom strategy game UI. Transparent background. Compact square silhouette, centered and tightly framed with about 6% transparent padding. Thick slightly irregular almost-black outline (#080907), simple flat muted parchment cream clock face, muted teal green metal rim (#477b7d), a short black-outlined top stem and button plus a tiny upper-right angled button. The stopwatch is front facing, gently imperfect organic silhouette. It should match chunky flat black-outlined sword and heart stat-chip icons, not a polished vector app icon or realistic object. Readable at 40-56 pixels. No speed lines (they take space away from the face). Leave the central face mostly blank and wide, since game code will overlay numbers like 1.5s or 1.15s. Only two subtle dark clock hands pointing roughly toward 12 and 2 near the top of the face, with plenty of clear central/lower face for text. No letters, numbers, labels, logos, watermark, glow, gradient, drop shadow, or background. This is a new standalone game asset, not an edit of a screenshot.

## Centered-hands edit prompt

Revised with the built-in image-generation tool on 2026-10-01 using the original generated icon as the edit target. The user requested larger hands pivoting at the center of the face and a clean teal rim. Transparency and the existing asset path are preserved.

Edit the supplied game stopwatch icon with only these corrections. Put the shared pivot of the two clock hands at the exact center of the circular cream clock face (not the center of the entire image including the top buttons); the current pivot is visibly above that center, so move it down to the face center. Make both black hands substantially thicker and larger, keeping them pointed toward 12 and roughly 2 o'clock, with the long hand reaching near the top of the face and the shorter hand toward upper-right. Enlarge the central pivot proportionally. Remove ALL the short black decorative tick marks/scratches from inside the teal circular rim, leaving an uninterrupted clean teal band between its existing black inner and outer outlines. Keep those bold black boundary outlines. Remove similar stray black scratch marks inside the top button and its stem. Preserve the same whimsical hand-painted style, teal-and-cream palette, outer silhouette, button shapes, source image canvas dimensions, framing, placement, and transparent background. Do not add numerals, text, tick marks, shadows, backdrop, or other objects. This replaces the in-game icon, so keep the same overall size and position.

## Simplification prompt

Revised again with the built-in image-generation tool on 2026-10-01. Edit target: the previous stopwatch. Style references: `assets/base/unit_card/hp_icon.png` and `assets/base/unit_card/sword_icon.png`. The selected result removes the layered metal rim and uses a simple teal face with a black silhouette and hands. `StatChip.value_position_offset` moves only speed numerals lower, leaving the centered hands exposed.

Image 1 is the stopwatch to edit; Images 2 and 3 are style references only, do NOT reproduce the heart or sword. Simplify the stopwatch so it genuinely matches the extremely simple flat-color black-outlined heart and sword stat icons. Keep the stopwatch silhouette, approximate canvas placement and two top buttons. Remove ALL rendering, gradients, highlights, shadows, metallic bands, gloss, texture and speckles. Replace the entire circular face and rim with ONE uninterrupted flat solid muted teal fill #729B92, surrounded by ONE thick totally solid pure black #000000 outer outline, a gently imperfect hand-drawn contour matching the heart reference. NO concentric inner ring, no colored rim layers, no beige inner face. Make the two buttons flat teal with the same pure black outline. The two clock hands must be bold solid pure-black simple straight rounded strokes, one pointing straight up and one toward 2 o'clock, meeting at a small solid pure-black hub at the exact center of the circular face (not center of the whole image including buttons). Leave the lower half of the face empty so numbers can be drawn there by the game separately. The hands must stay centered; do not move them up. Keep the hands visually separated with clear teal between them. No numbers, no tick marks, no extra marks, no text, no watermarks. Crisp fully opaque black outlines and flat fills, only edge antialiasing is allowed. Transparent background, keep same 1280x1280 canvas and stopwatch framing. Deliver ONLY the simplified stopwatch icon.

## Final thick-outline, single-button prompt

Redraw image 1 completely as a CLEAN, SIMPLE flat-color stopwatch game stat icon. The existing image has an unwanted pixelated cloudy smear; do not preserve that texture or any of its pixels. Use image 2's very chunky solid black outline and plain flat fill style. Draw a slightly organic round body filled with one completely even muted teal color, a MUCH THICKER pure black outline approximately 10% of the body diameter, and exactly ONE short button centered at the top. REMOVE the button and stem on the upper right entirely; that area must be transparent outside the circular body. Two solid pure-black hands, pointing to 12 and 2, meet at the exact center of the circular body. No inner ring. No tick marks. No additional decorations. The whole lower half of the face is pristine uninterrupted flat teal, with absolutely NO smear, grain, dithering, cloudy shading, highlights or gradients. This is clean hard-edged two-color clipart, teal and black, on a transparent background. Keep the centered hands clearly defined and leave the lower face available for a number overlay. Icon should fill a 128x128 square canvas with small transparent padding, matching the resolution and simplicity of the heart stat icon. No numbers or text baked into the image. Do not add any side button.

### Pixel cleanup and export

The generated result still contained partial alpha inside the face (one sampled smear pixel had alpha 0.2). The final asset uses an opaque silhouette mask, removes disconnected alpha specks, and flattens the interior palette to black and `#729B92`. A triangle-filtered 128px export keeps antialiasing confined to edges. The face is opaque and the background remains transparent.

ImageMagick steps, applied to the selected generated PNG:

```sh
magick "$source_png" -alpha extract -threshold 1% -define connected-components:area-threshold=100 -define connected-components:mean-color=true -connected-components 8 -threshold 50% "$alpha_mask"
magick "$source_png" -alpha off -colorspace Gray -threshold 12% -colorspace sRGB -fill '#729B92' -opaque white "$alpha_mask" -alpha off -compose CopyOpacity -composite -filter Triangle -resize 128x128 "PNG32:$output_png"
```

### Final outline polish

The approved 128px artwork received one further subtle outline increase. Erode its teal fill mask by one pixel, then restore the same solid teal palette and original alpha channel. This thickens the black edges inward while preserving the exact canvas, outer silhouette and transparency; it also avoids reintroducing generated texture. The image-generation edit was used as a visual reference, while this final pixel pass retained the approved artwork.

```sh
magick "$approved_png" -alpha off -channel G -separate +channel -evaluate Divide 0.6078431373 -morphology Erode Disk:1 "$fill_mask"
magick -size 128x128 'xc:#729B92' "$fill_mask" -compose Multiply -composite "$approved_png" -compose CopyOpacity -composite "PNG32:$output_png"
```

The subsequent stronger-outline request increases the circle/hand stroke inward by two more pixels (`Erode Disk:2`) and the top button area (rows 0–29) by one more pixel, retaining a small teal button inset. The original alpha channel, 128px canvas and flat palette are preserved. [Light-background preview](outline-preview.png) is shown at 3× nearest-neighbor scale; the actual game asset remains transparent and 128 × 128.

Built-in image-generation reference prompt for this final pass: “Edit this game stopwatch icon: give it a visibly MUCH heavier BLACK outline. The last very subtle increase was not enough. Increase the circular casing border by about two pixels at128x128scale, clearly bold/chunky like a thickly outlined cartoon health heart. Make the outline around the single top button heavier too. Preserve the simple teal face, centered black hands, single top button, proportions and transparent background. No side button, no internal ring, no numbers, no texture or shading or transparent patches inside the face. Flat pure black and teal only.128x128canvas. The key visible change must be noticeably thicker outer contours.”

### Thinner hands

The final refinement reduces the hands and hub by two pixels on their edges, while keeping the bold casing and button exactly as approved. Only the isolated interior hand component (plus one pixel for antialiasing) is composited back into the original image; exterior pixels and alpha remain unchanged. The light-background preview reflects this revision.

Built-in image-generation reference prompt: “Make only the two black clock hands and their central pivot visibly thinner/smaller, about one third slimmer. Preserve the current thick black OUTER circular outline and the thick single top button outline exactly. Keep the hands' center and directions (12 and2o'clock), lengths, flat teal fill,128x128square framing and transparent background. Only reduce the thickness of the interior hands and hub. No additional buttons, texture, smears, shading, numbers or other changes.”
