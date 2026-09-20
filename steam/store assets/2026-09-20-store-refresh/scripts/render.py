#!/usr/bin/env python3
"""Rebuild the media package from captured gameplay and the editable cut list."""
import argparse
import json
import pathlib
import subprocess

PACKAGE = pathlib.Path(__file__).resolve().parents[1]
TAKES = PACKAGE / "sources/takes"
GRAPHICS = PACKAGE / "sources/graphics"
WORK = PACKAGE / "work"
EXPORTS = PACKAGE / "exports"
EDIT = json.loads((PACKAGE / "scripts/edit.json").read_text())


def run(args):
    result = subprocess.run([str(x) for x in args], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr[-9000:])


def ffmpeg(args):
    run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args])


def encode_args(crf=14):
    return ["-c:v", "libx264", "-preset", "slow", "-crf", str(crf),
            "-threads", "4", "-pix_fmt", "yuv420p", "-color_primaries", "bt709",
            "-color_trc", "bt709", "-colorspace", "bt709", "-color_range", "tv"]


def lossless_args():
    return ["-c:v", "png", "-pix_fmt", "rgb24", "-compression_level", "3", "-threads", "4"]


DELIVERY_COLOR = "scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p"


def concat(files, destination):
    # Files live in work and have controlled names without quoting characters.
    listing = WORK / (destination.stem + ".ffconcat")
    listing.write_text("ffconcat version 1.0\n" + "".join(
        "file '" + f.name + "'\n" for f in files))
    ffmpeg(["-f", "concat", "-safe", "0", "-i", listing,
            "-c", "copy", destination])


def segment(clip, duration, destination, end_card=False):
    if end_card:
        ffmpeg(["-loop", "1", "-framerate", "60", "-i", GRAPHICS / "end-card.png",
                "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-t", str(duration),
                *lossless_args(), "-c:a", "pcm_s16le", destination])
        return
    args = ["-ss", str(clip["start"]), "-t", str(duration),
            "-i", TAKES / (clip["source"] + ".mov")]
    filters = []
    base = "[0:v]setpts=PTS-STARTPTS,fps=60"
    if "crop" in clip:
        w, h, x, y = clip["crop"]
        # Cut-list coordinates remain in 1080p; capture at the native viewport size.
        base += f",crop=iw*{w}/1920:ih*{h}/1080:iw*{x}/1920:ih*{y}/1080"
    if clip.get("footer"):
        base += ",scale=1920:960:flags=lanczos,setsar=1,pad=1920:1080:0:0:color=0x0a1510"
    else:
        base += ",scale=1920:1080:flags=lanczos,setsar=1"
    filters.append(base + "[base]")
    video = "base"
    overlays = []
    if clip.get("title"):
        placement = EDIT["headline_position"]
        bottom = clip.get("caption_bottom", placement["bottom_margin"])
        overlays = [(clip["title"], str(placement["x"]), f'H-h-{bottom}')]
    for index, (name, x, y) in enumerate(overlays, 1):
        args += ["-loop", "1", "-framerate", "60", "-i", GRAPHICS / (name + ".png")]
        filters.append(f"[{video}][{index}:v]overlay=x={x}:y={y}:shortest=1:format=rgb[v{index}]")
        video = f"v{index}"
    filters.append(f"[{video}]format=rgb24[outv]")
    filters.append(f"[0:a]asetpts=PTS-STARTPTS,afade=t=in:d=0.008,"
                   f"afade=t=out:st={duration - .008}:d=0.008,apad,atrim=duration={duration}[outa]")
    ffmpeg([*args, "-filter_complex_threads", "2", "-filter_complex", ";".join(filters),
            "-map", "[outv]", "-map", "[outa]", "-t", str(duration),
            *lossless_args(), "-c:a", "pcm_s16le", "-ar", "48000", destination])


def trailer(chapter_names=None, mix=True):
    duration = sum(chapter["duration"] for chapter in EDIT["chapters"])
    end_card_start = duration - EDIT["chapters"][-1]["duration"]
    ending = EDIT["ending"]
    chapters = []
    for chapter in EDIT["chapters"]:
        output = WORK / (chapter["name"] + ".mov")
        if chapter_names and chapter["name"] not in chapter_names:
            assert output.exists(), f"Missing cached chapter: {output}"
            chapters.append(output)
            continue
        print("Rendering chapter " + chapter["name"], flush=True)
        clips = []
        for i, clip in enumerate(chapter["clips"]):
            clip_duration = clip["duration"]
            if i == len(chapter["clips"]) - 1:
                clip_duration += chapter["overlap"]
            path = WORK / f'{chapter["name"]}-{i:02d}.mov'
            segment(clip, clip_duration, path, clip["source"] == "end-card")
            clips.append(path)
        output = WORK / (chapter["name"] + ".mov")
        concat(clips, output)
        chapters.append(output)
    if not mix:
        return
    args = []
    for path in chapters:
        args += ["-i", path]
    args += ["-ss", str(EDIT["music_start"]), "-i", PACKAGE / "sources/audio/battle_bgm.mp3"]
    filters = []
    chapter_count = len(chapters)
    for i in range(chapter_count):
        filters += [f"[{i}:v]settb=AVTB,setpts=PTS-STARTPTS,format=gbrp[v{i}]",
                    f"[{i}:a]asetpts=PTS-STARTPTS[a{i}]"]
    video, audio, offset = "v0", "a0", 0
    for i in range(1, chapter_count):
        prev = EDIT["chapters"][i-1]
        offset += prev["duration"]
        transition, overlap = prev["transition"], prev["overlap"]
        filters.append(f"[{video}][v{i}]xfade=transition={transition}:duration={overlap}:offset={offset}[x{i}]")
        filters.append(f"[{audio}][a{i}]acrossfade=d={overlap}:c1=tri:c2=tri[s{i}]")
        video, audio = f"x{i}", f"s{i}"
    music_end = duration - ending["quiet_tail"]
    music_fade_start = music_end - ending["music_fade_duration"]
    filters.append(f"[{video}]fps=60,trim=duration={duration},"
                   f"fade=t=out:st={duration - ending['picture_fade_duration']}:"
                   f"d={ending['picture_fade_duration']},format=rgb24[outv]")
    filters.append(f"[{audio}]atrim=duration={duration},volume=0.80,"
                   f"afade=t=out:st={end_card_start}:d=0.5[sfx]")
    filters.append(f"[{chapter_count}:a]asetpts=PTS-STARTPTS,atrim=duration={duration},volume=0.55,"
                   f"afade=t=in:d=0.025,afade=t=out:st={music_fade_start}:"
                   f"d={ending['music_fade_duration']}:curve=hsin[music]")
    filters.append("[sfx][music]amix=inputs=2:duration=longest:normalize=0,"
                   f"alimiter=limit=0.95,loudnorm=I=-16:LRA=9:TP=-1.0,atrim=duration={duration}[outa]")
    out = EXPORTS / f"trailer/auto-shrooms-trailer-{duration:g}s.mp4"
    master = PACKAGE / f"sources/masters/auto-shrooms-trailer-{duration:g}s-lossless.mov"
    master.parent.mkdir(exist_ok=True)
    print("Mixing trailer and soundtrack", flush=True)
    ffmpeg([*args, "-filter_complex_threads", "2", "-filter_complex", ";".join(filters),
            "-map", "[outv]", "-map", "[outa]", "-t", str(duration), *lossless_args(),
            "-c:a", "pcm_s24le", "-ar", "48000", "-movflags", "+faststart", master])
    ffmpeg(["-i", master, "-vf", DELIVERY_COLOR, *encode_args(), "-c:a", "aac",
            "-b:a", "320k", "-ar", "48000", "-movflags", "+faststart", out])
    # A poster that is genuinely present in the trailer, not a separate illustration.
    ffmpeg(["-ss", str(end_card_start + .8), "-i", out, "-frames:v", "1",
            "-vf", "scale=in_range=tv:out_range=full,format=yuvj420p", "-color_range", "pc", "-q:v", "2",
            EXPORTS / "trailer/poster-1920x1080.jpg"])


def loop_video(name, pieces, crop=None, marker=None, post_crop=None):
    paths = []
    duration = 0
    for i, piece in enumerate(pieces):
        if isinstance(piece, dict):
            clip = piece.copy()
        else:
            source, start, length = piece
            clip = dict(source=source, start=start, duration=length)
        if crop:
            clip["crop"] = crop
        path = WORK / f"loop-{name}-{i}.mov"
        segment(clip, clip["duration"], path)
        duration += clip["duration"]
        paths.append(path)
    assembled = WORK / f"loop-{name}.mov"
    concat(paths, assembled)
    mp4 = EXPORTS / "loops" / (name + ".mp4")
    args = ["-i", assembled]
    framing = "crop=" + ":".join(map(str, post_crop)) + "," if post_crop else ""
    vf = "[0:v]" + framing + "fps=30,scale=1170:-2:flags=lanczos,setsar=1[v]"
    label = "v"
    if marker:
        asset, start, end = marker
        placement = EDIT.get("loop_caption_positions", {}).get(name, {})
        marker_scale = placement.get("scale", 0.65)
        marker_bottom = placement.get("bottom_margin", 17)
        args += ["-loop", "1", "-framerate", "30", "-i", GRAPHICS / (asset + ".png")]
        vf += f";[1:v]scale=iw*{marker_scale}:ih*{marker_scale}[label];[v][label]overlay=x=29:y=H-h-{marker_bottom}:enable='between(t,{start},{end})':shortest=1:format=rgb[outv]"
        label = "outv"
    vf += f";[{label}]{DELIVERY_COLOR}[delivery]"
    ffmpeg([*args, "-filter_complex_threads", "2", "-filter_complex", vf,
            "-map", "[delivery]", "-an", "-t", str(duration), *encode_args(16),
            "-movflags", "+faststart", mp4])
    gif = mp4.with_suffix(".gif")
    gif_options = EDIT.get("loop_gif_options", {}).get(name, {})
    presets = gif_options.get("presets", [(936, 15, 128, 3), (780, 15, 128, 3),
                                         (780, 12, 96, 4), (702, 12, 64, 5),
                                         (616, 10, 64, 5), (616, 8, 48, 5)])
    for width, fps, colors, dither in presets:
        filters = (f"fps={fps},scale={width}:-2:flags=lanczos,split[a][b];"
                   f"[a]palettegen=max_colors={colors}:stats_mode=diff[p];"
                   f"[b][p]paletteuse=dither=bayer:bayer_scale={dither}:diff_mode=rectangle")
        ffmpeg(["-i", mp4, "-filter_complex_threads", "2", "-filter_complex", filters,
                "-loop", "0", gif])
        if gif.stat().st_size < gif_options.get("max_bytes", 3_150_000):
            break
    print(f"Loop {name}: {duration:.2f}s, GIF {gif.stat().st_size / 1e6:.2f} MB", flush=True)


def loops():
    gardening_loop()
    training_loop()
    loop_video("03-arrange-your-squad", [("formation", .9, 7.8)], [1728, 972, 0, 80])
    battle_loop()
    lineage_loop()


def gardening_loop():
    loop_video("01-plant-and-harvest", EDIT["description_loops"]["01-plant-and-harvest"])


def training_loop():
    loop_video("02-train-and-combine", EDIT["description_loops"]["02-train-and-combine"])


def lineage_loop():
    loop_video("05-lineage", EDIT["description_loops"]["05-lineage"])


def battle_loop():
    # Preserve all horizontal army coverage while removing HUD and empty margins.
    loop_video("04-battle", [("battle_a", 4.8, 8.0)], post_crop=[1920, 720, 0, 280])


def screenshots(names=None):
    mappings = [
        ("01-battle-action", "battle_a-08"),
        ("02-battle-approach", "battle_a-approach"),
        ("03-war-chamber", "02-war-chamber"),
        ("04-nursery", "03-nursery"),
        ("05-day-summary", "05-day-summary"),
        ("06-training-combo", "training-great-sword-preview"),
    ]
    for name, source in mappings:
        if names and name not in names:
            continue
        original = PACKAGE / "sources/stills" / (source + ".png")
        capture = EDIT.get("screenshot_sources", {}).get(name)
        if capture:
            assert capture["still"] == source
            # Extract native lossless gameplay pixels before the delivery resize.
            ffmpeg(["-i", TAKES / (capture["source"] + ".mov"),
                    "-vf", f"select=eq(n\\,{capture['frame']})", "-frames:v", "1", original])
        png = EXPORTS / "screenshots" / (name + ".png")
        run(["magick", original, "-resize", "1920x1080!", "-strip", png])
        run(["magick", png, "-sampling-factor", "4:4:4", "-quality", "91", png.with_suffix(".jpg")])
    run(["magick", "montage", "-font", PACKAGE / "sources/fonts/SpicyRice-Regular.ttf",
         *sorted((EXPORTS / "screenshots").glob("*.jpg")), "-thumbnail", "640x360",
         "-tile", "2x3", "-geometry", "+10+10", "-background", "#111816",
         PACKAGE / "preview/screenshots-contact.jpg"])
    print("Exported selected screenshots and refreshed gallery contact sheet", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("targets", nargs="*", default=["trailer", "loops", "screenshots"])
    parser.add_argument("--chapters", nargs="+", help="Rebuild only these trailer chapters, then remix all chapters")
    parser.add_argument("--no-mix", action="store_true", help="Render selected chapters without rebuilding the trailer master")
    args = parser.parse_args()
    WORK.mkdir(exist_ok=True)
    for target in args.targets:
        if target == "trailer":
            trailer(args.chapters, not args.no_mix)
        else:
            {"loops": loops, "battle-loop": battle_loop, "gardening-loop": gardening_loop, "training-loop": training_loop,
             "lineage-loop": lineage_loop, "screenshots": screenshots}[target]()
