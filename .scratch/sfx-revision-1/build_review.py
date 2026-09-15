"""Build the standalone SFX review from lossless Godot captures; no generation."""

import argparse
from array import array
import base64
import json
from pathlib import Path
import subprocess
import sys
import wave

HERE = Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-dir", type=Path, required=True)
    parser.add_argument("--previous", type=Path, required=True, help="Previous review-data.json for comparison")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--revision-dir", type=Path, default=HERE, help="Batch plan whose changes should be compared")
    args = parser.parse_args()
    captures = {r["id"]: r for r in json.loads((args.capture_dir / "capture.json").read_text())}
    previous = {r["id"]: r for r in json.loads(args.previous.read_text())}
    contexts = json.loads((HERE / "review-contexts.json").read_text())
    plan = json.loads((args.revision_dir / "plan.json").read_text())
    revised = {r["cue"] for r in plan["cues"]} | set(plan.get("level_changes", {}))
    regular = {"great_slash": "slash", "great_swing": "heavy_swing", "great_bow": "bow",
               "great_throw": "throw", "great_hit_slash": "hit_slash",
               "great_hit_blunt": "hit_blunt", "great_block": "block"}
    rows = []
    for cue_id, title, group, context in contexts:
        row = captures[cue_id]
        with wave.open(str(args.capture_dir / (cue_id + ".wav"))) as source:
            assert source.getsampwidth() == 2
            pcm = array("h", source.readframes(source.getnframes()))
            channels, rate = source.getnchannels(), source.getframerate()
        if sys.byteorder != "little":
            pcm.byteswap()
        mono = array("h", (round(sum(pcm[i:i + channels]) / channels) for i in range(0, len(pcm), channels)))
        active = [i for i, value in enumerate(mono) if abs(value) > 2]
        assert active, cue_id
        start = max(0, active[0] - round(rate * .004))
        end = min(len(mono), active[-1] + round(rate * .008))
        clipped = mono[start:end]
        if sys.byteorder != "little":
            clipped.byteswap()
        lossless = subprocess.check_output([
            "ffmpeg", "-v", "error", "-f", "s16le", "-ar", str(rate), "-ac", "1", "-i", "-",
            "-c:a", "flac", "-compression_level", "8", "-metadata_header_padding", "0", "-f", "flac", "-",
        ], input=clipped.tobytes())
        rows.append({**{k: v for k, v in row.items() if k != "capture_gain_db"},
                     "title": title, "group": group, "context": context,
                     "audio": base64.b64encode(lossless).decode()})
    assert len(rows) == len(captures) == 47
    current = {r["id"]: dict(r) for r in rows}
    for row in rows:
        if row["id"] in regular and row["id"] not in previous:
            row["previous"] = current[regular[row["id"]]]
            row["previousLabel"] = "Regular"
        elif row["id"] in revised:
            row["previous"] = {k: v for k, v in previous[row["id"]].items() if k not in ("previous", "previousLabel")}
            row["previousLabel"] = "Previous"
    payload = json.dumps(rows, separators=(",", ":")).replace("<", "\\u003c")
    marker = '<script id="sfx-data" type="application/json">[]</script>'
    template = (HERE / "review.html").read_text()
    new_count = sum(row.get("previousLabel") == "Regular" for row in rows)
    summary = f"{len(rows)} active sounds · {len(revised) - new_count} revised"
    if new_count:
        summary += f" · {new_count} new Great cues"
    template = template.replace("{{SOUND_SUMMARY}}", summary)
    assert template.count(marker) == 1
    output = template.replace(marker, '<script id="sfx-data" type="application/json">' + payload + '</script>')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(output)
    (args.capture_dir / "review-data.json").write_text(payload)
    print(f"Built {len(rows)} cues with {len(revised)} comparisons: {args.output}")


if __name__ == "__main__":
    main()
