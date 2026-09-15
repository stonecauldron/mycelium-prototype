"""Reproduce revision 3 from saved sources, without generation or network access."""

import argparse
from array import array
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import wave

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
spec = importlib.util.spec_from_file_location("prepare_sfx", HERE.parent / "elevenlabs-sfx/process_sfx.py")
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metrics(path):
    samples = audio.decode(path)
    peak = max(abs(x) for x in samples)
    with wave.open(str(path)) as stream:
        return {"duration_seconds": stream.getnframes() / stream.getframerate(),
                "sample_rate": stream.getframerate(), "channels": stream.getnchannels(),
                "bits_per_sample": stream.getsampwidth() * 8,
                "peak_dbfs": round(audio.db(peak), 2),
                "rms_dbfs": round(audio.db(audio.rms(samples)), 2),
                "crest_db": round(audio.db(peak / audio.rms(samples)), 2)}


def mix(cue):
    command = ["ffmpeg", "-v", "error"]
    filters = []
    for i, row in enumerate(cue["layers"]):
        command += ["-i", str(HERE / row["source"])]
        filters.append(f"[{i}:a]aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=mono,"
                       f"{row['filters']},volume={row['gain']}[layer{i}]")
    inputs = "".join(f"[layer{i}]" for i in range(len(cue["layers"])))
    filters.append(f"{inputs}amix=inputs={len(cue['layers'])}:normalize=0:duration=longest,"
                   f"highpass=f=35,{cue['finish']}[mixed]")
    # Keep floats until final level adjustment so overlapping layers cannot clip.
    raw = subprocess.check_output(command + ["-filter_complex", ";".join(filters),
        "-map", "[mixed]", "-ar", "44100", "-ac", "1", "-f", "f32le", "-"])
    samples = array("f", raw)
    if sys.byteorder != "little":
        samples.byteswap()
    if cue.get("preserve_padding"):
        gain = min(.7 / max(abs(x) for x in samples),
                   10 ** (cue["target_rms_dbfs"] / 20) / audio.rms(samples))
        return [x * gain for x in samples]
    prepared, _report = audio.prepare(samples, cue["max_duration_seconds"], cue["target_rms_dbfs"])
    if "saturation_drive" in cue:
        prepared = [math.tanh(x * cue["saturation_drive"]) for x in prepared]
        gain = .7 / max(abs(x) for x in prepared)
        prepared = [x * gain for x in prepared]
    return prepared


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install", action="store_true")
    args = parser.parse_args()
    plan = json.loads((HERE / "plan.json").read_text())
    prepared = HERE / "prepared"
    prepared.mkdir(exist_ok=True)
    selected = []
    preview = []
    for cue in plan["cues"]:
        output = prepared / (cue["cue"] + ".wav")
        sources = cue.get("layers", [{"source": cue.get("source")}])
        if cue["operation"] == "mix":
            audio.write_wav(output, mix(cue))
        else:
            shutil.copyfile(HERE / cue["source"], output)
        row = {"cue": cue["cue"], "operation": cue["operation"], "note": cue["note"],
               "sha256": digest(output), "prepared_file": str(output.relative_to(HERE)),
               "sources": [{**source, "sha256": digest(HERE / source["source"])} for source in sources],
               "before": metrics(HERE / "previous" / output.name), "after": metrics(output),
               "preview_start_seconds": round(len(preview) / audio.RATE, 3)}
        selected.append(row)
        preview.extend(x * .6 for x in audio.decode(output))
        preview.extend([0.0] * round(audio.RATE * .45))
        if args.install:
            destination = ROOT / "assets/audio/sfx" / output.name
            shutil.copyfile(output, destination)
            if cue["operation"] == "restore":
                import_path = "assets/audio/sfx/" + output.name + ".import"
                original = subprocess.check_output(["git", "show", plan["restore_commit"] + ":" + import_path], cwd=ROOT)
                (ROOT / import_path).write_bytes(original)
        print(cue["cue"], row["after"])
    manifest = {"generation_cost_usd": 0, "bow_source": plan["bow_source"], "selected": selected}
    (HERE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    audio.write_wav(HERE / "preview.wav", preview)


if __name__ == "__main__":
    main()
