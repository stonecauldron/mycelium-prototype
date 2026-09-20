#!/usr/bin/env python3
"""Record lossless gameplay. Godot must run outside the agent sandbox on macOS."""
import argparse
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

PACKAGE = pathlib.Path(__file__).resolve().parents[1]
REPO = PACKAGE.parents[2]
p = argparse.ArgumentParser()
p.add_argument("scenarios", nargs="*", default=["nursery", "training", "formation", "battle_a", "battle_b", "battle_elite", "summary", "gardening", "lineage_sword"])
args = p.parse_args()
for scenario in args.scenarios:
    out = PACKAGE / "sources/takes" / (scenario + ".mov")
    temporary = PACKAGE / "work/raw-capture" / scenario
    temporary.mkdir(parents=True, exist_ok=True)
    raw = temporary / "frames.rgb"
    timing = temporary / "timing-audio.avi"
    log = out.with_suffix(".log")
    print("Recording lossless " + scenario, flush=True)
    command = ["godot", "--path", str(REPO), "--rendering-method", "gl_compatibility", "--rendering-driver", "opengl3",
               "--windowed", "--resolution", "1920x1080", "--write-movie", str(timing), "--fixed-fps", "60", "--quit-after", "5400",
               str(PACKAGE / "scripts/capture.tscn"), "--", "scenario=" + scenario, "raw_capture=" + str(raw)]
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=REPO, stdout=stream, stderr=subprocess.STDOUT, timeout=1800)
    contents = log.read_text()
    for line in contents.splitlines():
        if line.startswith(("ARMY", "EVENT", "CAPTURE")) or "frames at 60 FPS" in line:
            print(line, flush=True)
    if result.returncode or any(x in contents for x in ("SCRIPT ERROR", "Parse Error", "Assertion failed")) or "take_complete" not in contents:
        print(contents[-5000:])
        sys.exit(1)
    events = json.loads(out.with_suffix('.json').read_text())
    capture = next(e for e in events if 'raw_frames' in e)
    width, height = capture['width'], capture['height']
    frame_bytes = width * height * 3
    assert raw.stat().st_size % frame_bytes == 0
    frames = raw.stat().st_size // frame_bytes
    final_frame = next(e['frame'] for e in events if e.get('action') == 'take_complete')
    assert abs(frames - final_frame) <= 1, (frames, final_frame)
    # Movie Maker supplies fixed frame timing and isolated PCM SFX. Its JPEG video
    # is discarded; the delivered picture comes only from uncompressed GPU pixels.
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", f"{width}x{height}",
                    "-framerate", "60", "-i", str(raw), "-i", str(timing), "-map", "0:v", "-map", "1:a",
                    "-c:v", "png", "-pix_fmt", "rgb24", "-compression_level", "3", "-threads", "4",
                    "-c:a", "pcm_s16le", "-t", str(frames / 60), "-movflags", "+faststart", str(out)], check=True)
    original_hash = hashlib.file_digest(raw.open('rb'), 'sha256').hexdigest()
    encoded_hash = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(out), "-map", "0:v", "-pix_fmt", "rgb24",
                    "-f", "hash", "-hash", "sha256", "-"], text=True).strip().split('=')[1]
    assert original_hash == encoded_hash, "Lossless MOV round-trip failed"
    out.with_suffix(".quality.json").write_text(json.dumps({"codec": "png", "pixel_format": "rgb24", "fps": 60,
        "width": width, "height": height, "frame_count": frames, "decoded_rgb_sha256": encoded_hash, "raw_capture_matches_mov": True}, indent=2) + "\n")
    shutil.rmtree(temporary)
    print(f"Finished lossless {scenario}: {frames} frames; pixel-exact GPU/MOV match", flush=True)
