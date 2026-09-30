#!/usr/bin/env python3
"""Capture the Great Sword reel and sync selective meme accents to real hits."""
import argparse
import array
import hashlib
import json
import math
import pathlib
import shutil
import subprocess

PACKAGE = pathlib.Path(__file__).resolve().parent
REPO = PACKAGE.parents[2]
PILOT = PACKAGE.parent / "2026-09-28-combo-reels"
SLUG = "great-sword"
VERSION = 3
FPS = 60
RATE = 48000
SECONDS = 20
FONT = REPO / "assets/fonts/SpicyRice-Regular.ttf"


def run(command, **kwargs):
    return subprocess.run(list(map(str, command)), check=True, **kwargs)


def read_json(path):
    return json.loads(path.read_text())


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def capture(dry_run=False):
    command = [
        "godot", "--path", REPO, "--rendering-method", "gl_compatibility",
        "--rendering-driver", "opengl3", "--windowed", "--resolution", "540x960",
        "--fixed-fps", FPS, "--disable-vsync", "--quit-after", "6000",
    ]
    movie = f"dry-run-v{VERSION}-timing.avi" if dry_run else f"great-sword-v{VERSION}-timing.avi"
    command += ["--write-movie", PACKAGE / "work" / movie]
    command += [PACKAGE / "capture.tscn", "--", f"weapon={SLUG}", "probe"]
    if not dry_run:
        command += [f"raw_capture={PACKAGE / f'work/great-sword-v{VERSION}.rgb'}"]
    log = PACKAGE / "sources" / (f"dry-run-v{VERSION}.log" if dry_run else f"{SLUG}-v{VERSION}.log")
    print("Dry-running" if dry_run else "Capturing", "Great Sword", flush=True)
    with log.open("w") as stream:
        run(command, cwd=REPO, stdout=stream, stderr=subprocess.STDOUT, timeout=1200)
    contents = log.read_text()
    assert "CAPTURE complete" in contents, contents[-7000:]
    assert not any(term in contents for term in ["SCRIPT ERROR", "Parse Error", "Assertion failed"]), contents[-7000:]
    if not dry_run:
        assert (PACKAGE / f"work/great-sword-v{VERSION}.rgb").stat().st_size == 1080 * 1920 * 3 * FPS * SECONDS
    return read_json(PACKAGE / "sources" / f"{SLUG}-v{VERSION}.json")


def encode_picture():
    output = PACKAGE / f"work/great-sword-base-v{VERSION}.mp4"
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
        "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", "1080x1920",
        "-framerate", FPS, "-i", PACKAGE / f"work/great-sword-v{VERSION}.rgb",
        "-i", PACKAGE / f"work/great-sword-v{VERSION}-timing.avi",
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


def samples(path, channels=1):
    return array.array("f", subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le",
        "-ac", str(channels), "-ar", str(RATE), "-",
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


def choose_accents(metadata):
    # Select separated, visible player hits, not a replacement for every swing.
    hits = [event for event in metadata["events"] if event.get("action") == "player_hit"]
    selected = []
    for start, end in [(4.25, 6.5), (6.6, 8.9), (9.1, 11.25), (11.35, 13.4)]:
        candidates = [hit for hit in hits if start <= hit["frame"] / FPS < end
                      and hit.get("visible", True)
                      and (not selected or hit["frame"] - selected[-1]["frame"] >= 84)]
        if candidates:
            selected.append(candidates[0])
    assert len(selected) >= 3, "Need three clearly visible, separated clang accents"
    return selected


def prepare_clang():
    source = PACKAGE / "sources/berserk-clang.mp3"
    destination = PACKAGE / "work/berserk-clang.wav"
    run([
        "ffmpeg", "-v", "error", "-y", "-i", source,
        "-af", "atrim=end=1.176,asetpts=PTS-STARTPTS,highpass=f=65,afade=t=out:st=0.92:d=0.256",
        "-ar", RATE, "-ac", "2", "-c:a", "pcm_f32le", destination,
    ])
    peak = max(abs(value) for value in samples(destination, channels=2))
    assert peak > 0
    return destination, 10 ** (-7.0 / 20) / peak


def mix_effects(source, metadata):
    pop = PILOT / "exports/cocoon-heavy-pop.wav"
    clang, clang_gain = prepare_clang()
    packets = video_packets(source)
    start = min(float(packet["pts_time"]) for packet in packets)
    reveal = start + 2.5
    pop_delay = round((reveal - transient_seconds(pop)) * RATE)
    duck_start, hold, recover = reveal - 0.18, reveal + 0.24, reveal + 0.5
    duck = (f"if(lt(t,{duck_start}),1,if(lt(t,{reveal}),"
            f"1-0.93*(t-{duck_start})/0.18,if(lt(t,{hold}),0.07,"
            f"if(lt(t,{recover}),0.07+0.93*(t-{hold})/0.26,1))))")
    accents = choose_accents(metadata)
    # This clang has an immediate attack and a louder later resonance. Align
    # its onset, not that later maximum, so it never anticipates the sword hit.
    clang_transient = 0.0
    graph = [
        f"[0:a]aresample={RATE},volume='{duck}':eval=frame[bed]",
        f"[1:a]adelay={pop_delay}S:all=1[pop]",
        f"[2:a]volume={clang_gain:.9f},asplit={len(accents)}"
        + "".join(f"[c{index}]" for index in range(len(accents))),
    ]
    for index, event in enumerate(accents):
        event["accent_seconds"] = start + event["frame"] / FPS
        delay = round((event["accent_seconds"] - clang_transient) * RATE)
        graph.append(f"[c{index}]adelay={delay}S:all=1[hit{index}]")
    inputs = "[bed][pop]" + "".join(f"[hit{index}]" for index in range(len(accents)))
    graph.append(inputs + f"amix=inputs={len(accents) + 2}:duration=first:normalize=0,"
                 "alimiter=limit=0.78:level=false:latency=true[a]")
    output = PACKAGE / f"exports/auto-shrooms-great-sword-v{VERSION}.mp4"
    run([
        "ffmpeg", "-v", "error", "-y", "-copyts", "-i", source, "-i", pop, "-i", clang,
        "-filter_complex", ";".join(graph), "-map", "0:v:0", "-map", "[a]",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", RATE,
        "-ac", "2", "-movflags", "+faststart", output,
    ])
    assert video_packets(output) == packets
    return output, {
        "picture_start_seconds": start, "pop_transient_seconds": reveal,
        "pop_source": str(pop.relative_to(REPO)), "pop_bed_gain": 0.07,
        "mix_restored_seconds": recover, "clang_accents": accents,
        "clang_transient_local_seconds": clang_transient,
        "clang_source_sha256": hashlib.sha256((PACKAGE / "sources/berserk-clang.mp3").read_bytes()).hexdigest(),
        "audition": "Technical checks only; subjective listening review required.",
        "clang_rights": "Third-party meme recording; commercial reuse rights unverified.",
    }


def previews(output):
    cover = PACKAGE / f"exports/great-sword-cover-v{VERSION}.jpg"
    run(["ffmpeg", "-v", "error", "-y", "-ss", "0.2", "-i", output,
         "-frames:v", "1", "-q:v", "2", cover])
    shutil.copy2(cover, PACKAGE / "exports/great-sword-cover.jpg")
    frames = []
    for index, seconds in enumerate([0.2, 0.65, 1.85, 2.7, 3.4, 5.4, 7.7, 10.3, 12.5, 14.8, 16.3, 18.5]):
        destination = PACKAGE / "preview" / f"export-v{VERSION}-{index}.jpg"
        run(["ffmpeg", "-v", "error", "-y", "-ss", seconds, "-i", output,
             "-frames:v", "1", "-vf", "scale=216:384", destination])
        frames.append(destination)
    run(["magick", "montage", "-font", FONT, *frames, "-tile", "6x2",
         "-geometry", "+4+4", "-background", "#101b15", PACKAGE / f"preview/storyboard-v{VERSION}.jpg"])


def verify_capture(metadata, dry_run=False):
    assert metadata["frames"] == (0 if dry_run else FPS * SECONDS)
    assert metadata["version"] == VERSION
    assert metadata["recipe"] == [0, 0]
    assert not metadata["visibility_failures"], metadata["visibility_failures"]
    events = metadata["events"]
    at = lambda action: next(event for event in events if event.get("action") == action)
    gameplay = at("gameplay_source")
    assert math.isclose(gameplay["knockback_recovery_seconds"], 0.35)
    assert gameplay["unit_script_sha256"] == hashlib.sha256((REPO / "assets/units/unit.gd").read_bytes()).hexdigest()
    assert at("walk_started")["frame"] == 21
    assert at("cocoon_closed")["frame"] == 51
    assert at("cocoon_reveal")["frame"] == 150
    assert at("reveal_landing")["frame"] == 186
    assert at("weapon_name")["frame"] == 240
    assert at("outro_started")["frame"] == 840
    assert at("combat_fade_started")["frame"] == 930
    assert at("combat_black")["frame"] == 1020
    assert at("combat_black")["fade_alpha"] == 1
    assert at("closing_question_started")["frame"] == 1029
    assert at("closing_question_started")["combat_fade_alpha"] == 1
    assert at("closing_question_settled")["frame"] == 1053
    assert at("closing_question_settled")["alpha"] == 1
    assert metadata["outro"]["subtitle"] == "Weapon combos"
    assert metadata["steam_cta"] is False
    assert metadata["result_label"] == "Great Sword"
    assert metadata["equation_paper_source_size"] == {"width": 1220, "height": 380}
    assert metadata["equation_paper_filter"] == "linear"
    paper = at("equation_paper_layout")
    assert (paper["x"], paper["y"], paper["width"], paper["height"]) == (90, 452, 900, 283)
    reveal = at("cocoon_reveal")
    assert reveal["complete_equation"] and reveal["shell_pieces"] == 2
    assert reveal["hop_height"] == 240 and reveal["unit_scale"] == 1.65
    single, army = at("single"), at("army")
    assert (single["players"], single["enemies"]) == (1, 3)
    assert single["enemy_type"] == "rose_thorn"
    assert single["enemy_home_slot_spacing"] == 54
    assert metadata["aoe_swings"], "Solo demonstration must prove a genuine area hit"
    assert any(event["enemy_count"] >= 2 for event in metadata["aoe_swings"])
    assert (army["players"], army["enemies"]) == (9, 18)
    assert (army["player_adults"], army["player_children"]) == (6, 3)
    assert len(army["player_specs"]) == 9
    children = [unit for unit in army["player_specs"] if unit["life_stage"] == "child"]
    assert [unit["slot"] for unit in children] == [1, 4, 7]
    assert all(unit["source"] == "native_lineage_spore_harvest" for unit in children)
    for unit in army["player_specs"]:
        assert unit["weapon"] == "Great Sword" and unit["trainings"] == [0, 0]
        assert all(unit[key] == 1 for key in [
            "unit_scale_x", "unit_scale_y", "appearance_scale_x", "appearance_scale_y",
        ])
    for setup in [single, army]:
        assert setup["weapon"] == "Great Sword"
        assert setup["profile"]["melee_range"] == 144
        assert setup["profile"]["attack_interval"] == 2.5
        assert 300 <= setup["nearest_front_gap"] <= 315
    for shot, metric in metadata["shot_metrics"].items():
        assert metric["damage"] > 0
        if shot != "single_wide":
            assert metric["min_enemies_alive"] > 0
        if shot in ["single_wide", "army_wide", "army_launch"]:
            assert metric["frames_all_players_visible"] == metric["frames"]
        if shot in ["single_wide", "army_wide"]:
            assert metric["frames_all_enemies_visible"] == metric["frames"]
    launch = metadata["shot_metrics"]["army_launch"]
    assert 540 < launch["first_action_frame"] < launch["first_effect_frame"] < 678
    cycle = [event for event in events if event.get("action") == "outro_input"]
    for slot in range(2):
        frames = [event["frame"] for event in cycle if event["slot"] == slot]
        assert len(frames) >= 39 and frames[-1] >= FPS * SECONDS - 10
        assert all(b - a <= 9 for a, b in zip(frames, frames[1:]))
    assert all(not event["result_visible"] and event["valid_result"] for event in cycle)
    return {
        "gameplay_source": gameplay,
        "recipe": "Sword + Sword = Great Sword", "army": "6 Adults + 3 Children versus 18 Solar Swords",
        "player_adults": army["player_adults"], "player_children": army["player_children"],
        "child_slots": [unit["slot"] for unit in children],
        "children_inherit_combo_through_native_lineage": True,
        "starting_gap_world": army["nearest_front_gap"], "melee_engage_range": 126,
        "first_army_swing_seconds": launch["first_action_frame"] / FPS,
        "first_army_hit_seconds": launch["first_effect_frame"] / FPS,
        "visibility_checked_every_frame": True, "shot_metrics": metadata["shot_metrics"],
        "closing_inputs_cycle_to_end": True, "outro_changes": len(cycle),
        "solo_enemy_type": single["enemy_type"], "solo_enemy_spacing": single["enemy_home_slot_spacing"],
        "aoe_swings": metadata["aoe_swings"], "outro": metadata["outro"],
        "title_top_y": 215, "subtitle_top_y": 350, "steam_cta": False,
        "equation_paper_backing": True, "unit_body_sizes_unchanged": True,
    }


def encoded_region(output, seconds, crop):
    return subprocess.check_output([
        "ffmpeg", "-v", "error", "-ss", str(seconds), "-i", str(output),
        "-frames:v", "1", "-vf", "crop=" + crop, "-pix_fmt", "rgb24", "-f", "rawvideo", "-",
    ])


def verify_outro_pixels(output):
    black = encoded_region(output, 17.08, "1080:240:0:780")
    before_question = encoded_region(output, 17.08, "890:160:95:1040")
    question = encoded_region(output, 18.5, "890:160:95:1040")
    cta_area = encoded_region(output, 18.5, "880:200:100:1450")
    assert max(black) <= 3 and max(before_question) <= 3
    assert sum(question) / len(question) > 5
    assert max(cta_area) <= 3, "No Steam CTA should remain on the end card"
    earlier = encoded_region(output, 19.7, "180:180:142:478")
    final = encoded_region(output, 19.98, "180:180:142:478")
    changes = sum(abs(a - b) > 15 for a, b in zip(earlier, final))
    assert changes > 1000, "Input icons must keep changing on the extended ending"
    return {"combat_black_before_question": True, "question_visible_after_black": True,
            "steam_cta_area_black": True, "input_changed_near_last_frame": True}


def verify(output, metadata, mix):
    composition = verify_capture(metadata)
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(output),
    ]))
    video = next(stream for stream in probe["streams"] if stream["codec_type"] == "video")
    audio = next(stream for stream in probe["streams"] if stream["codec_type"] == "audio")
    assert (video["width"], video["height"], video["pix_fmt"]) == (1080, 1920, "yuv420p")
    assert video["r_frame_rate"] == "60/1" and int(video["nb_frames"]) == FPS * SECONDS
    assert audio["codec_name"] == "aac" and audio["sample_rate"] == "48000" and audio["channels"] == 2
    run(["ffmpeg", "-v", "error", "-i", output, "-f", "null", "-"])
    loudness = run([
        "ffmpeg", "-hide_banner", "-i", output, "-af",
        "loudnorm=I=-16:TP=-1.5:LRA=9:print_format=json", "-f", "null", "-",
    ], capture_output=True, text=True).stderr
    metrics, _ = json.JSONDecoder().raw_decode(loudness[loudness.rfind("{"):])
    assert float(metrics["input_tp"]) <= -1.0
    assert metadata["equation_center_x"] == 540
    army = next(event for event in metadata["events"] if event.get("action") == "army")
    assert army["players"] == 9 and army["enemies"] == 18 and army["weapon"] == "Great Sword"
    cuts = [event for event in metadata["events"] if event.get("action") == "cut"]
    assert [event["shot"] for event in cuts] == ["single_wide", "army_launch", "army_impact", "army_wide"]
    for event in cuts:
        assert not event["screen_fixed_forest_visible"]
        assert math.isclose(event["background_screen_scale"], 0.5 * event["zoom"], abs_tol=0.000001)
    assert cuts[-1]["zoom"] < cuts[-2]["zoom"]
    report = {
        "file": output.name, "width": 1080, "height": 1920, "fps": 60, "frames": FPS * SECONDS,
        "duration": float(probe["format"]["duration"]), "bytes": output.stat().st_size,
        "full_decode": "passed", "audio": {"codec": "aac", "sample_rate": RATE,
            "integrated_lufs": metrics["input_i"], "true_peak_dbtp": metrics["input_tp"], **mix},
        "capture_metadata": f"sources/{SLUG}-v{VERSION}.json",
        "composition": composition,
        "encoded_outro_checks": verify_outro_pixels(output),
        "camera_cuts": cuts,
        "scope": "One Great Sword reel for review. No posting or gameplay changes.",
    }
    write_json(PACKAGE / f"validation-v{VERSION}.json", report)
    previews(output)
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--capture", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--remix-only", action="store_true")
    args = parser.parse_args()
    for folder in ["sources", "work", "exports", "preview"]:
        (PACKAGE / folder).mkdir(exist_ok=True)
    if args.dry_run:
        print(json.dumps(verify_capture(capture(True), dry_run=True), indent=2))
    else:
        metadata = capture() if args.capture else read_json(PACKAGE / f"sources/{SLUG}-v{VERSION}.json")
        base = PACKAGE / f"work/great-sword-base-v{VERSION}.mp4" if args.remix_only else encode_picture()
        output, mix = mix_effects(base, metadata)
        verify(output, metadata, mix)
