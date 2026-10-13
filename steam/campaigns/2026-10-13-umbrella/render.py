#!/usr/bin/env python3
"""Capture and verify native Umbrella combat in portrait and landscape formats."""
import argparse
import array
import hashlib
import json
import math
import pathlib
import subprocess
from collections import Counter

PACKAGE = pathlib.Path(__file__).resolve().parent
REPO = PACKAGE.parents[2]
PILOT = PACKAGE.parent / "2026-09-28-combo-reels"
VERSION = 4
FPS = 60
RATE = 48000
SECONDS = 20
FORMATS = {"portrait": (1080, 1920), "landscape": (1920, 1080)}
GAMEPLAY_FILES = [
    "assets/units/unit.gd",
    "assets/units/unit_appearance.gd",
    "assets/combat/projectile/projectile.gd",
    "assets/combat/projectile/projectile_blocker.gd",
    "assets/weapons/umbrella/umbrella.tres",
    "assets/weapons/umbrella/umbrella_appearance.tscn",
    "assets/weapons/mortar/mortar_projectile.tscn",
    "assets/units/enemies/peashooter/peashooter_unit.tres",
    "assets/units/enemies/seed_lobber/seed_lobber_unit.tres",
]


def run(command, **kwargs):
    return subprocess.run(list(map(str, command)), check=True, **kwargs)


def read_json(path):
    return json.loads(path.read_text())


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def stem(format_name):
    return f"umbrella-{format_name}-v{VERSION}"


def source_hashes():
    return {path: hashlib.sha256((REPO / path).read_bytes()).hexdigest() for path in GAMEPLAY_FILES}


def record_source(format_name):
    name = stem(format_name)
    patch = PACKAGE / "sources" / f"{name}-physics.patch"
    patch.write_bytes(subprocess.check_output(["git", "diff", "--binary", "HEAD", "--", *GAMEPLAY_FILES], cwd=REPO))
    state = {
        "base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
        "files": source_hashes(), "gameplay_patch": patch.name,
    }
    write_json(PACKAGE / "sources" / f"{name}-source.json", state)
    return state


def capture(format_name, dry_run=False):
    width, height = FORMATS[format_name]
    name = stem(format_name)
    source = record_source(format_name)
    movie = f"{name}-dry-timing.avi" if dry_run else f"{name}-timing.avi"
    command = [
        "godot", "--path", REPO, "--rendering-method", "gl_compatibility",
        "--rendering-driver", "opengl3", "--windowed", "--resolution",
        f"{width // 2}x{height // 2}", "--fixed-fps", FPS, "--disable-vsync",
        "--quit-after", "6000", "--write-movie", PACKAGE / "work" / movie,
        PACKAGE / "capture.tscn", "--", f"format={format_name}", "probe",
    ]
    if not dry_run:
        command += [f"raw_capture={PACKAGE / 'work' / (name + '.rgb')}"]
    log = PACKAGE / "sources" / f"{name}{'-dry' if dry_run else ''}.log"
    print("Dry-running" if dry_run else "Capturing", format_name, flush=True)
    with log.open("w") as stream:
        run(command, cwd=REPO, stdout=stream, stderr=subprocess.STDOUT, timeout=1200)
    contents = log.read_text()
    assert "CAPTURE complete" in contents, contents[-7000:]
    assert not any(term in contents for term in ["SCRIPT ERROR", "Parse Error", "Assertion failed"]), contents[-7000:]
    assert source["files"] == source_hashes(), "Gameplay changed during capture; recapture the current source"
    if not dry_run:
        assert (PACKAGE / "work" / f"{name}.rgb").stat().st_size == width * height * 3 * FPS * SECONDS
    return read_json(PACKAGE / "sources" / f"{name}.json")


def encode_picture(format_name):
    width, height = FORMATS[format_name]
    name = stem(format_name)
    output = PACKAGE / "work" / f"{name}-base.mp4"
    graph = (
        "[0:v]scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p[v];"
        f"[1:a]atrim=start=0.5:end={SECONDS + 0.5},asetpts=PTS-STARTPTS,"
        "afade=t=out:st=15.5:d=1.5[sfx];"
        f"[2:a]atrim=start=14:end={14 + SECONDS},asetpts=PTS-STARTPTS,volume=0.3[music];"
        "[sfx][music]amix=inputs=2:duration=longest:normalize=0,"
        f"loudnorm=I=-16:TP=-1.5:LRA=9,afade=t=in:d=0.08,afade=t=out:st={SECONDS - 0.7}:d=0.7[a]"
    )
    run([
        "ffmpeg", "-hide_banner", "-loglevel", "warning", "-y",
        "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", f"{width}x{height}",
        "-framerate", FPS, "-i", PACKAGE / "work" / f"{name}.rgb",
        "-i", PACKAGE / "work" / f"{name}-timing.avi",
        "-i", REPO / "assets/audio/battle_bgm.mp3",
        "-filter_complex_threads", "2", "-filter_complex", graph,
        "-map", "[v]", "-map", "[a]", "-t", SECONDS,
        "-c:v", "libx264", "-preset", "medium", "-crf", "16", "-threads", "4",
        "-profile:v", "high", "-level:v", "4.2", "-g", "60", "-bf", "2",
        "-maxrate", "20M", "-bufsize", "20M",
        "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709",
        "-c:a", "aac", "-b:a", "192k", "-ar", RATE, "-ac", "2",
        "-movflags", "+faststart", "-use_editlist", "0", output,
    ])
    return output


def samples(path):
    return array.array("f", subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le",
        "-ac", "1", "-ar", str(RATE), "-",
    ]))


def transient_seconds(path):
    signal = samples(path)
    window = round(RATE * 0.003)
    energies = [sum(value * value for value in signal[start:start + window])
                for start in range(0, len(signal), window)]
    return max(range(len(energies)), key=energies.__getitem__) * window / RATE


def video_packets(path):
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0", "-show_packets",
        "-show_entries", "packet=pts_time,dts_time,duration_time,data_hash",
        "-show_data_hash", "sha256", "-of", "json", str(path),
    ]))["packets"]


def mix_effects(source, format_name):
    pop = PILOT / "exports/cocoon-heavy-pop.wav"
    packets = video_packets(source)
    start = min(float(packet["pts_time"]) for packet in packets)
    reveal = start + 2.5
    pop_delay = round((reveal - transient_seconds(pop)) * RATE)
    duck_start, hold, recover = reveal - 0.18, reveal + 0.24, reveal + 0.5
    duck = (f"if(lt(t,{duck_start}),1,if(lt(t,{reveal}),"
            f"1-0.93*(t-{duck_start})/0.18,if(lt(t,{hold}),0.07,"
            f"if(lt(t,{recover}),0.07+0.93*(t-{hold})/0.26,1))))")
    graph = (
        f"[0:a]aresample={RATE},volume='{duck}':eval=frame[bed];"
        f"[1:a]adelay={pop_delay}S:all=1[pop];"
        "[bed][pop]amix=inputs=2:duration=first:normalize=0,"
        "alimiter=limit=0.78:level=false:latency=true[a]"
    )
    output = PACKAGE / "exports" / f"auto-shrooms-{stem(format_name)}.mp4"
    run([
        "ffmpeg", "-v", "error", "-y", "-copyts", "-i", source, "-i", pop,
        "-filter_complex", graph, "-map", "0:v:0", "-map", "[a]",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", RATE,
        "-ac", "2", "-movflags", "+faststart", output,
    ])
    assert video_packets(output) == packets
    return output, {
        "picture_start_seconds": start, "pop_transient_seconds": reveal,
        "pop_source": str(pop.relative_to(REPO)), "pop_bed_gain": 0.07,
        "mix_restored_seconds": recover,
        "combat_audio": "Native bow/bomb launch, canopy catch/bounce, and combat cues. No meme clang.",
        "audition": "Technical checks only; subjective listening review required.",
    }


def previews(output, format_name):
    name = stem(format_name)
    cover = PACKAGE / "exports" / f"umbrella-{format_name}-cover-v{VERSION}.jpg"
    run(["ffmpeg", "-v", "error", "-y", "-ss", "0.2", "-i", output,
         "-frames:v", "1", "-q:v", "2", cover])
    frames = []
    size = "216:384" if format_name == "portrait" else "384:216"
    for index, seconds in enumerate([0.2, 0.65, 1.85, 2.7, 3.4, 5.4, 7.7, 10.3, 12.5, 14.8, 16.3, 18.5]):
        destination = PACKAGE / "preview" / f"export-{name}-{index}.jpg"
        run(["ffmpeg", "-v", "error", "-y", "-ss", seconds, "-i", output,
             "-frames:v", "1", "-vf", f"scale={size}", destination])
        frames.append(destination)
    run(["magick", "montage", "-font", REPO / "assets/fonts/SpicyRice-Regular.ttf",
         *frames, "-tile", "6x2", "-geometry", "+4+4",
         "-background", "#101b15", PACKAGE / "preview" / f"storyboard-{name}.jpg"])


def verify_capture(metadata, format_name, dry_run=False):
    width, height = FORMATS[format_name]
    assert metadata["frames"] == (0 if dry_run else FPS * SECONDS)
    assert metadata["version"] == VERSION
    assert metadata["format"] == format_name
    assert (metadata["width"], metadata["height"]) == (width, height)
    assert metadata["recipe"] == [1, 3]
    assert not metadata["visibility_failures"], metadata["visibility_failures"][:10]
    assert not metadata["intro_visibility_failures"], metadata["intro_visibility_failures"][:10]
    events = metadata["events"]
    at = lambda action: next(event for event in events if event.get("action") == action)
    gameplay = at("gameplay_source")
    for key, path in {
        "unit_script_sha256": "assets/units/unit.gd",
        "unit_appearance_sha256": "assets/units/unit_appearance.gd",
        "projectile_script_sha256": "assets/combat/projectile/projectile.gd",
        "blocker_script_sha256": "assets/combat/projectile/projectile_blocker.gd",
        "umbrella_resource_sha256": "assets/weapons/umbrella/umbrella.tres",
        "umbrella_scene_sha256": "assets/weapons/umbrella/umbrella_appearance.tscn",
        "mortar_projectile_sha256": "assets/weapons/mortar/mortar_projectile.tscn",
        "enemy_resource_sha256": "assets/units/enemies/peashooter/peashooter_unit.tres",
        "seed_lobber_resource_sha256": "assets/units/enemies/seed_lobber/seed_lobber_unit.tres",
    }.items():
        assert gameplay[key] == hashlib.sha256((REPO / path).read_bytes()).hexdigest(), path
    for action, frame in {
        "walk_started": 21, "cocoon_closed": 51, "cocoon_reveal": 150,
        "reveal_landing": 186, "weapon_name": 240, "outro_started": 840,
        "combat_fade_started": 930, "combat_black": 1020,
        "closing_question_started": 1029, "closing_question_settled": 1053,
    }.items():
        assert at(action)["frame"] == frame, action
    assert at("combat_black")["fade_alpha"] == 1
    assert at("closing_question_started")["combat_fade_alpha"] == 1
    assert at("closing_question_settled")["alpha"] == 1
    assert metadata["outro"]["subtitle"] == "Weapon combos"
    assert metadata["steam_cta"] is False
    assert metadata["result_label"] == "Umbrella Shield"
    assert math.isclose(metadata["equation_center_x"], width / 2, abs_tol=0.01)
    assert metadata["equation_paper_source_size"] == {"width": 1220, "height": 380}
    assert metadata["equation_paper_filter"] == "linear"
    reveal = at("cocoon_reveal")
    assert reveal["complete_equation"] and reveal["shell_pieces"] == 2
    single, army = at("single"), at("army")
    assert (single["players"], single["enemies"]) == (1, 3)
    assert (army["players"], army["enemies"]) == (9, 18)
    assert (army["player_adults"], army["player_children"]) == (6, 3)
    children = [unit for unit in army["player_specs"] if unit["life_stage"] == "child"]
    assert [unit["slot"] for unit in children] == [1, 4, 7]
    assert all(unit["source"] == "native_lineage_spore_harvest" for unit in children)
    for unit in army["player_specs"]:
        assert unit["weapon"] == "Umbrella Shield" and unit["trainings"] == [1, 3]
        assert all(unit[key] == 1 for key in [
            "unit_scale_x", "unit_scale_y", "appearance_scale_x", "appearance_scale_y",
        ])
    assert single["enemy_counts"] == {"seed_lobber": 3}
    assert army["enemy_counts"] == {"peashooter": 9, "seed_lobber": 9}
    enemy_profiles = {
        "peashooter": ("res://assets/weapons/bow/bow.tres", True, "res://assets/weapons/bow/arrow_projectile.tscn"),
        "seed_lobber": ("res://assets/weapons/mortar/mortar.tres", False, "res://assets/weapons/mortar/mortar_projectile.tscn"),
    }
    for setup in [single, army]:
        assert setup["weapon"] == "Umbrella Shield"
        assert len(setup["enemy_specs"]) == setup["enemies"]
        assert Counter(enemy["type"] for enemy in setup["enemy_specs"]) == setup["enemy_counts"]
        for enemy in setup["enemy_specs"]:
            assert (enemy["held_weapon_path"], enemy["show_held_weapon"], enemy["projectile_path"]) == enemy_profiles[enemy["type"]]
    metrics = metadata["shot_metrics"]
    for shot, metric in metrics.items():
        if shot in ["single_wide", "army_wide", "army_launch"]:
            assert metric["frames_all_players_visible"] == metric["frames"], (shot, metric)
        if shot in ["single_wide", "army_wide"]:
            assert metric["frames_all_enemies_visible"] == metric["frames"], (shot, metric)
    assert metrics["single_wide"]["visible_bounces"] > 0, "Solo shot must show a real bomb bounce"
    assert metrics["army_launch"]["visible_catches"] + metrics["army_launch"]["visible_bounces"] > 0, "Player shot needs visible defense"
    for effect in ["visible_catches", "visible_bounces"]:
        assert sum(metric[effect] for shot, metric in metrics.items() if shot.startswith("army")) > 0, effect
    assert any(event.get("action") in ["enemy_arrow_launch", "enemy_bomb_launch"]
               and event["shot"] == "army_impact" and event["visible"] for event in events), "Enemy shot needs a visible launch"
    defenses = metadata["defense_events"]
    for event in defenses:
        assert event["hit_targets"] == 0 and event["weapon"] == "Umbrella Shield"
        if event["action"] == "arrow_caught":
            assert event["native_spent"] and event["attached_to_blocker"] and event["attachment_stable"]
        else:
            assert event["action"] == "bomb_bounced" and not event["native_spent"]
            assert event["native_bounced_blocker"] and event["fuse_armed"]
            assert event["outgoing_dot_normal"] > 0
    assert any(event["action"] == "arrow_caught" and event["moves_with_canopy"] for event in defenses)
    if format_name == "landscape":
        layout = metadata["layout"]
        assert math.isclose(layout["intro_ground_y"], 960, abs_tol=1)
        assert math.isclose(layout["entry_x"], 705, abs_tol=1)
        assert math.isclose(layout["cocoon_x"], 1120, abs_tol=1)
        assert layout["reveal_direction"] == "left"
        assert layout["reveal_apex_x"] < layout["cocoon_x"]
        assert layout["landing_x"] < layout["cocoon_x"]
        assert layout["reveal_trajectory"] == "parabola"
        assert math.isclose(layout["reveal_apex_x"], (layout["cocoon_x"] + layout["landing_x"]) / 2)
        flight = [sample for sample in metadata["reveal_bounds"] if 150 <= sample["frame"] <= 186]
        assert [sample["frame"] for sample in flight] == list(range(150, 187))
        for sample in metadata["reveal_bounds"]:
            progress = min((sample["frame"] - 150) / 36, 1)
            expected_x = layout["cocoon_x"] + (layout["landing_x"] - layout["cocoon_x"]) * progress
            expected_y = layout["intro_ground_y"] - 4 * layout["reveal_hop_height"] * progress * (1 - progress)
            assert math.isclose(sample["actor_x"], expected_x, abs_tol=0.01), sample
            assert math.isclose(sample["actor_y"], expected_y, abs_tol=0.01), sample
        assert all(b["actor_x"] < a["actor_x"] for a, b in zip(flight, flight[1:]))
    cycle = [event for event in events if event.get("action") == "outro_input"]
    for slot in range(2):
        frames = [event["frame"] for event in cycle if event["slot"] == slot]
        assert len(frames) >= 39 and frames[-1] >= FPS * SECONDS - 10
        assert all(b - a <= 9 for a, b in zip(frames, frames[1:]))
    assert all(not event["result_visible"] and event["valid_result"] for event in cycle)
    cuts = [event for event in events if event.get("action") == "cut"]
    assert [event["shot"] for event in cuts] == ["single_wide", "army_launch", "army_impact", "army_wide"]
    for event in cuts:
        assert not event["screen_fixed_forest_visible"]
        assert math.isclose(event["background_screen_scale"], 0.5 * event["zoom"], abs_tol=0.000001)
    return {
        "gameplay_source": gameplay, "recipe": "Shield + Bow = Umbrella Shield",
        "army": "6 Adults + 3 Children versus 9 Peashooters + 9 Seed Lobbers",
        "single_enemy_counts": single["enemy_counts"], "army_enemy_counts": army["enemy_counts"],
        "defense_counts": dict(Counter(event["action"] for event in defenses)),
        "single_starting_gap_world": single["nearest_front_gap"],
        "army_starting_gap_world": army["nearest_front_gap"],
        "visibility_checked_every_frame": True, "shot_metrics": metrics,
        "closing_inputs_cycle_to_end": True, "steam_cta": False,
        "unit_body_sizes_unchanged": True, "camera_cuts": cuts,
        "intro_framing": {key: metadata["layout"][key] for key in [
            "intro_ground_y", "cocoon_x", "entry_x", "reveal_apex_x",
            "landing_x", "reveal_direction",
            "reveal_trajectory", "reveal_hop_height",
        ]},
    }


def encoded_region(output, seconds, rect):
    crop = ":".join(str(round(rect[key])) for key in ["width", "height", "x", "y"])
    return subprocess.check_output([
        "ffmpeg", "-v", "error", "-ss", str(seconds), "-i", str(output),
        "-frames:v", "1", "-vf", "crop=" + crop, "-pix_fmt", "rgb24", "-f", "rawvideo", "-",
    ])


def verify_outro_pixels(output, metadata):
    layout = metadata["layout"]
    black = encoded_region(output, 17.08, layout["combat_black_probe"])
    before = encoded_region(output, 17.08, layout["question"])
    after = encoded_region(output, 18.5, layout["question"])
    cta = encoded_region(output, 18.5, layout["cta_probe"])
    assert max(black) <= 3 and max(before) <= 3
    assert sum(after) / len(after) > 5
    assert max(cta) <= 3
    earlier = encoded_region(output, 19.7, layout["first_input"])
    final = encoded_region(output, 19.98, layout["first_input"])
    assert sum(abs(a - b) > 15 for a, b in zip(earlier, final)) > 1000
    return {"combat_black_before_question": True, "question_visible_after_black": True,
            "steam_cta_area_black": True, "input_changed_near_last_frame": True}


def verify(output, metadata, mix, format_name):
    width, height = FORMATS[format_name]
    composition = verify_capture(metadata, format_name)
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(output),
    ]))
    video = next(stream for stream in probe["streams"] if stream["codec_type"] == "video")
    audio = next(stream for stream in probe["streams"] if stream["codec_type"] == "audio")
    assert (video["width"], video["height"], video["pix_fmt"]) == (width, height, "yuv420p")
    assert video["r_frame_rate"] == "60/1" and int(video["nb_frames"]) == FPS * SECONDS
    assert audio["codec_name"] == "aac" and audio["sample_rate"] == "48000" and audio["channels"] == 2
    run(["ffmpeg", "-v", "error", "-i", output, "-f", "null", "-"])
    loudness = run([
        "ffmpeg", "-hide_banner", "-i", output, "-af",
        "loudnorm=I=-16:TP=-1.5:LRA=9:print_format=json", "-f", "null", "-",
    ], capture_output=True, text=True).stderr
    metrics, _ = json.JSONDecoder().raw_decode(loudness[loudness.rfind("{"):])
    assert float(metrics["input_tp"]) <= -1.0
    report = {
        "file": output.name, "width": width, "height": height, "fps": FPS, "frames": FPS * SECONDS,
        "duration": float(probe["format"]["duration"]), "bytes": output.stat().st_size,
        "full_decode": "passed", "audio": {"codec": "aac", "sample_rate": RATE,
            "integrated_lufs": metrics["input_i"], "true_peak_dbtp": metrics["input_tp"], **mix},
        "capture_metadata": f"sources/{stem(format_name)}.json", "composition": composition,
        "gameplay_provenance": read_json(PACKAGE / "sources" / f"{stem(format_name)}-source.json"),
        "encoded_outro_checks": verify_outro_pixels(output, metadata),
        "scope": "Native Umbrella combat reel. No posting or gameplay changes.",
    }
    write_json(PACKAGE / f"validation-{format_name}-v{VERSION}.json", report)
    previews(output, format_name)
    print(json.dumps({key: report[key] for key in ["file", "width", "height", "fps", "frames", "bytes"]}), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--format", choices=[*FORMATS, "all"], default="all")
    parser.add_argument("--capture", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--remix-only", action="store_true")
    args = parser.parse_args()
    for folder in ["sources", "work", "exports", "preview"]:
        (PACKAGE / folder).mkdir(exist_ok=True)
    selected = list(FORMATS) if args.format == "all" else [args.format]
    for format_name in selected:
        if args.dry_run:
            print(json.dumps(verify_capture(capture(format_name, True), format_name, dry_run=True), indent=2))
        else:
            metadata = capture(format_name) if args.capture else read_json(PACKAGE / "sources" / f"{stem(format_name)}.json")
            verify_capture(metadata, format_name)
            base = PACKAGE / "work" / f"{stem(format_name)}-base.mp4" if args.remix_only else encode_picture(format_name)
            output, mix = mix_effects(base, format_name)
            verify(output, metadata, mix, format_name)
