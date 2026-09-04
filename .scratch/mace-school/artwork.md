# Mace-school artwork provenance

Generated with the built-in Imagegen tool on 2026-09-04. Existing weapon sprites were supplied as style references. Final PNGs are copied unmodified from the generated outputs; sizing and grip placement happen in Godot scenes.

## Final assets

- `assets/weapons/warhammer/warhammer.png` — generated source `/Users/cauldron/.codex/generated_images/01a06121-1b71-7080-bf18-933ad84d742a/exec-30c3fa49-8a3c-4a76-9044-2386ebd83d5c.png`.
- `assets/weapons/polehammer/polehammer.png` — generated source `/Users/cauldron/.codex/generated_images/01a06121-1b71-7080-bf18-933ad84d742a/exec-737c59c3-e79a-4212-9a47-fd8063704587.png`.
- `assets/weapons/sling/sling.png` — Y-shaped slingshot revision; generated source `/Users/cauldron/.codex/generated_images/01a06121-1b71-7080-bf18-933ad84d742a/exec-411c5644-af2a-4ea0-90c3-cef8ce9dd952.png`.
- `assets/weapons/sling/stone.png` — generated source `/Users/cauldron/.codex/generated_images/01a06121-1b71-7080-bf18-933ad84d742a/exec-e78ad8f5-0e3c-4f0a-a422-b8f2a161a68f.png`.
- `assets/base/composting_bin/composting_bin.png` — generated source `/Users/cauldron/.codex/generated_images/01a06121-1b71-7080-bf18-933ad84d742a/exec-7a64760a-ac75-458f-bddb-35e1d39d9de9.png`.
- `assets/weapons/sword_and_shield/sword_and_shield.png` — generated source `/Users/cauldron/.codex/generated_images/01a06121-1b71-7080-bf18-933ad84d742a/exec-cf67e031-a04c-4a93-8c6d-407c0d62eb01.png`.
- `assets/weapons/mace_and_shield/mace_and_shield.png` — generated source `/Users/cauldron/.codex/generated_images/01a06121-1b71-7080-bf18-933ad84d742a/exec-87307760-ba5b-48be-8e32-edc629b62abc.png`.
- `assets/weapons/spear_and_shield/spear_and_shield.png` — generated source `/Users/cauldron/.codex/generated_images/01a06121-1b71-7080-bf18-933ad84d742a/exec-cefb38df-c225-48a8-bae0-6fd3c705af84.png`.

## Prompt set

### warhammer

Use case: stylized-concept. Asset type: production sprite for a hand-drawn 2D game, not a mockup. Match the supplied game's very simple thick near-black hand-drawn outlines, flat muted warm-gray metal and dark desaturated green handles. No gradients, highlights, texture, shadows, text, frame, hands, or character. Genuine transparent background, no checkerboard drawn into image. One centered isolated item, upright, fully visible with modest transparent padding. Keep forms exceptionally simple and readable at 50–100 pixels.
Using the provided great hammer as a style reference, create a DIFFERENT one-handed Warhammer: upright medium-length dark green handle, compact rectangular warm gray hammer head at top, with a small squared rear peen. The striking face points left. Distinct from the reference's enormous two-handed rectangular slab. Entire item vertical in square canvas.

References: `assets/weapons/great_hammer/greathammer.png`.

### polehammer

Use case: stylized-concept. Asset type: production sprite for a hand-drawn 2D game, not a mockup. Match the supplied game's very simple thick near-black hand-drawn outlines, flat muted warm-gray metal and dark desaturated green handles. No gradients, highlights, texture, shadows, text, frame, hands, or character. Genuine transparent background, no checkerboard drawn into image. One centered isolated item, upright, fully visible with modest transparent padding. Keep forms exceptionally simple and readable at 50–100 pixels.
Using the supplied halberd as a style/length reference and great hammer as metal style reference, create a Polehammer: straight long slender dark green pole ending in a compact horizontal block-headed warm-gray hammer. Small blunt rear peen; NO axe blade, NO spear tip. Long shaft occupies lower 75% of height. Vertical, handle end at bottom center.

References: `assets/weapons/halberd/halberd.png`, `assets/weapons/great_hammer/greathammer.png`.

### sling — original, superseded by the Y-shaped slingshot below

Use case: stylized-concept. Asset type: production sprite for a hand-drawn 2D game, not a mockup. Match the supplied game's very simple thick near-black hand-drawn outlines, flat muted warm-gray metal and dark desaturated green handles. No gradients, highlights, texture, shadows, text, frame, hands, or character. Genuine transparent background, no checkerboard drawn into image. One centered isolated item, upright, fully visible with modest transparent padding. Keep forms exceptionally simple and readable at 50–100 pixels.
Using the bow/mace images as line style and palette references, create a primitive hand sling, NOT a slingshot: two thick dark green cord loops connect to a small warm-gray oval pouch, holding one simple gray stone. Cords form a narrow inverted U with grip at bottom and pouch at top. Clear simple silhouette, upright compact hand-held item. No wood Y frame.

References: `assets/weapons/bow/bow.png`, `assets/weapons/mace/mace.png`.

### sling_stone

Use case: stylized-concept. Asset type: production sprite for a hand-drawn 2D game, not a mockup. Match the supplied game's very simple thick near-black hand-drawn outlines, flat muted warm-gray metal and dark desaturated green handles. No gradients, highlights, texture, shadows, text, frame, hands, or character. Genuine transparent background, no checkerboard drawn into image. One centered isolated item, upright, fully visible with modest transparent padding. Keep forms exceptionally simple and readable at 50–100 pixels.
Using the mace as a flat color and outline reference, create one small rounded irregular stone projectile. A single simple warm-gray pebble with thick near-black outline, no internal details. Centered, fills about 70% of square canvas. No weapon, no handle.

References: `assets/weapons/mace/mace.png`.

### compost_bin

Use case: stylized-concept. Asset type: production sprite for a hand-drawn 2D game, not a mockup. Match the supplied game's very simple thick near-black hand-drawn outlines, flat muted warm-gray metal and dark desaturated green handles. No gradients, highlights, texture, shadows, text, frame, hands, or character. Genuine transparent background, no checkerboard drawn into image. One centered isolated item, upright, fully visible with modest transparent padding. Keep forms exceptionally simple and readable at 50–100 pixels.
Using supplied game equipment as visual style reference, create one open-topped squat wooden compost bin viewed almost straight-on, just enough top-down view to show dark compost inside. Simple dark desaturated green wood slats with near-black thick outlines, warm-gray rim, two small mushroom scraps in the opening. No lid, no wheels, no text or skull, no handles, no ground/shadow. Clearly a bin, not a cocoon. Centered square canvas, full silhouette, suits a paper-styled mushroom game UI.

References: `assets/weapons/bow/bow.png`, `assets/weapons/great_hammer/greathammer.png`.

### polehammer_fixed

Edit this production game sprite to remove the entire baked checkerboard backdrop, making every background pixel genuinely transparent with alpha. Preserve the polehammer exactly: its silhouette, colors, linework, proportions, and upright orientation. Keep the weapon opaque. No checkerboard, no white background, no shadow. Output one isolated polehammer on genuine transparency.

References: `/Users/cauldron/.codex/generated_images/01a06121-1b71-7080-bf18-933ad84d742a/exec-d5e1ecc7-887a-49b5-ad98-1c9360f0403c.png`.

### sword_and_shield

Create one square transparent inventory icon for "sword and shield" in this hand-drawn 2D game's exact simple style. Use both supplied references faithfully, preserving the sword's shape and the shield's flat warm-gray fill, muted dark-green handle, and thick near-black outlines. Arrange the shield on the lower left and the upright sword on the right, slightly overlapping with the sword in front. Both silhouettes should remain distinct. No person, hand, text, frame, gradients, effects, highlights, or cast shadows. Keep the entire pair inside the canvas with modest padding. This is a small readable inventory icon, not a scene. Genuine transparent background with alpha, never a drawn checkerboard.

References: `/Users/cauldron/Git/mycelium-prototype/assets/weapons/sword/sword.png`, `/Users/cauldron/Git/mycelium-prototype/assets/weapons/shield/shield.png`.

### mace_and_shield

Create one square transparent inventory icon for "mace and shield" in this hand-drawn 2D game's exact simple style. Use both supplied references faithfully, preserving the mace's shape and the shield's flat warm-gray fill, muted dark-green handle, and thick near-black outlines. Arrange the shield on the lower left and the upright mace on the right, slightly overlapping with the mace in front. Both silhouettes should remain distinct. No person, hand, text, frame, gradients, effects, highlights, or cast shadows. Keep the entire pair inside the canvas with modest padding. This is a small readable inventory icon, not a scene. Genuine transparent background with alpha, never a drawn checkerboard.

References: `/Users/cauldron/Git/mycelium-prototype/assets/weapons/mace/mace.png`, `/Users/cauldron/Git/mycelium-prototype/assets/weapons/shield/shield.png`.

### spear_and_shield

Create one square transparent inventory icon for "spear and shield" in this hand-drawn 2D game's exact simple style. Use both supplied references faithfully, preserving the spear's shape and the shield's flat warm-gray fill, muted dark-green handle, and thick near-black outlines. Arrange the shield on the lower left and the upright spear on the right, slightly overlapping with the spear in front. Both silhouettes should remain distinct. No person, hand, text, frame, gradients, effects, highlights, or cast shadows. Keep the entire pair inside the canvas with modest padding. This is a small readable inventory icon, not a scene. Genuine transparent background with alpha, never a drawn checkerboard.

References: `/Users/cauldron/Git/mycelium-prototype/assets/weapons/spear/spear.png`, `/Users/cauldron/Git/mycelium-prototype/assets/weapons/shield/shield.png`.

The first Polehammer output had a baked checkerboard background; the background-extraction edit replaced it with the final alpha PNG.

## User-requested visual revision — 2026-09-04

The Warhammer held sprite is horizontally flipped with Godot's `Sprite2D.flip_h`; the original PNG, grip, and attack behavior are unchanged. The Sling's icon and held art now use a Y-shaped slingshot. Its name, combat stats, stone projectile, and trajectory are unchanged. Generated using the built-in Imagegen tool, not the fallback CLI. The previous Sling PNG remains available at its original generated-image source.

### slingshot revision prompt

Use case: precise-object-edit.
Asset type: isolated production weapon sprite and matching inventory icon for a hand-drawn 2D game.
Input images: Image 1 is the existing sling to replace. Image 2 is the bow as a supporting style and palette reference.
Primary request: replace the loop-and-cord sling with a classic, unmistakable Y-shaped slingshot. One upright solid handle splits into two sturdy arms forming a clear Y; a simple elastic band joins the fork tips with a small warm-gray pouch at its center. No long dangling loop, no bow shape, no extra stone floating outside it.
Style: match the game's very simple thick near-black hand-drawn outlines, flat muted dark desaturated-green frame, and flat warm-gray band/pouch. Solid color fills only; no shading, gradients, highlights, surface texture, or fine decorative details.
Composition: one centered upright slingshot, handle pointing straight down, fully visible with modest even padding. Aim for compact proportions: fork about half the object's total height, a straight easily gripped lower handle. It must read clearly at 60–90 pixels tall.
Scene/backdrop: genuine transparent background with alpha, including the spaces between the fork and band. Do not draw a checkerboard or any background.
Constraints: preserve the visual style and palette of the references, changing the weapon silhouette to the requested Y-shaped slingshot. No character, hands, text, logo, frame, shadow, or additional object.
