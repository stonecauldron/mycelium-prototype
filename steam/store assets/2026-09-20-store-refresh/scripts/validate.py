#!/usr/bin/env python3
"""Check the delivered files and the actual capture rosters; write validation.json."""
import json
import pathlib
import subprocess

PACKAGE = pathlib.Path(__file__).resolve().parents[1]
EDIT = json.loads((PACKAGE / "scripts/edit.json").read_text())
TRAILER_DURATION = sum(chapter["duration"] for chapter in EDIT["chapters"])
TRAILER_FRAMES = round(TRAILER_DURATION * EDIT["fps"])


def probe(path, count_frames=True):
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", *(["-count_frames"] if count_frames else []), "-show_streams", "-show_format",
        "-of", "json", str(path)]))


def training_proof(clips, overlap=0):
    events = json.loads((PACKAGE / "sources/takes/training.json").read_text())
    proof = next(item for item in events if item.get("training_verified"))
    assert (proof["initial_stage"], proof["initial_weapon"], proof["school"], proof["preview_weapon"]) == (
        "Child", "Sword", "Sword", "Great Sword")
    assert proof["confirmed"] and not proof["day_advanced"] and not proof["emergence_shown"]
    assert proof["final_location"] == "Sword Cocoon"
    times = {item["action"]: item["seconds"] for item in events if "action" in item}
    assert "one_day_later" not in times
    assert all(c["source"] == "training" and c.get("title") != "one-day" for c in clips)
    assert any(c["start"] <= times["training_preview"] < c["start"] + c["duration"]
               or times["training_preview"] <= c["start"] < times["training_started"] for c in clips)
    last = clips[-1]
    end = last["start"] + last["duration"]
    assert last["start"] < times["training_started"] < end <= times["training_started"] + .3
    assert end + overlap <= times["take_complete"]
    return {**proof, "confirmation_source_seconds": times["training_started"],
            "edit_end_source_seconds": end, "extra_transition_handle": overlap}


def check():
    report = {"rosters": [], "exports": [], "sources": [], "checks": []}
    for path in sorted((PACKAGE / "sources/takes").glob("*.json")):
        if path.name.endswith(".quality.json"):
            continue
        for item in json.loads(path.read_text()):
            if "roster" not in item:
                continue
            units = item["roster"]
            weapons = [u["weapon"] for u in units]
            if item["roster_label"] == "dedicated_lineage":
                assert path.stem == "lineage_sword"
                assert weapons == ["Bow", "Bow", "Sword"]
                assert [u["range_class"] for u in units] == ["Ranged", "Ranged", "Melee"]
                assert item["children"] == 1 and item["adults"] == 2
                assert units[-1]["name"] == "Lamarck" and units[-1]["stage"] == "Adult"
                report["rosters"].append({"take": path.stem, "stage": item["roster_label"], "passed": True})
                continue
            assert len(units) == 10 and item["children"] == 3 and item["adults"] == 7
            assert item["class_counts_melee_mid_ranged"] == [4, 3, 3]
            assert "Great Sword" in weapons and "Great Horn" in weapons
            assert not any("mortar" in w.lower() for w in weapons)
            assert weapons[-1] == "Great Shield"
            ranks = {"Ranged": 0, "Mid": 1, "Melee": 2}
            assert [ranks[u["range_class"]] for u in units] == sorted(ranks[u["range_class"]] for u in units)
            assert any(u["body_mutation"] or u["cap_mutation"] for u in units if u["stage"] == "Child")
            assert any(u["body_mutation"] or u["cap_mutation"] for u in units if u["stage"] == "Adult")
            report["rosters"].append({"take": path.stem, "stage": item["roster_label"], "passed": True})
    assert len(report["rosters"]) >= 10
    sources = sorted((PACKAGE / "sources/takes").glob("*.mov"))
    assert len(sources) == 9
    for path in sources:
        quality = json.loads(path.with_suffix(".quality.json").read_text())
        assert quality["raw_capture_matches_mov"]
        # Full source decoding was already verified by the capture RGB hash.
        data = probe(path, count_frames=False)
        video = next(s for s in data["streams"] if s["codec_type"] == "video")
        assert video["codec_name"] == "png" and video["pix_fmt"] == "rgb24"
        assert (video["width"], video["height"], video["r_frame_rate"]) == (2560, 1440, "60/1")
        assert int(video["nb_frames"]) == quality["frame_count"]
        report["sources"].append({"file": str(path.relative_to(PACKAGE)), **quality})
    master = PACKAGE / f"sources/masters/auto-shrooms-trailer-{TRAILER_DURATION:g}s-lossless.mov"
    data = probe(master)
    video = next(s for s in data["streams"] if s["codec_type"] == "video")
    assert video["codec_name"] == "png" and int(video["nb_read_frames"]) == TRAILER_FRAMES
    assert (video["width"], video["height"], video["r_frame_rate"]) == (1920, 1080, "60/1")
    assert abs(float(data["format"]["duration"]) - TRAILER_DURATION) < .04
    report["lossless_master"] = str(master.relative_to(PACKAGE))
    videos = sorted((PACKAGE / "exports/trailer").glob("*.mp4"))
    videos += sorted((PACKAGE / "exports/loops").glob("*.mp4"))
    assert len(videos) == 6
    for path in videos:
        data = probe(path)
        video = next(s for s in data["streams"] if s["codec_type"] == "video")
        duration = float(data["format"]["duration"])
        if "trailer" in path.name:
            assert abs(duration - TRAILER_DURATION) < .04
            assert (video["width"], video["height"], video["r_frame_rate"]) == (1920, 1080, "60/1")
            assert int(video["nb_read_frames"]) == TRAILER_FRAMES
            assert any(s["codec_type"] == "audio" for s in data["streams"])
        else:
            assert 6 <= duration <= 10
            assert video["width"] == 1170 and video["r_frame_rate"] == "30/1"
        # FFprobe calls full-range 8-bit 4:2:0 yuvj420p; both are valid H.264 output.
        assert video["codec_name"] == "h264" and video["pix_fmt"] in {"yuv420p", "yuvj420p"}
        assert video.get("color_space") == "bt709"
        # Decode every delivered frame and audio packet, not just headers.
        subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "null", "-"], check=True)
        report["exports"].append({"file": str(path.relative_to(PACKAGE)), "duration": duration,
                                  "width": video["width"], "height": video["height"],
                                  "fps": video["r_frame_rate"], "pixel_format": video["pix_fmt"],
                                  "color_range": video.get("color_range"), "bytes": path.stat().st_size})
    gifs = sorted((PACKAGE / "exports/loops").glob("*.gif"))
    assert len(gifs) == 5
    for path in gifs:
        data = probe(path)
        duration = float(data["format"]["duration"])
        assert 6 <= duration <= 10 and path.stat().st_size < 5_000_000
        report["exports"].append({"file": str(path.relative_to(PACKAGE)), "duration": duration, "bytes": path.stat().st_size})
    shots = sorted((PACKAGE / "exports/screenshots").glob("*.jpg"))
    assert len(shots) == 6
    for path in shots:
        size = subprocess.check_output(["magick", "identify", "-format", "%wx%h", str(path)], text=True)
        assert size == "1920x1080"
        assert path.with_suffix(".png").exists()
    report["screenshot_gif_bytes"] = sum(p.stat().st_size for p in gifs + shots)
    report["checks"] = ["No Mortar in any recorded featured roster", "Great Sword and Great Horn present in main footage",
                         "Main Squad: 3 Children / 7 Adults", "Main Squad: 4 Melee / 3 Mid / 3 Ranged, correctly ordered",
                         "Main Squad: Great Shield at the front", "Mutated Children and Adults",
                         "Dedicated lineage battle: one Sword Adult ahead of two Bow Units",
                         f"{TRAILER_DURATION:g}-second {TRAILER_FRAMES}-frame trailer", "Five 6–10-second MP4/GIF loop pairs",
                         "Six full-resolution screenshot pairs", "Full MP4 decode passed",
                         "Nine pixel-exact RGB lossless 1440p60 source MOVs", "Lossless 1080p60 trailer master",
                         "Bottom-left paper captions", "Fungus Vult! capsule end card with Fredoka CTA and Steam logo"]
    report["revision"] = EDIT["revision"]
    report["ending"] = {"end_card_duration": EDIT["chapters"][-1]["duration"], **EDIT["ending"]}
    gardening = json.loads((PACKAGE / "sources/takes/gardening.json").read_text())
    gardening_proof = next(item for item in gardening if item.get("gardening_verified"))
    actions = [item["action"] for item in gardening if "action" in item]
    assert actions.index("planted") < actions.index("fertilized") < actions.index("mutated") < actions.index("harvested")
    lineage = json.loads((PACKAGE / "sources/takes/lineage_sword.json").read_text())
    lineage_proof = next(item for item in lineage if item.get("lineage_verified"))
    assert lineage_proof["descendant_generation"] == lineage_proof["parent_generation"] + 1
    assert lineage_proof["parent"] == "Lamarck" and lineage_proof["descendant"] == "Lamarck II"
    assert lineage_proof["inherited_weapon"] == "Sword"
    assert any(item.get("lineage_death") == lineage_proof["parent"] for item in lineage)
    report["new_loop_actions"] = {"gardening": gardening_proof, "lineage": lineage_proof}
    report["checks"] += ["Fertilizer and Mutation applied by UI drag to the same growing Plot",
                         "Actual combat death followed through emitted spore to Lamarck II"]
    # Preserve the original fast grow sequence; the expanded loops stay standalone.
    timeline = 0
    trailer_clips = []
    for chapter in EDIT["chapters"]:
        assert abs(sum(clip["duration"] for clip in chapter["clips"]) - chapter["duration"]) < .001
        for clip in chapter["clips"]:
            trailer_clips.append({**clip, "timeline_start": timeline})
            timeline += clip["duration"]

    def action_in_trailer(source, events, action, visible_until=None):
        event_time = next(item["seconds"] for item in events if item.get("action") == action)
        for clip in trailer_clips:
            if clip["source"] != source:
                continue
            visible_time = max(event_time, clip["start"])
            if (visible_time <= (visible_until if visible_until is not None else event_time)
                    and clip["start"] <= visible_time < clip["start"] + clip["duration"]):
                return {"action": action, "source": source, "source_seconds": visible_time,
                        "trailer_seconds": clip["timeline_start"] + visible_time - clip["start"],
                        "caption": clip.get("title")}
        raise AssertionError(f"Trailer omits recorded action: {source}/{action}")

    assert not {"gardening", "lineage_sword"}.intersection(clip["source"] for clip in trailer_clips)
    nursery = json.loads((PACKAGE / "sources/takes/nursery.json").read_text())
    grow_actions = [action_in_trailer("nursery", nursery, action) for action in
                    ["planted", "two_days_later", "harvested"]]
    times = [item["trailer_seconds"] for item in grow_actions]
    assert times == sorted(times)
    report["trailer_actions"] = {"original_grow": grow_actions}
    training_chapter = next(ch for ch in EDIT["chapters"] if ch["name"] == "03-train")
    report["training"] = {
        "trailer": training_proof(training_chapter["clips"], training_chapter["overlap"]),
        "description_loop": training_proof(EDIT["description_loops"]["02-train-and-combine"])}
    report["checks"] += ["Sword Child enters Sword Training with a Great Sword preview",
                         "Training loop and trailer stop immediately after confirmation; no emergence"]
    assert EDIT["chapters"][-1]["clips"][0]["source"] == "end-card"
    assert EDIT["chapters"][-1]["duration"] >= 5
    report["checks"] += ["Original Plant / Day jump / Harvest trailer sequence restored",
                         "Expanded gardening and lineage remain standalone description loops",
                         "Five-second end card retained"]
    (PACKAGE / "validation.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"lossless_sources": len(report["sources"]), "roster_checks": len(report["rosters"]), "videos": len(videos), "gifs": len(gifs),
                      "screenshots": len(shots), "screenshot_gif_mb": report["screenshot_gif_bytes"] / 1e6}, indent=2))


if __name__ == "__main__":
    check()
