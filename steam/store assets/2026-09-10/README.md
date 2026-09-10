# Auto Shrooms — Steam Store and Library assets

Created 10 September 2026 from the supplied `base_artwork.png` and `base_logo.png`.

The `upload/` folder contains the four required Store capsules, four required Library assets, an ambient Store Page Background, and five existing gameplay screenshots exported at 1920 × 1080. Upload these individual images to Steam. The prior asset set remains in its original location.

## Store uploads

- Header Capsule: `upload/store/store_capsule_header_en.png` — 920 × 430.
- Small Capsule: `upload/store/store_capsule_Small_en.png` — 462 × 174.
- Main Capsule: `upload/store/store_capsule_main_en.png` — 1232 × 706.
- Vertical Capsule: `upload/store/store_capsule_vertical_en.png` — 748 × 896.
- Page Background: `upload/store/store_page_background_en.png` — 1438 × 810. Ambient forest artwork without characters, equipment, or text; subdued colors and lighting keep it quiet behind the page content. Steam applies its own blue tint and edge fade after upload.
- Screenshots: `upload/store/screenshots/1.png` through `5.png` — 1920 × 1080 each. These are existing gameplay captures from the repository, resized with negligible edge cropping to exact 16:9. No gameplay imagery was generated.

## Library uploads

- Library Capsule: `upload/library/library_capsule_en.png` — 600 × 900.
- Library Header: `upload/library/library_header_en.png` — 920 × 430; same image as the Store Header.
- Library Hero: `upload/library/library_hero_en.png` — 3840 × 1240, no text.
- Library Logo: `upload/library/library_logo_transparent_en.png` — 1280 × 179, transparent PNG. Exported directly from the original wordmark with its transparent padding trimmed; proportions and alpha preserved.

In Steam's Library logo placement tool, choose **centered top**. The hero keeps the fighters centered and the upper canopy quiet for the separate logo. The documented central 860 × 380 crop is provided in the preview folder for inspection.

## Art direction and validation

The capsule adaptations preserve the opposing mushroom/plant teams, seven character identities, central golden tunnel, dark root canopy, and cyan mushrooms. Portraits reflow the title into two lines and extend the environment vertically. The Small Capsule removes all fighters and equipment, using a large title over the forest; legibility was checked at Steam's 120 × 45 and 184 × 69 display sizes.

All upload PNG dimensions were verified. Capsules, hero, page background, and screenshots are opaque RGB; only the Library Logo has transparency. Final pixel exports use Lanczos resampling. The hero is enlarged from its generated master to Steam's required 3840 × 1240 size. Capsule artwork, title placement, and the ambient page background were adapted with the built-in image generation tool; the standalone Library Logo uses the actual supplied PNG.

`preview/contact_sheet.jpg` shows the eight branding assets and the page background. Original inputs and generated masters are retained in `sources/`. `PROMPTS.md` records the generation prompts. To reproduce exports on this Mac with ImageMagick installed, run `bash export_assets.sh` from this directory.

Bundle artwork, community icons, and event artwork are outside this Store/Library asset set. Files are prepared for upload; nothing has been uploaded to Steam.

## Specifications checked

- [Steam graphical assets overview](https://partner.steamgames.com/doc/store/assets)
- [Store graphical assets](https://partner.steamgames.com/doc/store/assets/standard)
- [Library assets](https://partner.steamgames.com/doc/store/assets/libraryassets)
