#!/usr/bin/env python3
"""Validate the social export, portrait layout, unchanged pacing, and PCM soundtrack."""
import array
import hashlib
import json
import pathlib
import struct
import subprocess

from render_portrait import ART, EDIT, MASTER, MOVIE, OUT, PACKAGE
from validate import training_proof


def probe(path, frames=False):
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", *(["-count_frames"] if frames else []),
        "-show_streams", "-show_format", "-of", "json", str(path)]))


def atoms(path):
    records = []
    containers = {b"moov", b"trak", b"mdia", b"minf", b"stbl", b"edts"}
    with path.open("rb") as stream:
        def walk(start, end):
            position = start
            while position + 8 <= end:
                stream.seek(position)
                size, kind = struct.unpack(">I4s", stream.read(8))
                header = 8
                if size == 1:
                    size = struct.unpack(">Q", stream.read(8))[0]
                    header = 16
                elif size == 0:
                    size = end - position
                assert size >= header and position + size <= end
                records.append((kind.decode("ascii", errors="replace"), position))
                if kind in containers:
                    walk(position + header, position + size)
                position += size
        walk(0, path.stat().st_size)
    return records


def pcm_hash(path):
    return subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-map", "0:a:0",
                                    "-c:a", "copy", "-f", "hash", "-hash", "sha256", "-"], text=True).strip()


def check():
    data = probe(MOVIE, frames=True)
    v = next(s for s in data["streams"] if s["codec_type"] == "video")
    a = next(s for s in data["streams"] if s["codec_type"] == "audio")
    assert (v["width"], v["height"], v["r_frame_rate"], int(v["nb_read_frames"])) == (1080, 1920, "60/1", 1920)
    assert v["codec_name"] == "h264" and v["profile"] == "High" and v["pix_fmt"] == "yuv420p"
    assert v["field_order"] == "progressive" and v["color_space"] == "bt709"
    assert v["color_range"] == "tv" and 516_000 <= int(v["bit_rate"]) < 25_000_000
    assert a["codec_name"] == "aac" and a["sample_rate"] == "48000" and a["channels"] == 2
    assert 120_000 < int(a["bit_rate"]) < 132_000
    assert abs(float(data["format"]["duration"]) - 32) < .08
    assert MOVIE.stat().st_size < 500_000_000
    structure = atoms(MOVIE)
    assert not any(kind == "elst" for kind, _ in structure)
    assert next(pos for kind, pos in structure if kind == "moov") < next(pos for kind, pos in structure if kind == "mdat")
    subprocess.run(["ffmpeg", "-v", "error", "-i", str(MOVIE), "-f", "null", "-"], check=True)
    original = json.loads((PACKAGE / "scripts/edit.json").read_text())
    assert sum(ch["duration"] for ch in EDIT["chapters"]) == 32
    assert [ch["duration"] for ch in EDIT["chapters"]] == [ch["duration"] for ch in original["chapters"]]
    assert EDIT["chapters"][-1]["duration"] == 5
    for chapter in EDIT["chapters"]:
        assert abs(sum(c["duration"] for c in chapter["clips"]) - chapter["duration"]) < .001
        for clip in chapter["clips"]:
            assert clip["source"] not in {"gardening", "lineage_sword"}
            if "crop" in clip:
                w, h, x, y = clip["crop"]
                assert x >= 0 and y >= 0 and x+w <= 1920 and y+h <= 1080
    m = probe(MASTER)
    mv = next(s for s in m["streams"] if s["codec_type"] == "video")
    assert (mv["codec_name"], mv["pix_fmt"], int(mv["nb_frames"])) == ("png", "rgb24", 1920)
    assert (mv["width"], mv["height"]) == (1080, 1920)
    landscape_master = PACKAGE / "sources/masters/auto-shrooms-trailer-32s-lossless.mov"
    assert pcm_hash(MASTER) == pcm_hash(landscape_master)
    audio = array.array("f", subprocess.check_output([
        "ffmpeg", "-v", "error", "-ss", "31.9", "-i", str(MOVIE),
        "-t", "0.1", "-vn", "-ac", "1", "-ar", "48000", "-f", "f32le", "-"]))
    assert audio and max(abs(s) for s in audio) < .001
    rect = EDIT["key_text_safe_rect"]
    sx, sy, sw, sh = rect
    layout = json.loads((ART / "layout.json").read_text())
    titles = {c["title"] for ch in EDIT["chapters"] for c in ch["clips"] if "title" in c}
    for title in titles:
        width, height = map(int, subprocess.check_output([
            "magick", "identify", "-format", "%w %h", str(ART / (title + ".png"))], text=True).split())
        layout["caption_" + title] = [*EDIT["caption_position"], width, height]
    for name, (x, y, w, h) in layout.items():
        assert x >= sx and y >= sy and x+w <= sx+sw and y+h <= sy+sh, name
    assert EDIT["landscape_revision"] == original["revision"]
    training = next(ch for ch in EDIT["chapters"] if ch["name"] == "03-train")
    landscape_training = next(ch for ch in original["chapters"] if ch["name"] == "03-train")
    assert [(c["source"], c["start"], c["duration"]) for c in training["clips"]] == [
        (c["source"], c["start"], c["duration"]) for c in landscape_training["clips"]]
    training_check = training_proof(training["clips"], training["overlap"])
    with landscape_master.open("rb") as stream:
        landscape_hash = hashlib.file_digest(stream, "sha256").hexdigest()
    report = {"file": str(MOVIE.relative_to(PACKAGE)), "bytes": MOVIE.stat().st_size,
              "width": 1080, "height": 1920, "aspect_ratio": "9:16", "fps": "60/1", "frames": 1920,
              "container_duration": float(data["format"]["duration"]), "video_bitrate": int(v["bit_rate"]),
              "audio_bitrate": int(a["bit_rate"]), "fast_start": True, "edit_lists": False,
              "lossless_master": str(MASTER.relative_to(PACKAGE)), "pcm_matches_landscape_master": True,
              "revision": EDIT["revision"], "landscape_revision": original["revision"],
              "landscape_master_sha256": landscape_hash, "training": training_check,
              "editorial_safe_rect": rect, "text_bounds": layout,
              "checks": ["Full MP4 decoding passed", "1920 frames at native 60 fps", "Progressive H.264 High / AAC / BT.709",
                         "Original chapter pacing and five-second end card", "Original quick grow sequence; no extended loops",
                         "All source crops stay inside the captured frame", "Critical text within editorial margins",
                         "Sword Child / Great Sword preview / confirmation; no emergence",
                         "Matching training source ranges in both trailers",
                         "Lossless RGB master and PCM soundtrack matching current landscape", "Quiet audio tail"]}
    (PACKAGE / "social-validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: report[k] for k in ["width", "height", "fps", "frames", "container_duration", "bytes", "fast_start", "edit_lists"]}, indent=2))


if __name__ == "__main__":
    check()
