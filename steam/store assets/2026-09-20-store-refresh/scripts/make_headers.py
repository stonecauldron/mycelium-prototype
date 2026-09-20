#!/usr/bin/env python3
"""Render exact store-heading typography using the game's font and paper artwork."""
import json
import pathlib
import tempfile
from zipfile import ZipFile, ZIP_DEFLATED

from make_graphics import magick, size

PACKAGE = pathlib.Path(__file__).resolve().parents[1]
RECIPE = json.loads((PACKAGE / "scripts/headers.json").read_text())
OUT = PACKAGE / "exports/headers"
PREVIEW = PACKAGE / "preview"


def main():
    OUT.mkdir(exist_ok=True)
    width, height = RECIPE["width"], RECIPE["height"]
    inset, ribbon_height = RECIPE["ribbon_inset"], RECIPE["ribbon_height"]
    ribbon_width = width - 2 * inset
    font = PACKAGE / RECIPE["font"]
    report = []
    with tempfile.TemporaryDirectory() as folder:
        temp = pathlib.Path(folder)
        source = PACKAGE / "sources/graphics/paper-ribbon.png"
        # Keep the paper's notched ends at their original proportions.
        cap_width = round(48 * ribbon_height / 100)
        for name, crop, target in [
            ("left", "48x100+0+0", f"{cap_width}x{ribbon_height}!"),
            ("middle", "1664x100+48+0", f"{ribbon_width-2*cap_width}x{ribbon_height}!"),
            ("right", "48x100+1712+0", f"{cap_width}x{ribbon_height}!"),
        ]:
            magick(source, "-crop", crop, "+repage", "-resize", target, temp / (name + ".png"))
        magick(temp / "left.png", temp / "middle.png", temp / "right.png", "+append",
               "-background", "none", "-gravity", "center", "-extent", f"{width}x{height}", temp / "ribbon.png")
        review = []
        for header in RECIPE["headers"]:
            label = temp / "text.png"
            magick("-background", "none", "-fill", RECIPE["ink"], "-font", font,
                   "-pointsize", header.get("point_size", RECIPE["point_size"]), "label:" + header["text"],
                   "-trim", "+repage", label)
            tw, th = size(label)
            assert tw <= ribbon_width - 2 * cap_width - 32
            assert th <= ribbon_height - 30
            output = OUT / (header["name"] + ".png")
            magick(temp / "ribbon.png", label, "-gravity", "center", "-composite",
                   "-colorspace", "sRGB", "-depth", "8", "-strip", "PNG32:" + str(output))
            assert size(output) == (width, height)
            report.append({**header, "file": str(output.relative_to(PACKAGE)),
                           "width": width, "height": height, "bytes": output.stat().st_size,
                           "text_bounds": [(width-tw)//2, (height-th)//2, tw, th]})
            # Review at the documented 780 logical pixel description width.
            display = temp / (header["name"] + ".png")
            magick(output, "-resize", "780x", "-background", "#1b2838", "-alpha", "remove",
                   "-alpha", "off", "-bordercolor", "#1b2838", "-border", "0x12", display)
            review.append(display)
        magick(*review, "-append", PREVIEW / "description-headers.png")
        magick(PREVIEW / "description-headers.png", "-resize", "390x", PREVIEW / "description-headers-mobile.png")
    (PACKAGE / "headers-validation.json").write_text(json.dumps(report, indent=2) + "\n")
    guide = PACKAGE / "HEADER-GUIDE.md"
    guide.write_text("# Store description headers\n\n"
        "Five 1170 × 150 PNGs with transparent outer margins, cream paper ribbons, and the game's Spicy Rice title font. "
        "Lettering and capitalization match the supplied headings.\n\n"
        "Upload these as description images, place each above its matching paragraph and loop, and use the displayed heading as its alt text. "
        "The preview sheet is for review only; upload the five individual PNGs.\n\n"
        "| Header / alt text | PNG | Matching loop |\n| --- | --- | --- |\n" +
        "".join(f"| {h['text']} | `exports/headers/{h['name']}.png` | `exports/loops/{h['loop']}.mp4` |\n" for h in RECIPE['headers']) +
        "\nEdit `scripts/headers.json` and run `python3 scripts/make_headers.py` to rebuild. "
        "The font and original paper artwork are retained under `sources/`. Rebuild the full upload archive with `python3 scripts/package.py`.\n\n"
        "Steam supports PNG description images and recommends 1170px width for high-DPI displays. "
        "[Official guidance](https://partner.steamgames.com/doc/store/page/assets).\n")
    bundle = PACKAGE / "auto-shrooms-description-headers.zip"
    with ZipFile(bundle, "w", ZIP_DEFLATED) as archive:
        for record in report:
            archive.write(PACKAGE / record["file"], record["file"])
        archive.write(guide, guide.name)
    with ZipFile(bundle) as archive:
        assert archive.testzip() is None
    print(f"Five headers rendered and bundled: {sum(h['bytes'] for h in report):,} PNG bytes")


if __name__ == "__main__":
    main()
