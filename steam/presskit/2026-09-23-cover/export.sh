#!/usr/bin/env bash
set -euo pipefail

# Reproduce the final press exports from the retained generated source images.
asset_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$asset_dir"
mkdir -p exports

for variant in with-logo without-logo; do
  magick "sources/cover-${variant}-generated.png" \
    -filter Lanczos -resize '1920x1080^' -gravity center -extent 1920x1080 \
    -colorspace sRGB -alpha off -depth 8 -define png:compression-level=9 \
    "PNG24:exports/auto-shrooms-cover-${variant}-1920x1080.png"
  magick "exports/auto-shrooms-cover-${variant}-1920x1080.png" \
    -colorspace sRGB -sampling-factor 4:4:4 -quality 95 \
    "exports/auto-shrooms-cover-${variant}-1920x1080.jpg"
done

magick identify -format '%f: %wx%h %[colorspace] %[channels] opaque=%[opaque]\n' exports/*
