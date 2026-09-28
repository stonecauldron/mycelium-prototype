#!/usr/bin/env python3
"""Capture and export the single Spore Mortar reel for format review."""
import argparse
import json
import math
import pathlib
import subprocess

PACKAGE = pathlib.Path(__file__).resolve().parent
REPO = PACKAGE.parents[2]
SLUG = "spore-mortar"
FPS = 60
SECONDS = 16
VERSION = 7
FONT = REPO / "assets/fonts/SpicyRice-Regular.ttf"


def run(command, **kwargs):
    return subprocess.run(list(map(str, command)), check=True, **kwargs)


def capture():
    work = PACKAGE / "work"
    raw = work / f"{SLUG}.rgb"
    movie = work / f"{SLUG}-timing.avi"
    log = PACKAGE / "sources" / f"{SLUG}-v{VERSION}.log"
    command = [
        "godot", "--path", REPO, "--rendering-method", "gl_compatibility",
        "--rendering-driver", "opengl3", "--windowed", "--resolution", "540x960",
        "--write-movie", movie, "--fixed-fps", FPS, "--disable-vsync", "--quit-after", "6000",
        PACKAGE / "capture.tscn", "--", f"weapon={SLUG}", f"raw_capture={raw}", "probe",
    ]
    print("Capturing Spore Mortar at 1080x1920 / 60 fps", flush=True)
    with log.open("w") as stream:
        run(command, cwd=REPO, stdout=stream, stderr=subprocess.STDOUT, timeout=1200)
    contents = log.read_text()
    assert "CAPTURE complete" in contents, contents[-6000:]
    assert not any(term in contents for term in ["SCRIPT ERROR", "Parse Error", "Assertion failed"]), contents[-6000:]
    metadata = json.loads((PACKAGE / "sources" / f"{SLUG}-v{VERSION}.json").read_text())
    assert metadata["frames"] == FPS * SECONDS, metadata
    assert raw.stat().st_size == 1080 * 1920 * 3 * FPS * SECONDS
    print("Capture complete: 960 native portrait frames", flush=True)


def encode():
    raw = PACKAGE / "work" / f"{SLUG}.rgb"
    timing = PACKAGE / "work" / f"{SLUG}-timing.avi"
    output = PACKAGE / "exports" / f"auto-shrooms-spore-mortar-v{VERSION}.mp4"
    graph = (
        "[0:v]scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p[v];"
        "[1:a]atrim=start=0.5:end=16.5,asetpts=PTS-STARTPTS[sfx];"
        "[2:a]atrim=start=14:end=30,asetpts=PTS-STARTPTS,volume=0.3[music];"
        "[sfx][music]amix=inputs=2:duration=longest:normalize=0,"
        "loudnorm=I=-16:TP=-1.5:LRA=9,afade=t=in:d=0.08,afade=t=out:st=15.6:d=0.4[a]"
    )
    print("Encoding portrait review MP4", flush=True)
    run([
        "ffmpeg", "-hide_banner", "-loglevel", "warning", "-y",
        "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", "1080x1920",
        "-framerate", FPS, "-i", raw, "-i", timing,
        "-i", REPO / "assets/audio/battle_bgm.mp3",
        "-filter_complex_threads", "2", "-filter_complex", graph,
        "-map", "[v]", "-map", "[a]", "-t", SECONDS,
        "-c:v", "libx264", "-preset", "medium", "-crf", "16", "-threads", "4",
        "-profile:v", "high", "-level:v", "4.2", "-g", "60", "-bf", "2",
        "-maxrate", "20M", "-bufsize", "20M",
        "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-ac", "2",
        "-movflags", "+faststart", "-use_editlist", "0", output,
    ])
    # Keep the answer hidden on the cover; reveal it only during playback.
    run(["ffmpeg", "-v", "error", "-y", "-ss", "0.2", "-i", output,
         "-frames:v", "1", "-q:v", "2", PACKAGE / "exports/spore-mortar-cover.jpg"])
    return output


def verify(output):
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(output)
    ]))
    video = next(stream for stream in probe["streams"] if stream["codec_type"] == "video")
    audio = next(stream for stream in probe["streams"] if stream["codec_type"] == "audio")
    assert (video["width"], video["height"], video["pix_fmt"]) == (1080, 1920, "yuv420p")
    assert video["r_frame_rate"] == "60/1" and int(video["nb_frames"]) == 960
    assert audio["codec_name"] == "aac" and audio["sample_rate"] == "48000"
    run(["ffmpeg", "-v", "error", "-i", output, "-f", "null", "-"])
    samples = []
    for index, seconds in enumerate([0.2, 0.65, 1.85, 2.7, 3.4, 4.8, 7.7, 10.3, 12.5, 14.8]):
        destination = PACKAGE / "preview" / f"export-v{VERSION}-{index}.jpg"
        run(["ffmpeg", "-v", "error", "-y", "-ss", seconds, "-i", output,
             "-frames:v", "1", "-vf", "scale=216:384", destination])
        samples.append(destination)
    run(["magick", "montage", "-font", FONT, *samples, "-tile", "5x2",
         "-geometry", "+4+4", "-background", "#101b15", PACKAGE / f"preview/storyboard-v{VERSION}.jpg"])
    loudness = subprocess.run([
        "ffmpeg", "-hide_banner", "-i", str(output), "-af",
        "loudnorm=I=-16:TP=-1.5:LRA=9:print_format=json", "-f", "null", "-"
    ], capture_output=True, text=True, check=True).stderr
    metrics, _ = json.JSONDecoder().raw_decode(loudness[loudness.rfind("{"):])
    capture_data = json.loads((PACKAGE / "sources" / f"{SLUG}-v{VERSION}.json").read_text())
    assert capture_data["equation_center_x"] == 540
    army = next(event for event in capture_data["events"] if event.get("action") == "army")
    assert army["players"] == 9 and army["enemies"] == 18
    spawn = next(event for event in capture_data["events"] if event.get("action") == "enemy_spawn_offset")
    first_hit = next(event for event in capture_data["events"] if event.get("action") == "first_mortar_damage")
    first_melee = next((event for event in capture_data["events"] if event.get("action") == "first_melee_range"), None)
    assert spawn["world_pixels"] == 480 and spawn["frame"] == army["frame"]
    assert first_hit["melee_clearance"] > 0, "Mortar damage must land before melee range"
    assert first_melee is None or first_melee["frame"] > first_hit["frame"]
    entry = next(event for event in capture_data["events"] if event.get("action") == "cocoon_entry")
    reveal = next(event for event in capture_data["events"] if event.get("action") == "cocoon_reveal")
    name = next(event for event in capture_data["events"] if event.get("action") == "weapon_name")
    walk = next(event for event in capture_data["events"] if event.get("action") == "walk_started")
    closed = next(event for event in capture_data["events"] if event.get("action") == "cocoon_closed")
    landing = next(event for event in capture_data["events"] if event.get("action") == "reveal_landing")
    walk_seconds = (closed["frame"] - walk["frame"]) / FPS
    assert walk_seconds == 0.5 and walk["animation_speed"] == 2.1
    assert closed["frame"] == 51 and reveal["frame"] == 150 and name["frame"] == 240
    assert entry["life_stage"] == "child" and "held_school" in entry
    assert reveal["complete_equation"] and reveal["sound"] == "train"
    assert reveal["shell_pieces"] == 2 and reveal["hop_height"] == 240
    assert reveal["apex_hold_seconds"] == 0.1 and landing["frame"] == 186
    assert landing["sound"] == "ground"
    assert reveal["frame"] < name["frame"]
    camera_positions = {}
    camera_zooms = {}
    for event in capture_data["events"]:
        if "zoom" not in event:
            continue
        shot = event["shot"]
        if event.get("action") == "cut":
            assert not event["screen_fixed_forest_visible"]
            assert math.isclose(event["background_screen_scale"], 0.5 * event["zoom"], abs_tol=0.000001)
        camera_zooms.setdefault(shot, event["zoom"])
        assert math.isclose(event["zoom"], camera_zooms[shot], abs_tol=0.000001)
        camera_positions.setdefault(shot, event["camera_x"])
        assert camera_positions[shot] == event["camera_x"], f"Camera drifted during {shot}"
        if shot == "army_launch" and event["frame"] in [600, 660]:
            assert event["fully_visible_players"] == 9, "All nine firing units must fit inside the picture"
        if shot in ["single_wide", "army_wide"] and "alive" in event:
            assert event["fully_visible_players"] == event["alive"], "Wide shot must include every living player"
            assert event["fully_visible_enemies"] == event["enemies_alive"], "Wide shot must include every living enemy"
    assert list(camera_positions) == ["single_wide", "army_launch", "army_impact", "army_wide"]
    assert camera_zooms["army_wide"] < camera_zooms["army_launch"]
    report = {
        "file": output.name, "width": 1080, "height": 1920, "fps": 60,
        "frames": 960, "duration": float(probe["format"]["duration"]),
        "bytes": output.stat().st_size, "full_decode": "passed",
        "audio": {"codec": "aac", "sample_rate": 48000, "integrated_lufs": metrics["input_i"], "true_peak_dbtp": metrics["input_tp"]},
        "composition": {"equation_center_x": 540, "army_players": 9, "army_enemies": 18,
                        "child_entry": True, "complete_recipe_before_name": True,
                        "camera_zooms": camera_zooms, "both_armies_visible_in_wide_shots": True,
                        "camera_cuts_without_panning": True, "background_scales_with_camera": True},
        "final_battle": {"extra_enemy_spawn_distance": spawn["world_pixels"],
                         "first_mortar_hit_seconds": first_hit["frame"] / FPS,
                         "melee_clearance_at_first_hit": first_hit["melee_clearance"],
                         "first_melee_seconds": first_melee["frame"] / FPS if first_melee else None,
                         "mortar_hits_before_melee": True},
        "cocoon_entry": {"walk_seconds": walk_seconds, "animation_speed": walk["animation_speed"],
                         "closed_seconds": closed["frame"] / FPS, "reveal_seconds": reveal["frame"] / FPS},
        "cocoon_reveal": {"split_shell": True, "hop_height": reveal["hop_height"],
                          "apex_hold_seconds": reveal["apex_hold_seconds"],
                          "landing_seconds": landing["frame"] / FPS,
                          "explosion_sound": False, "unit_scale": reveal["unit_scale"]},
        "scope": "Single Spore Mortar pilot; remaining four reels deferred for user critique.",
    }
    (PACKAGE / f"validation-v{VERSION}.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--capture", action="store_true")
    args = parser.parse_args()
    for folder in ["sources", "work", "exports", "preview"]:
        (PACKAGE / folder).mkdir(exist_ok=True)
    if args.capture:
        capture()
    verify(encode())
