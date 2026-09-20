#!/usr/bin/env python3
"""Rebuild paper captions and the capsule end card from retained game assets."""
import pathlib
import subprocess
import tempfile

PACKAGE = pathlib.Path(__file__).resolve().parents[1]
GRAPHICS = PACKAGE / "sources/graphics"
TITLE_FONT = PACKAGE / "sources/fonts/SpicyRice-Regular.ttf"
CTA_FONT = PACKAGE / "sources/fonts/Fredoka-SemiBold.ttf"
INK = "#2e2924"
CREAM = "#fff3cf"


def magick(*args):
    subprocess.run(["magick", *map(str, args)], check=True)


def size(path):
    return tuple(map(int, subprocess.check_output(
        ["magick", "identify", "-format", "%w %h", str(path)], text=True).split()))


def text(name, value, pointsize, font=TITLE_FONT, fill=CREAM):
    path = GRAPHICS / (name + ".png")
    magick("-background", "none", "-fill", fill, "-font", font, "-pointsize", pointsize,
           "label:" + value, "-trim", "+repage", "-bordercolor", "none", "-border", "4x4", path)
    return path


def paper_caption(name, value, pointsize):
    # Preserve the ribbon's cut-paper ends instead of squeezing them horizontally.
    with tempfile.TemporaryDirectory() as folder:
        temp = pathlib.Path(folder)
        label = text(name, value, pointsize, fill=INK)
        width, height = size(label)
        target_height = height + 38
        target_width = max(width + 100, 295)
        mid_width = round(target_width * 100 / target_height) - 96
        source = GRAPHICS / "paper-ribbon.png"
        for part, crop, resize in [("left", "48x100+0+0", None),
                                   ("middle", "1664x100+48+0", f"{mid_width}x100!"),
                                   ("right", "48x100+1712+0", None)]:
            args = [source, "-crop", crop, "+repage"]
            if resize:
                args += ["-resize", resize]
            magick(*args, temp / (part + ".png"))
        magick(temp / "left.png", temp / "middle.png", temp / "right.png", "+append",
               "-resize", f"{target_width}x{target_height}!", "+repage", label,
               "-gravity", "center", "-composite", label)


def blurred_capsule_background(destination, width, height):
    # Use the same colored artwork and dimming in both aspect ratios.
    magick(GRAPHICS / "capsule.png", "-crop", "1232x450+0+256", "+repage",
           "-resize", f"{width}x{height}^", "-gravity", "center",
           "-extent", f"{width}x{height}", "-blur", "0x32",
           "-evaluate", "Multiply", "0.32", destination)


def end_card():
    tagline = text("tagline", "Fungus Vult!", 76)
    wishlist = text("wishlist", "Wishlist on Steam", 76, font=CTA_FONT)
    legal = text("steam-attribution", "©2026 Valve Corporation. Steam and the Steam logo are trademarks and/or registered trademarks of Valve Corporation in the U.S. and/or other countries.", 16, font=CTA_FONT, fill="#b8c5b9")
    magick("-background", "none", GRAPHICS / "steam-logo.svg", "-resize", "246x", GRAPHICS / "steam-logo.png")
    logo_w, logo_h = size(GRAPHICS / "steam-logo.png")
    cta_w, cta_h = size(wishlist)
    row_width = logo_w + 52 + cta_w
    logo_x = (1920 - row_width) // 2
    cta_x = logo_x + logo_w + 52
    tw, th = size(tagline)
    lw, lh = size(legal)
    background = GRAPHICS / "end-card-background.png"
    blurred_capsule_background(background, 1920, 1080)
    magick(background,
           GRAPHICS / "capsule.png", "-gravity", "northwest", "-geometry", "+344+44", "-composite",
           tagline, "-geometry", f"+{(1920-tw)//2}+{810-th//2}", "-composite",
           GRAPHICS / "steam-logo.png", "-geometry", f"+{logo_x}+{953-logo_h//2}", "-composite",
           wishlist, "-geometry", f"+{cta_x}+{953-cta_h//2}", "-composite",
           legal, "-geometry", f"+{(1920-lw)//2}+{1055-lh//2}", "-composite",
           GRAPHICS / "end-card.png")


def loop_captions():
    for name, value in [("plant", "PLANT"), ("fertilize", "FERTILIZE"),
                        ("mutate", "MUTATE"), ("harvest", "HARVEST"),
                        ("lineage-death", "LAMARCK FALLS"), ("lineage-spores", "A LINEAGE LIVES ON"),
                        ("lineage-plant", "PLANT THEIR SPORES"), ("lineage-harvest", "HARVEST THE NEXT GENERATION"),
                        ("lineage-result", "MEET LAMARCK II")]:
        paper_caption(name, value, 56)


if __name__ == "__main__":
    for name, value, points in [("grow", "GROW", 90), ("train", "TRAIN", 90),
                                 ("fight", "FIGHT", 90), ("two-days", "2 DAYS LATER", 44),
                                 ("one-day", "1 DAY LATER", 44)]:
        paper_caption(name, value, points)
    loop_captions()
    end_card()
