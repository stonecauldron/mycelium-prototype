# Image generation prompts

The ambient Store Page Background uses `sources/page_background_generated.png`; its full built-in imagegen prompt is recorded in `sources/page_background_prompt.txt`.

The final hero uses `sources/hero_final_generated.png`, with the last placement correction recorded in `sources/hero_final_prompt.txt`. Earlier hero masters are retained as intermediate versions.

Built-in `image_gen.imagegen` was used for all scene edits and capsule compositing. The original transparent logo is exported directly from the supplied PNG. ImageMagick is used only for pixel-size exports and QA contact sheets.

Reference 1: `sources/base_artwork.png` (artwork edit target).
Reference 2: `sources/base_logo.png` (wordmark insert).

## header

Use case: compositing.
Asset type: final Steam Store Header Capsule for Auto Shrooms, landscape aspect ratio exactly 920:430. Render at high resolution approximately 1840x860.
Input image 1 is the edit target artwork; input image 2 is the supporting original transparent wordmark to composite.
Adapt the supplied image minimally into a wide Steam header and composite the exact cream and black "Auto Shrooms" wordmark into its spacious dark upper canopy. Keep the same overall composition: four mushroom fighters on the LEFT (red flag bearer, green archer, brown hammer fighter, brown shield fighter) facing three plant fighters on the RIGHT (sunflower swordsman, rose spearman, wooden stump shield bearer), luminous golden tunnel centered behind them, cyan glowing mushrooms around the edges. Preserve all seven character designs, their proportions, faces, weapons, poses, and ordering; preserve the painterly background and flat outlined character art. All seven characters, flag, weapons and feet fully visible.
Wordmark is ONE LINE, horizontally centered near the top, approximately 86% of canvas width and 22% of canvas height, inside a 6% top margin. Copy the exact letter shapes, cream fill and near-black outline from image 2; do not invent a font or ornaments. Ensure no overlap with faces or flag. Keep a modest amount of foreground. Only extend the backdrop or reframe slightly to fit the target aspect; no added characters or objects, no style changes, no split panels. Only text: "Auto Shrooms". Full bleed artwork, no border or blank margins.

## main

Use case: compositing.
Asset type: final Steam Store Main Capsule, aspect ratio exactly 1232:706, approximately 2464x1412 pixels.
Input 1 is the edit target artwork. Input 2 is the supporting transparent wordmark.
Preserve the supplied painterly cave scene and all seven characters exactly as much as possible. Four mushroom fighters on the LEFT (red flag bearer, green archer, brown hammer fighter, brown orange-clad shield fighter) face three plant fighters on the RIGHT (sunflower swordsman, rose spearman, wooden stump shield bearer). Preserve their simple faces, poses, shapes, weapons, color, black outlines, arrangement. Keep the bright golden tunnel at center and cyan bioluminescent mushrooms around the darker root canopy and foreground. All characters fully visible, including feet, weapons and flag.
Composite the supplied cream and near-black "Auto Shrooms" wordmark in ONE LINE in the dark upper canopy, centered, about 82% canvas width, top margin 8%. Reproduce the exact reference letterforms, no alternate font, no bevels or ornaments. Text must not overlap the flag, faces or weapons. Preserve the original visual balance with fighters across the lower half, gold light centered behind the gap between teams. Extend only the backdrop slightly if necessary; no redesign or extra objects, no new characters. Only text: "Auto Shrooms". Full bleed, no border, no panels.

## small

Use case: precise-object-edit and compositing.
Asset type: final Steam Store Small Capsule for Auto Shrooms, extremely wide aspect ratio exactly 462:174, approximately 1848x696 pixels.
Input image 1 is the edit target artwork. Input image 2 is the exact original transparent logo.
Remove ALL seven fighters and ALL their held objects including the white flag, flagpole, bow, hammer, swords, shields and spears. Reconstruct the forest floor naturally. Keep the SAME painterly cave composition: dark twisted tree-root arch framing the image from left and right, cyan bioluminescent mushrooms at the edges, warm golden tunnel opening at the center. Preserve the palette and painting style. Simplify background detail modestly for a tiny Steam search thumbnail.
Place the original cream and near-black "Auto Shrooms" wordmark in ONE LINE horizontally and vertically centered, filling approximately 93% of image width with 3.5% side margins. Match the exact letter shapes, cream fill and bold dark outlines of the input wordmark; do not invent a new typeface or embellishments. It must remain readable when reduced to 120x45 pixels. Subdue the center brightness behind the wordmark just enough for contrast. NO characters, NO weapons, NO flag, NO other text, NO borders or blank margins. Full bleed artwork.

## vertical

Use case: compositing.
Asset type: final Steam Store Vertical Capsule, portrait aspect ratio exactly 748:896, approximately 1496x1792 pixels.
Input 1 is the artwork edit target, input 2 is the exact supporting transparent wordmark.
Adapt the original scene to portrait while keeping the SAME composition and character identities: four mushrooms on the LEFT facing three plants on the RIGHT, golden tunnel in the center behind their standoff, dark roots and glowing cyan mushrooms framing them. Four mushrooms in same left-to-right order: red flag bearer, green archer, brown hammer fighter, brown orange-clad shield fighter. Three plants in same left-to-right order: sunflower swordsman, rose spearman, wooden stump shield bearer. Keep all seven full-body characters including feet and weapons, no cropping or extra fighters. Preserve the simple black-outlined flat characters and painterly environment, exact outfits and weapons. Keep the opposing left-right arrangement; add vertical forest canopy and foreground space to fit portrait, group the two sides a little closer if needed but preserve their positions relative to each other and natural body proportions.
At the top in the dark canopy, place the exact original cream and black wordmark reflowed into TWO centered lines: "Auto" above "Shrooms". Keep both words' original letter shapes, cream fill and bold near-black outline. The wider "Shrooms" line fills about 88% of canvas width, "Auto" naturally narrower at the SAME letter height. Logo area spans roughly y=8%-30%; all characters and flag occupy below it, with no overlaps. Gold tunnel behind center of battle, fighters across lower half; cyan mushrooms in foreground. Keep a cohesive dense poster composition, no empty borders or panels. No added text, ornaments or branding.

## library

Use case: compositing.
Asset type: Steam Library Capsule, portrait aspect ratio exactly 600:900, approximately 1200x1800 pixels.
Input 1 is the source artwork to adapt. Input 2 is the original transparent logo to composite.
Maintain the original artwork's entire standoff composition: four mushroom fighters on the LEFT, three plant fighters on the RIGHT, warm golden root tunnel behind the center, cyan glowing mushrooms and dark tree roots around edges. The seven fighters in left-to-right order are red mushroom flag bearer, green mushroom archer, brown mushroom hammer fighter, brown orange-clad mushroom shield fighter, sunflower swordsman, rose spearman, and wooden stump shield bearer. Keep their faces, shapes, flat outlined illustration style, outfits, poses, equipment and proportions. Keep all seven full-body characters and their feet, weapons, flag within frame; no extra characters. Avoid cropping the original landscape into a narrow slice: extend the dark canopy above and foreground below, and gently group the two sides closer while retaining their left/right arrangement and hierarchy.
At the top put the original wordmark reflowed into two centered lines "Auto" above "Shrooms", exact original letter shapes, cream fill, bold near-black outline. "Shrooms" line is 88% of canvas width, "Auto" naturally narrower with same letter height. Logo occupies y=9%-29%, the tunnel behind center y=45%-66%, all characters roughly y=54%-78%. Flag stays below the logo. Dense, beautifully balanced portrait: moody root canopy, golden center, foreground cyan mushrooms. No empty borders, no panels, no additional lettering or ornaments.

## hero

Use case: precise-object-edit.
Asset type: Steam Library Hero, extra-wide panoramic artwork, EXACT aspect ratio 3840:1240, output as close to 3840x1240 as possible.
Input 1 is the edit target and source of all character identities and composition.
Create an extended panoramic version of this EXACT forest-cave standoff, preserving the painting style, palette and character identities. No text or wordmark at all, no typography. Keep four mushroom fighters on the LEFT of the central group facing three plant fighters on its RIGHT, with the glowing golden tunnel directly behind the gap between teams. Character order: red flag bearer, green archer, brown hammer fighter, brown orange-clad shield fighter, sunflower swordsman, rose spearman, wooden stump shield bearer. All seven full-body characters including weapons, feet and flag fully visible. No added characters, no redesign, no duplicated fighters.
Important Steam responsive crop design: scale the whole original scene down into the CENTER of the panoramic world so all seven characters' FACES lie inside the central 860x380 region of the final 3840x1240 image (x1490-2350, y430-810). Main fighter bodies and equipment can extend a little beyond this. The original left-to-right composition is retained as a compact central standoff. Outpaint the forest generously to the left and right, natural twisting roots, rocks and cyan bioluminescent mushrooms continue across the FULL panoramic width. Gold cave glow centered. Keep the top center dark with attractive quiet canopy space for Steam to overlay a separate white logo; never paint a logo into the hero. Painterly texture, rich deep dark teal greens, vivid cyan light and gold glow just like source; keep the characters' simple flat colors and thick outlines. Do not add giant foreground characters. No border or letterboxing; full bleed artwork.

## hero_safe

Use case: precise-object-edit.
Asset type: final Steam Library Hero, aspect ratio exactly 3840:1240.
Edit the supplied panoramic artwork with one precise composition change: make the entire group of seven fighters HALF its current width and height, and move that compact group UP so the characters' faces sit around 51% of the canvas height. Final fighter group width is approximately 23% of the full panoramic canvas. Center the seven-fighter standoff horizontally.
Strict safe-region target: at 3840x1240, every face is completely inside x=1490 to 2350 and y=430 to 810; best to center the faces near y=635. At a 2206x713 preview, faces should all be between x856 and1350 and y247 and466. The flag may extend above the face region. Keep every fighter's entire body, feet, flag and weapon visible. Fill their previous footprint with matching forest floor.
Preserve the exact character designs, colors, black outlines, poses, held objects and their left-to-right ordering: red mushroom flag bearer, green mushroom archer, brown hammer fighter, orange-clad brown shield fighter, sunflower swordsman, rose spearman, wooden stump shield bearer. Still four mushrooms on the left facing three plants on the right. Keep the golden tunnel directly centered behind them.
Preserve the rest of the environment, painted root arches, cyan mushrooms, golden center, quiet dark canopy above the scene. Panoramic full bleed artwork. Absolutely NO letters, NO text, NO wordmark, no borders, no added or duplicated characters. This is a safe-area correction for a responsive Steam hero, not a redesign.
