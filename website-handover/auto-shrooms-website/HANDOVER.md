# Auto Shrooms → cauldron.games

Prepared 24 September 2026. Start with [the visual preview](preview.html), then use the card snippet and `assets/` folder to add the game. The ZIP is the complete portable handover.

**Presskit addition:** [Game-styled presskit page](presskit-auto-shrooms.html) · [Presskit design and integration guide](PRESSKIT-HANDOVER.md) · [Public press-download ZIP](downloads/auto-shrooms-presskit.zip). The new page uses the game's Spicy Rice and Fredoka fonts, plum/sage/cream UI palette, cut-paper panels and Nursery background.

## Add the game

1. Copy `assets/auto-shrooms/` to the website's public `assets/auto-shrooms/` directory. In a framework project, this may be under `public/`.
2. Paste [snippets/game-card.html](snippets/game-card.html) inside the existing `#games .game-grid`, before Wageslave. Both games then occupy the site's existing two-column layout; below 52rem they stack.
3. Keep the website's existing stylesheet. The snippet uses its actual `.game-card`, `.game-meta`, `.demo-button` and `.wishlist-button` classes; no new CSS or JavaScript is required.
4. Confirm the artwork, Steam link and trailer work from the deployed asset paths. Check the card at desktop and narrow mobile widths.

**Public CTA:** “Wishlist on Steam” links to the [main game, app 4963670](https://store.steampowered.com/app/4963670/Auto_Shrooms/). The gold secondary button opens the supplied YouTube trailer. The `demo-button` CSS class gives the primary button the same blue appearance as Wageslave's Steam button; the class name does not imply demo availability.

**Demo availability:** [cauldron.itch.io/auto-shrooms](https://cauldron.itch.io/auto-shrooms) currently asks logged-out visitors for a password. The ready-to-paste card has no public play link. Once the page is public and its build works, the secondary button can be changed to “Play the web demo”. No playable web build or iframe is included in this marketing handover.

## Website fit

The live [homepage](https://cauldron.games/) currently has a mailing-list panel, Games, About, and a studio footer. Its single Wageslave card has 1920 × 1080 artwork, five short paragraphs, a status line, and blue/gold action buttons. The supplied Auto Shrooms card follows that format. The cover already contains the game title, matching the existing image-in-heading pattern.

For the homepage card, retain the parchment background, thin blue-grey borders, Jacquard 12 headings and IBM Plex Mono body text. The complete current studio stylesheet is copied to `preview/cauldron-games.css` for that preview only. It imports Google Fonts; offline previews use its font fallbacks. The separate Auto Shrooms presskit now has its own game-inspired design and self-hosted game fonts, as requested; see PRESSKIT-HANDOVER.md.

Recommended position: Auto Shrooms first, Wageslave second. This is a suggested editorial choice, not a live-site change.

## Included assets

All paths below are relative to this folder. Exact sizes, SHA-256 hashes, source paths and conversions are in [asset-manifest.json](asset-manifest.json).

| File | Dimensions / format | Use |
| --- | --- | --- |
| `assets/auto-shrooms/splash-art-640.webp` | 640 × 360 | Small responsive game card |
| `assets/auto-shrooms/splash-art-960.webp` | 960 × 540 | Standard/high-density game card |
| `assets/auto-shrooms/splash-art-1920.webp` | 1920 × 1080 | Largest responsive card/detail image |
| `assets/auto-shrooms/splash-art.jpg` | 1920 × 1080 | JPEG fallback and social share image |
| `assets/auto-shrooms/cover-clean.webp` | 1920 × 1080 | Optional cover with separate title placement |
| `assets/auto-shrooms/logo.png` | 1280 × 179, transparent PNG | Separate wordmark |
| `assets/auto-shrooms/screenshots/*.jpg` | Six 1920 × 1080 JPGs | Full-size gallery / press screenshots |
| `assets/auto-shrooms/screenshots/*-960.webp` | Six 960 × 540 WebPs | Gallery thumbnails |
| `press/auto-shrooms-cover-with-logo.png` | 1920 × 1080 PNG | Original delivery cover |
| `press/auto-shrooms-cover-without-logo.png` | 1920 × 1080 PNG | Original delivery clean cover |
| `press/auto-shrooms-trailer-1080p60.mp4` | 1920 × 1080, 60 fps, 32 seconds | Original high-quality trailer for press/upload |

The homepage needs only `splash-art*`; its trailer button opens YouTube. The remaining files support a future detail page, press page, or editorial download. Uploading them does not cause them to download in a visitor's browser unless referenced.

## Copy, gallery and media

[COPY.md](COPY.md) contains paste-ready card copy, a factsheet, longer description, features and metadata. [content.json](content.json) provides the same homepage copy, links and gallery alt text as structured data.

Suggested gallery order: battle action → War Chamber → Nursery → Training → battle approach → day summary. All six are real game captures from the September 20 media production; the cover illustrations are promotional art. The gallery order in `content.json` and the preview is intentional even though the original screenshot numbering is retained.

Keep the cover at its complete 16:9 aspect ratio so the wordmark, banner and fighters remain visible. Use explicit width and height, responsive images and `height: auto`. The homepage snippet lazy-loads the image because Games sits below the mailing-list panel. If used as an above-the-fold hero, remove lazy loading and add `fetchpriority="high"`; the preview does this because its card is near the top.

The trailer is the supplied [YouTube video](https://www.youtube.com/watch?v=RZcBiuLZ1qw). The page and [snippets/trailer.html](snippets/trailer.html) use its iframe with no autoplay and an adjacent YouTube link. The homepage card links to the same video. No local video file is referenced by the webpage. The original 60 fps MP4 remains in the downloadable press bundle.

## Presskit integration

The current [presskit.html](https://cauldron.games/presskit.html) is a Wageslave page, including a Wageslave asset-folder link. Preserve it. The supplied `presskit-auto-shrooms.html` is the separate Auto Shrooms page; copy it with its referenced assets to the website root, use the configured Dropbox link described in PRESSKIT-HANDOVER.md. Its route is proposed and has not been published. The page and public factsheet are generated from `presskit-content.json`.

This handover ZIP contains internal implementation notes and previews. The included `downloads/auto-shrooms-presskit.zip` is the public press download: two covers, transparent logo, weaponless Child and Adult sprites, 21 weapon sprites, six full-size screenshots, original trailer and factsheet. Both page download buttons use the owner-supplied Dropbox folder URL stored in `links.presskit_dropbox`; this local ZIP remains available for updating that folder. It contains no internal implementation notes or commercial UI textures.

## Asset provenance

- **Covers:** `steam/presskit/2026-09-23-cover/exports/`. Existing approved branding adapted with image generation in the prior production; this handover adds only proportional downscaling and file encoding. The original delivery covers were lightly enlarged from 1672 × 941 generated sources; they are not native 4K or print masters.
- **Units:** Two transparent 768 × 768 Godot renders: weaponless Child and Adult, with default game tints and fixed idle poses. Recorded in `character-renders.json`; download only.
- **Weapons:** 21 original transparent PNG sprites from `assets/weapons/`, copied without modification at native resolution; download only.
- **Logo:** existing transparent, tightly framed export from `steam/store assets/2026-09-10/upload/library/library_logo_transparent_en.png`. No new logo or font reconstruction.
- **Screenshots and trailer:** `steam/store assets/2026-09-20-store-refresh/exports/`. Revision 8 gameplay media; no synthetic gameplay, new overlays, recapture or gameplay changes in this handover.
- **Trailer audio:** existing Battle music, credited in-game to Andres D. Bubenhofer, plus game effects. The original press-download MP4 is copied unchanged.
- **Website reference:** [homepage](https://cauldron.games/), [stylesheet](https://cauldron.games/styles.css), and [Wageslave presskit](https://cauldron.games/presskit.html), inspected on 24 September 2026.

## Rebuild and verification

From this folder within the original repository, run `python3 prepare.py` with ImageMagick and FFprobe installed. It copies existing assets, writes WebP derivatives, builds the previews, refreshes the manifest and packages both ZIPs. It uses the retained stylesheet snapshot and needs no network access. Character PNGs are reused; their separate Godot rebuild command is in PRESSKIT-HANDOVER.md.

See [verification.json](verification.json) for current asset, archive, media and browser checks. The Dropbox URL is configured; confirm its folder contents and visitor access before publication. The website itself has not been edited or published.
