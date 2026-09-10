#!/usr/bin/env bash
set -euo pipefail

# Re-export approved artwork at Steam's exact upload sizes.
asset_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$asset_dir"
mkdir -p upload/store/screenshots upload/library preview

export_png() {
  magick "$1" -filter Lanczos -resize "$2^" -gravity center -extent "$2" \
    -colorspace sRGB -alpha off -depth 8 "PNG24:$3"
}

export_png sources/header_generated.png 920x430 upload/store/store_capsule_header_en.png
export_png sources/main_generated.png 1232x706 upload/store/store_capsule_main_en.png
export_png sources/small_generated.png 462x174 upload/store/store_capsule_Small_en.png
export_png sources/vertical_generated.png 748x896 upload/store/store_capsule_vertical_en.png
export_png sources/page_background_generated.png 1438x810 upload/store/store_page_background_en.png
export_png sources/library_generated.png 600x900 upload/library/library_capsule_en.png
export_png sources/hero_final_generated.png 3840x1240 upload/library/library_hero_en.png
cp upload/store/store_capsule_header_en.png upload/library/library_header_en.png

# Preserve the supplied wordmark pixels and alpha, remove transparent padding,
# then scale proportionally to the required 1280 px width (result: 1280 x 179).
magick sources/base_logo.png -trim +repage -filter Lanczos -resize 1280x \
  -colorspace sRGB -depth 8 PNG32:upload/library/library_logo_transparent_en.png

# These are the repository's existing gameplay captures, not generated art.
for screenshot in ../screenshots/*.png; do
  export_png "$screenshot" 1920x1080 "upload/store/screenshots/$(basename "$screenshot")"
done

magick upload/store/store_capsule_Small_en.png -filter Lanczos -resize 120x45! preview/small_120x45.png
magick upload/store/store_capsule_Small_en.png -filter Lanczos -resize 184x69! preview/small_184x69.png
magick upload/library/library_hero_en.png -gravity center -crop 860x380+0+0 +repage preview/hero_center_safe_area.png

magick montage \
  -font /System/Library/Fonts/Helvetica.ttc -pointsize 18 -fill '#eae9df' \
  -background '#15201f' -label '%f\n%wx%h' \
  upload/store/store_capsule_main_en.png \
  upload/store/store_capsule_vertical_en.png \
  upload/library/library_capsule_en.png \
  upload/store/store_capsule_header_en.png \
  upload/library/library_header_en.png \
  upload/store/store_capsule_Small_en.png \
  upload/library/library_hero_en.png \
  upload/library/library_logo_transparent_en.png \
  upload/store/store_page_background_en.png \
  -thumbnail '580x360>' -tile 3x -geometry 600x400+16+20 \
  preview/contact_sheet.jpg

magick identify -format '%f: %wx%h %[channels] opaque=%[opaque]\n' \
  upload/store/*.png upload/library/*.png upload/store/screenshots/*.png
