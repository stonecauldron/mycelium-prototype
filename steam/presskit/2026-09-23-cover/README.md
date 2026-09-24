# Auto Shrooms press covers

Prepared 23 September 2026. Matching landscape artwork for digital press coverage, with and without the game title.

## Ready-to-use images

All four files in `exports/` are 1920 × 1080 pixels (16:9), opaque RGB, sRGB.

- `auto-shrooms-cover-with-logo-1920x1080.png` — cover with the Auto Shrooms wordmark.
- `auto-shrooms-cover-without-logo-1920x1080.png` — clean cover for editorial layouts and custom title placement.
- The corresponding `.jpg` files are smaller sharing copies, exported at quality 95 with 4:4:4 chroma sampling.

Use the PNGs as the preferred delivery images. These are promotional illustrations, not gameplay screenshots. They contain no platform marks, wishlist CTA or tagline.

## Sources and provenance

The original approved artwork and separate logo are retained in `sources/original-artwork.png` and `sources/original-logo.png`. Both were copied from the existing Steam branding package dated 10 September 2026.

The built-in image generation tool adapted the clean artwork to the cover composition and added the supplied wordmark for the title version. Both generated sources are 1672 × 941 pixels. The final 1080p images are lightly enlarged with Lanczos resampling and have a minimal center crop to exact 16:9; they are not native 4K or print-resolution masters. The source files are flattened raster images, not layered documents.

The complete prompts used by the built-in tool are retained in `sources/cover-without-logo-prompt.txt` and `sources/cover-with-logo-prompt.txt`. Generation is not deterministic; exporting from the retained generated files is reproducible.

Run `bash export.sh` with ImageMagick installed to regenerate the four delivery images.

## Visual checks

- The seven fighters, banner, weapons and full character silhouettes remain visible in both versions.
- The title is readable against the dark upper canopy and does not cover the fighters or banner.
- The clean cover contains no game title; the in-world mushroom emblem remains on its flag.
- Final dimensions, color mode and opacity were checked after export, and both exported PNGs were visually inspected.
