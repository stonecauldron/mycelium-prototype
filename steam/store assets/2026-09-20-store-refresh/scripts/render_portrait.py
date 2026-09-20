#!/usr/bin/env python3
"""Build a 9:16 social version from the lossless takes and approved 32s soundtrack."""
import argparse
import json
import pathlib
import subprocess
import tempfile

import make_graphics
from render import DELIVERY_COLOR, encode_args, ffmpeg, lossless_args

PACKAGE = pathlib.Path(__file__).resolve().parents[1]
EDIT = json.loads((PACKAGE / "scripts/portrait-edit.json").read_text())
GRAPHICS = PACKAGE / "sources/graphics"
ART = GRAPHICS / "portrait"
WORK = PACKAGE / "work/portrait"
OUT = PACKAGE / "exports/social"
PREVIEW = PACKAGE / "preview/portrait"
MASTER = PACKAGE / "sources/masters/auto-shrooms-reel-32s-lossless.mov"
MOVIE = OUT / "auto-shrooms-reel-32s-1080x1920.mp4"


def magick(*args):
    subprocess.run(["magick", *map(str, args)], check=True)


def graphics():
    for path in [ART, WORK, OUT, PREVIEW]:
        path.mkdir(exist_ok=True)
    # Existing game art fills the portrait canvas. Gameplay remains a sharp, separate layer.
    make_graphics.blurred_capsule_background(ART / "background.png", 1080, 1920)
    make_graphics.paper_caption("portrait-hook", "FUNGUS VULT!", 72)
    make_graphics.paper_caption("portrait-arrange", "ARRANGE YOUR SQUAD", 64)
    titles = {c.get("title") for ch in EDIT["chapters"] for c in ch["clips"] if c.get("title")}
    for title in titles:
        magick(GRAPHICS / (title + ".png"), "-resize", "800x62", ART / (title + ".png"))
    with tempfile.TemporaryDirectory() as folder:
        temp = pathlib.Path(folder)
        magick(GRAPHICS / "capsule.png", "-resize", "810x", temp / "capsule.png")
        magick(GRAPHICS / "tagline.png", "-resize", "700x100", temp / "tagline.png")
        magick(GRAPHICS / "steam-logo.png", "-resize", "180x", temp / "steam.png")
        magick("-background", "none", "-fill", "#fff3cf", "-font", make_graphics.CTA_FONT,
               "-pointsize", "64", "label:Wishlist on Steam", "-trim", "+repage", temp / "cta.png")
        magick("-background", "none", "-fill", "#b8c5b9", "-font", make_graphics.CTA_FONT,
               "-pointsize", "18", "-size", "810x70", "-gravity", "center",
               "caption:©2026 Valve Corporation. Steam and the Steam logo are trademarks and/or registered trademarks of Valve Corporation in the U.S. and/or other countries.",
               temp / "legal.png")
        tw, th = make_graphics.size(temp / "tagline.png")
        sw, sh = make_graphics.size(temp / "steam.png")
        cw, ch = make_graphics.size(temp / "cta.png")
        assert sw + 28 + cw <= 810
        x = 90 + (810 - sw - 28 - cw) // 2
        magick(ART / "background.png", temp / "capsule.png", "-gravity", "northwest",
               "-geometry", "+90+360", "-composite", temp / "tagline.png",
               "-geometry", f"+{90+(810-tw)//2}+{914-th//2}", "-composite",
               temp / "steam.png", "-geometry", f"+{x}+{1076-sh//2}", "-composite",
               temp / "cta.png", "-geometry", f"+{x+sw+28}+{1076-ch//2}", "-composite",
               temp / "legal.png", "-geometry", "+90+1160", "-composite", ART / "end-card.png")
        layout = {"capsule": [90, 360, 810, make_graphics.size(temp / "capsule.png")[1]],
                  "tagline": [90+(810-tw)//2, 914-th//2, tw, th],
                  "steam_logo": [x, 1076-sh//2, sw, sh],
                  "wishlist": [x+sw+28, 1076-ch//2, cw, ch],
                  "attribution": [90, 1160, 810, 70]}
        (ART / "layout.json").write_text(json.dumps(layout, indent=2) + "\n")


def filters(clip):
    w, h, x, y = clip["crop"]
    px, py, pw, ph = EDIT["gameplay_rect"]
    cx, cy = EDIT["caption_position"]
    return (f"[0:v]setpts=PTS-STARTPTS,fps=60,crop=iw*{w}/1920:ih*{h}/1080:"
            f"iw*{x}/1920:ih*{y}/1080,scale={pw}:{ph}:force_original_aspect_ratio=decrease:flags=lanczos,setsar=1[game];"
            f"[1:v][game]overlay=x={px}+({pw}-w)/2:y={py}+({ph}-h)/2:shortest=1:format=rgb[framed];"
            f"[framed][2:v]overlay={cx}:{cy}:shortest=1:format=rgb,format=rgb24[outv]")


def shot(clip, duration, destination, still=False):
    args = ["-ss", str(clip["start"]), "-i", PACKAGE / f"sources/takes/{clip['source']}.mov",
            "-loop", "1", "-framerate", "60", "-i", ART / "background.png",
            "-loop", "1", "-framerate", "60", "-i", ART / (clip["title"] + ".png"),
            "-filter_complex_threads", "2", "-filter_complex", filters(clip), "-map", "[outv]", "-an"]
    if still:
        args += ["-frames:v", "1"]
    else:
        args += ["-t", str(duration), *lossless_args()]
    ffmpeg([*args, destination])


def preview():
    paths = []
    timeline = 0
    for chapter in EDIT["chapters"]:
        for i, clip in enumerate(chapter["clips"]):
            path = PREVIEW / f"shot-{len(paths):02d}.jpg"
            if clip["source"] == "end-card":
                magick(ART / "end-card.png", path)
            else:
                sample = {**clip, "start": clip["start"] + clip["duration"] / 2}
                shot(sample, clip["duration"], path, still=True)
            magick(path, "-resize", "270x480", "-font", make_graphics.CTA_FONT,
                   "-pointsize", "16", "-fill", "white", "-undercolor", "#000000a0",
                   "-gravity", "northwest", "-annotate", "+5+5", f"{timeline:.2f}s", path)
            paths.append(path)
            timeline += clip["duration"]
    magick("montage", "-font", make_graphics.CTA_FONT, *paths, "-tile", "7x", "-geometry", "+4+4", "-background", "#111816",
           PREVIEW / "shot-contact.jpg")


def render(chapter_names=None):
    chapters = []
    for chapter in EDIT["chapters"]:
        output = WORK / (chapter["name"] + ".mov")
        chapters.append(output)
        if chapter_names and chapter["name"] not in chapter_names:
            assert output.exists(), output
            continue
        print("Portrait chapter " + chapter["name"], flush=True)
        paths = []
        for i, clip in enumerate(chapter["clips"]):
            duration = clip["duration"] + (chapter["overlap"] if i == len(chapter["clips"])-1 else 0)
            path = WORK / f"{chapter['name']}-{i:02d}.mov"
            if clip["source"] == "end-card":
                ffmpeg(["-loop", "1", "-framerate", "60", "-i", ART / "end-card.png",
                        "-t", str(duration), *lossless_args(), path])
            else:
                shot(clip, duration, path)
            paths.append(path)
        listing = WORK / (chapter["name"] + ".ffconcat")
        listing.write_text("ffconcat version 1.0\n" + "".join(f"file '{p.name}'\n" for p in paths))
        ffmpeg(["-f", "concat", "-safe", "0", "-i", listing, "-c", "copy", output])
    args = [a for path in chapters for a in ["-i", path]]
    # Exact approved music/SFX timing; there are no added or lengthened sequences.
    args += ["-i", PACKAGE / "sources/masters/auto-shrooms-trailer-32s-lossless.mov"]
    chain = [f"[{i}:v]settb=AVTB,setpts=PTS-STARTPTS,format=gbrp[v{i}]" for i in range(len(chapters))]
    video, offset = "v0", 0
    for i in range(1, len(chapters)):
        previous = EDIT["chapters"][i-1]
        offset += previous["duration"]
        chain.append(f"[{video}][v{i}]xfade=transition={previous['transition']}:"
                     f"duration={previous['overlap']}:offset={offset}[x{i}]")
        video = f"x{i}"
    chain.append(f"[{video}]fps=60,trim=duration=32,fade=t=out:st=31.8:d=0.2,format=rgb24[outv]")
    print("Mixing portrait master", flush=True)
    ffmpeg([*args, "-filter_complex_threads", "2", "-filter_complex", ";".join(chain),
            "-map", "[outv]", "-map", f"{len(chapters)}:a", "-t", "32", *lossless_args(),
            "-c:a", "copy", "-movflags", "+faststart", MASTER])
    print("Encoding social MP4", flush=True)
    ffmpeg(["-i", MASTER, "-vf", DELIVERY_COLOR, *encode_args(16), "-profile:v", "high",
            "-level:v", "4.2", "-maxrate", "20M", "-bufsize", "20M", "-g", "30", "-bf", "2",
            "-x264-params", "open-gop=0", "-c:a", "aac", "-b:a", "128k", "-ar", "48000",
            "-ac", "2", "-movflags", "+faststart", "-use_editlist", "0", MOVIE])
    ffmpeg(["-ss", "28", "-i", MOVIE, "-frames:v", "1", "-q:v", "2",
            OUT / "auto-shrooms-reel-cover-1080x1920.jpg"])


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", action="store_true", help="Render framing stills only")
    parser.add_argument("--chapters", nargs="+")
    args = parser.parse_args()
    graphics()
    if args.preview:
        preview()
    else:
        render(args.chapters)
