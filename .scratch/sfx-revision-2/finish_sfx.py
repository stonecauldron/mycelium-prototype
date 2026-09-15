"""Layer generated Foley into short bow releases and weightier blunt impacts.

Run after process_sfx.py --prepare. No generation or network access is used.
"""

import argparse
import hashlib
import importlib.util
from itertools import zip_longest
import json
import math
from pathlib import Path
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location("prepare_sfx", HERE.parent / "elevenlabs-sfx/process_sfx.py")
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)
RATE = audio.RATE


def layer(row):
    samples = audio.decode(HERE / row["source"])
    samples = samples[round(row.get("start_seconds", 0) * RATE):]
    # Normalize each source before balancing layers; several string takes are quiet.
    peak = max(abs(x) for x in samples)
    samples = [x / peak for x in samples]
    pitch = row.get("pitch", 1.0)
    count = min(round(row["duration_seconds"] * RATE), int((len(samples) - 1) / pitch))
    output = []
    previous = 0.0
    smoothing = 1 - math.exp(-math.tau * row.get("lowpass_hz", 16000) / RATE)
    for i in range(count):
        position = i * pitch
        left = int(position)
        value = samples[left] + (samples[left + 1] - samples[left]) * (position - left)
        previous += smoothing * (value - previous)
        envelope = math.exp(-i / (RATE * row.get("decay_seconds", 10)))
        output.append(previous * envelope * row["gain"])
    # Fade every layer's end so truncating a resonance cannot create a click.
    fade = min(round(.015 * RATE), len(output))
    for i in range(fade):
        output[-1 - i] *= i / fade
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    plan = json.loads((HERE / "plan.json").read_text())
    manifest = json.loads((HERE / "manifest.json").read_text())
    for cue in plan["cues"]:
        if "layers" not in cue:
            continue
        layers = [layer(row) for row in cue["layers"]]
        mixed = [sum(values) for values in zip_longest(*layers, fillvalue=0.0)]
        samples, report = audio.prepare(mixed, cue["max_duration_seconds"], cue["target_rms_dbfs"])
        output = HERE / "prepared" / (cue["cue"] + "_finished.wav")
        audio.write_wav(output, samples)
        selected = next(r for r in manifest["selected"] if r["cue"] == cue["cue"])
        selected.update(report, prepared_file=str(output.relative_to(HERE)),
                        sha256=hashlib.sha256(output.read_bytes()).hexdigest(),
                        layers=[{**r, "source_sha256": hashlib.sha256((HERE / r["source"]).read_bytes()).hexdigest()} for r in cue["layers"]],
                        selection_reason=cue["selection_note"])
        if args.install:
            shutil.copyfile(output, ROOT / "assets/audio/sfx" / (cue["cue"] + ".wav"))
        print(f"Finished {cue['cue']}: {report['duration_seconds']} s")
    preview = []
    for row in manifest["selected"]:
        row["preview_start_seconds"] = round(len(preview) / RATE, 3)
        preview.extend(x * .6 for x in audio.decode(HERE / row["prepared_file"]))
        preview.extend([0.0] * round(RATE * .45))
    audio.write_wav(HERE / "preview.wav", preview)
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")


if __name__ == "__main__":
    main()
