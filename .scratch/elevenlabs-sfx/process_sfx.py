"""Download, prepare and audit the ElevenLabs pack. Does not generate audio.

Raw takes and request metadata are retained locally. Selection scores favor a
compact event with its tail intact; they do not judge artistic sound quality.
"""

import argparse
from array import array
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.request
import wave

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RATE = 44100


def load_json(name):
    return json.loads((HERE / name).read_text())


def download(row):
    name = f"{row['cue']}_{row['take']}.mp3"
    path = HERE / "raw" / name
    if path.exists() and path.stat().st_size > 0:
        return name
    request = urllib.request.Request(row["audio_url"], headers={"User-Agent": "Mycelium-SFX-authoring"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
    if len(data) < 100:
        raise ValueError(f"Empty audio response: {name}")
    temporary = path.with_suffix(".part")
    temporary.write_bytes(data)
    temporary.replace(path)
    return name


def decode(path):
    raw = subprocess.check_output([
        "ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(RATE),
        "-f", "s16le", "-acodec", "pcm_s16le", "-",
    ])
    samples = array("h", raw)
    if sys.byteorder != "little":
        samples.byteswap()
    return [x / 32768 for x in samples]


def rms(samples):
    return math.sqrt(sum(x * x for x in samples) / max(1, len(samples)))


def db(value):
    return 20 * math.log10(max(value, 1e-12))


def write_wav(path, samples):
    pcm = array("h", [round(max(-1, min(1, x)) * 32767) for x in samples])
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


def prepare(samples, max_duration, target_rms_db):
    # Remove DC/very low handling rumble with a gentle 35 Hz high-pass.
    coefficient = math.exp(-math.tau * 35 / RATE)
    previous_input = previous_output = 0.0
    filtered = []
    for value in samples:
        output = coefficient * (previous_output + value - previous_input)
        filtered.append(output)
        previous_input, previous_output = value, output
    block = round(RATE * 0.005)
    envelope = [rms(filtered[i:i + block]) for i in range(0, len(filtered), block)]
    top = max(envelope, default=0)
    if top < 0.001:
        raise ValueError("Generated take is effectively silent")
    active = [i for i, value in enumerate(envelope) if value >= max(0.0005, top * 0.035)]
    start = max(0, active[0] * block - round(RATE * 0.004))
    end = min(len(filtered), (active[-1] + 1) * block + round(RATE * 0.015))
    full = filtered[start:end]
    cut = min(len(full), round(max_duration * RATE))
    chosen = full[:cut]
    retained = sum(x * x for x in chosen) / max(1e-12, sum(x * x for x in full))
    # The lowest tail energy at the cut makes a compact, natural ending preferable.
    tail_ratio = rms(chosen[-block:]) / max(1e-12, rms(chosen))
    score = retained * 5 - min(tail_ratio, 3) * 0.4
    fade_in = min(round(RATE * 0.001), len(chosen))
    fade_out = min(round(RATE * 0.015), max(1, len(chosen) // 5))
    for i in range(fade_in):
        chosen[i] *= i / max(1, fade_in)
    for i in range(fade_out):
        chosen[-1 - i] *= i / fade_out
    gain = min(0.7 / max(abs(x) for x in chosen), 10 ** (target_rms_db / 20) / rms(chosen))
    chosen = [x * gain for x in chosen]
    if len(chosen) < round(RATE * 0.05):
        chosen += [0.0] * (round(RATE * 0.05) - len(chosen))
    return chosen, {
        "source_duration_seconds": round(len(samples) / RATE, 4),
        "trim_start_seconds": round(start / RATE, 4),
        "duration_seconds": round(len(chosen) / RATE, 4),
        "retained_energy_fraction": round(retained, 4),
        "selection_score": round(score, 4),
        "peak_dbfs": round(db(max(abs(x) for x in chosen)), 2),
        "rms_dbfs": round(db(rms(chosen)), 2),
    }


def main():
    global HERE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=HERE, help="Directory containing this batch's plan and requests")
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--prepare", action="store_true")
    parser.add_argument("--install", action="store_true", help="Replace this batch's game assets only when all planned takes are ready")
    args = parser.parse_args()
    HERE = args.source_dir.resolve()
    rows = [r for r in load_json("requests.json") if r.get("audio_url")]
    plan = load_json("plan.json")
    cues = {p["cue"]: p for p in plan["cues"]}
    (HERE / "raw").mkdir(exist_ok=True)
    if args.download:
        with ThreadPoolExecutor(max_workers=6) as workers:
            downloaded = list(workers.map(download, rows))
        print(f"Downloaded/cached {len(downloaded)} source takes")
    if not (args.prepare or args.install):
        return
    prepared = HERE / "prepared"
    prepared.mkdir(exist_ok=True)
    candidates = {cue: [] for cue in cues}
    for row in rows:
        name = f"{row['cue']}_{row['take']}"
        raw = HERE / "raw" / (name + ".mp3")
        cue = cues[row["cue"]]
        samples, report = prepare(decode(raw), cue["max_duration_seconds"], cue["target_rms_dbfs"])
        output = prepared / (name + ".wav")
        write_wav(output, samples)
        report.update(cue=row["cue"], take=row["take"], request_id=row["request_id"],
                      source_file=str(raw.relative_to(HERE)), source_url=row["audio_url"],
                      source_sha256=hashlib.sha256(raw.read_bytes()).hexdigest(),
                      prepared_file=str(output.relative_to(HERE)),
                      sha256=hashlib.sha256(output.read_bytes()).hexdigest())
        candidates[row["cue"]].append(report)
    selected = []
    for cue in cues:
        takes = candidates[cue]
        if takes:
            preferred = cues[cue].get("preferred_take")
            winner = next(r for r in takes if r["take"] == preferred) if preferred else max(takes, key=lambda r: r["selection_score"])
            winner["selection_reason"] = cues[cue].get("selection_note", "Best retained energy and quiet tail")
            selected.append(winner)
    manifest = {"model": plan["model"], "selection_method": "Explicit preferred takes where authored; otherwise best retained energy and cleanest tail. Subjective review uses the preview.",
                "estimated_generation_usd": round(sum(r["input"]["duration_seconds"] for r in rows) * plan["unit_price_usd"], 6),
                "takes": [r for take_list in candidates.values() for r in take_list], "selected": selected}
    preview = []
    for row in selected:
        row["preview_start_seconds"] = round(len(preview) / RATE, 3)
        preview.extend(x * 0.6 for x in decode(HERE / row["prepared_file"]))
        preview.extend([0.0] * round(RATE * 0.45))
    write_wav(HERE / "preview.wav", preview)
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Prepared {len(rows)} takes; selected {len(selected)}/{len(cues)} cues")
    if args.install:
        if len(selected) != len(cues) or any(len(takes) < plan["takes_per_cue"] for takes in candidates.values()):
            raise ValueError("Complete all three takes for every cue before installing")
        for row in selected:
            shutil.copyfile(HERE / row["prepared_file"], ROOT / "assets/audio/sfx" / (row["cue"] + ".wav"))
        print(f"Installed {len(selected)} ElevenLabs effects from {HERE.name}")


if __name__ == "__main__":
    main()
