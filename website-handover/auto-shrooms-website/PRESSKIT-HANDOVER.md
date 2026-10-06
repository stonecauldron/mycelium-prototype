# Auto Shrooms presskit page

Open [presskit-auto-shrooms.html](presskit-auto-shrooms.html) for the reference page. It uses the game's Spicy Rice and Fredoka fonts, Nursery art and UI palette. The page has no character gallery. Unit and weapon sprites are included only in the downloadable presskit.

## Dropbox download link

Both presskit buttons now open the Dropbox folder link supplied by the owner. Its complete URL is stored in `links.presskit_dropbox` in [presskit-content.json](presskit-content.json), including the supplied sharing parameters and `dl=0` folder-view behaviour.

To change the destination later, edit that field and run `python3 prepare.py` from this handover folder within the game repository. Both buttons update together. They are ordinary HTTPS links, without an HTML `download` attribute. Clearing the field returns both controls to their disabled, coming-soon state.

The local [public press ZIP](downloads/auto-shrooms-presskit.zip) remains included for uploading or updating the Dropbox folder. This change connects the supplied link; it does not upload files or change Dropbox sharing permissions.

## Files to give the website developer

| File / directory | Purpose |
| --- | --- |
| `presskit-auto-shrooms.html` | Responsive page with YouTube trailer and configured Dropbox download |
| `assets/auto-shrooms/presskit.css` | Styles scoped beneath `.shrooms-presskit` |
| `assets/auto-shrooms/fonts/` | Exact game fonts with OFL notices |
| `assets/auto-shrooms/nursery-background.webp` | Game Nursery backdrop |
| Other `assets/auto-shrooms/` media | Cover previews, logo and screenshot gallery |
| `press/characters/` | Weaponless Child and Adult PNGs, download only |
| `press/weapons/` | 21 original weapon PNGs, download only |
| `press/` | Cover PNGs, original trailer and public factsheet |
| `downloads/auto-shrooms-presskit.zip` | 34-file public press bundle to upload to Dropbox |
| `presskit-content.json` | Facts, copy, links, sprite selection and Dropbox URL |
| `templates/presskit.html` | Page template for `prepare.py` |
| `scripts/render_characters.tscn` | Optional Godot export scene for the two weaponless units |

For the website, copy the HTML, `assets/`, `press/FACTSHEET.md` and the two cover PNGs referenced by the artwork links. The video is hosted on YouTube and the complete download is hosted on Dropbox, so `press/characters/`, `press/weapons/`, the local trailer MP4 and `downloads/` do not need to be hosted on your web server. They remain part of the public ZIP.

The proposed route is `/presskit-auto-shrooms.html`. Preserve the existing Wageslave presskit at `/presskit.html` and add a separate Auto Shrooms navigation link. Nothing has been published.

## Typography

The authoritative source is `assets/themes/default.tres` in the game repository.

| Use | Typeface | Website values | Game source |
| --- | --- | --- | --- |
| Page title, section titles, feature headings | **Spicy Rice Regular** | Weight 400; hero 48–91px; section titles 27–42px; line-height 1.12 | `assets/fonts/SpicyRice-Regular.ttf`; `TitleLabel`, `PageTitleLabel`, `SectionTitleLabel` |
| Body, facts, captions | **Fredoka Variable** | Body 18px / 1.6; weight 450; smaller labels 14–16px | `assets/fonts/Fredoka-VariableFont_wdth,wght.ttf`; body's authored weight 450 |
| Navigation and buttons | **Fredoka Variable** | Weights 500–600; minimum control height 48px | Game button weight 600, metadata weight 500 |

Both fonts are copied byte-for-byte from the game, including all glyphs. Fredoka's supplied axes are weight 300–700 and width 75–125; the page uses normal width. The site uses local `@font-face` declarations, `font-display: swap`, and font preload links. There are no Google Fonts requests. The original files total about 218 KiB, so no font conversion dependency is needed.

Retain both copyright/license notices when distributing the fonts. Official sources: [Spicy Rice OFL](https://raw.githubusercontent.com/google/fonts/main/ofl/spicyrice/OFL.txt) and [Fredoka OFL](https://raw.githubusercontent.com/google/fonts/main/ofl/fredoka/OFL.txt). These fonts are implementation assets; the public press-download ZIP contains the finished logo rather than font files.

## Colour tokens

| CSS token | Hex | Source and use |
| --- | --- | --- |
| `--plum` | `#4B2C34` | Sampled from the game's `title/title 3 6.png`; cut-paper title ribbons |
| `--sage` | `#779977` | Sampled from `label/label 9.png` and `title/title 2 9.png`; primary buttons and feature accents |
| `--paper` | `#DDDDBB` | Sampled from the existing media package's `paper-panel.png`; factsheet and content panels |
| `--cream` | `#EBE8DE` | `PageTitleLabel` colour in the game theme; text against the dark cave and ribbons |
| `--ink` | `#2E2924` | Rounded 8-bit form of `PaperStyles.INK`; body text on paper |
| `--ink-muted` | `#524D42` | Rounded 8-bit form of `PaperStyles.INK_MUTED`; labels and captions on paper |
| `--cave` | `#0B1528` | Web interpretation of the Nursery's dark blue background; long-page base |
| `--gold` | `#EDC375` | Supporting web accent for the short tagline and keyboard focus |

The header uses a darker blue backing; buttons use dark ink for readable contrast on sage. Title ribbons use cream on plum. Keep long passages on cream paper rather than overlaying them directly on detailed artwork. The exact game palette is the starting point; these layout-specific background/focus choices support a readable press page.

## Layout and video

- The hero uses Nursery art, a Spicy Rice title, wishlist action and presskit download control.
- Paper panels contain the factsheet, overview, artwork and studio contact. Plum ribbons and sage buttons follow the game's UI palette.
- The main content has an overview, YouTube trailer, six screenshots, artwork/logo downloads, press download and contact. There is no character or weapon gallery.
- The content stacks at 760px; screenshot and artwork galleries become one column below 430px. Native headings, image alt text and visible keyboard focus are retained.
- The trailer iframe uses the supplied video ID **RZcBiuLZ1qw**, at `https://www.youtube.com/embed/RZcBiuLZ1qw`, with an accessible title, fullscreen support and no autoplay. It is 16:9 with a minimum 200px content height on narrow screens. `referrerpolicy="strict-origin-when-cross-origin"` retains the origin required by YouTube. The adjacent “Watch on YouTube” link opens the same video.
- The iframe loads normally rather than lazily because lazy iframe loading did not initialize in the in-app preview. Playback still requires user interaction.
- `snippets/trailer.html` and the homepage card use the same YouTube video. No self-hosted video player or local MP4 link remains in either web preview. The original 1080p60 MP4 is retained only as a press-download asset.

Serve the page over HTTP(S), including for local preview; file URLs may prevent embedded playback. If the site has a Content Security Policy, allow `https://www.youtube.com` in `frame-src`. Embed behaviour follows [YouTube's official player documentation](https://developers.google.com/youtube/player_parameters).

## Press information

`presskit-content.json` provides the editable facts, descriptions, features, studio and links. The factsheet is generated from it. Press contact: Pedro Caldeira, `pedro@cauldron.games`, as used on the studio's public site on 24 September 2026.

Steam lists release TBA and Windows/macOS support. Exact date and price are unannounced in this handover. The itch.io page was password-protected, so it has no public play button. No invented awards, history, quotes or review-key promises are included.

## Download-only sprites

**Units:** `characters/child.png` and `characters/adult.png` are transparent 768 × 768 renders of the real Child and Adult scenes, without weapons, using their default game colours and a fixed idle pose. Ground shadows are hidden. Each is framed independently with approximately 48px padding; their relative scale is not an in-game size comparison. Both are renders of existing raster art, not newly drawn high-resolution masters. All earlier equipped, enemy and flag-bearer cutouts have been removed from this delivery.

**Weapons:** `weapons/` contains 21 standalone PNG sprites copied byte-for-byte from the original weapon art, with their original dimensions and transparency. Includes the five basic weapons and the advanced/combined weapons, including Sword and Shield, Spear and Shield, and Mace and Shield artwork. These are the original sprites rather than the 64px UI icons. The factsheet lists every filename, display name and pixel size.

`character-renders.json` records the two unit renders; `asset-manifest.json` records the delivered files, hashes and sources. Neither units nor weapons are referenced by the webpage's image tags or exposed through individual webpage downloads.

Normal `prepare.py` rebuilds reuse the finished unit PNGs and copy the weapon originals. To re-render the two units after game artwork changes, run from the repository root:

```sh
godot --path . --rendering-method gl_compatibility --rendering-driver opengl3 --windowed --resolution 320x240 --audio-driver Dummy --quit-after 240 handover/auto-shrooms-website/scripts/render_characters.tscn
python3 handover/auto-shrooms-website/prepare.py
```

Use an unsandboxed Godot launch on macOS, as required by the repository's agent guidance. The export scene does not enter gameplay or modify source artwork.

## Public press ZIP

The 34-file ZIP contains:

1. A factsheet with copy, screenshot captions and sprite inventory.
2. Two 1920 × 1080 promotional cover PNGs, with and without the title.
3. The transparent 1280 × 179 logo.
4. Six 1920 × 1080 gameplay JPGs.
5. The original 32-second 1080p60 trailer.
6. The weaponless Child and Adult PNGs.
7. All 21 weapon PNGs.

Implementation notes, fonts, CSS, Nursery background and scripts stay in the separate website handover ZIP. Covers remain the previous promotional illustrations; provenance is in HANDOVER.md.

## Rebuild and deployment

Run `python3 prepare.py` in this folder within the game repository, with ImageMagick and FFprobe installed. It refreshes copied assets, factsheet, public ZIP, page and complete handover ZIP without network access. The original repository is needed to rebuild; the finished page and assets are portable.

The supplied Dropbox URL is configured. Before launch, confirm its folder contents and visitor access, check YouTube playback on the final domain, verify artwork/gallery links, and add a canonical URL once the route is final. The Open Graph share image uses its planned absolute cauldron.games URL. See `verification.json` for completed checks and any preview limitations.
