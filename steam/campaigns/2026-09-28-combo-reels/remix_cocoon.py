#!/usr/bin/env python3
"""Add the generated cork pop to v7, preserving its encoded picture exactly."""
import argparse
import array
import json
import math
import pathlib
import subprocess

PACKAGE = pathlib.Path(__file__).resolve().parent
SOURCE = PACKAGE / "exports/auto-shrooms-spore-mortar-v7.mp4"
RATE = 48000


def run(command, **kwargs):
    return subprocess.run(list(map(str, command)), check=True, **kwargs)


def samples(path, filters=None, channels=1):
    command = ["ffmpeg", "-v", "error", "-i", str(path)]
    if filters:
        command += ["-af", filters]
    command += ["-f", "f32le", "-ac", str(channels), "-ar", str(RATE), "-"]
    return array.array("f", subprocess.check_output(command))


def video_packets(path):
    return json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-select_streams", "v:0", "-show_packets",
        "-show_entries", "packet=pts_time,dts_time,duration_time,data_hash",
        "-show_data_hash", "sha256", "-of", "json", str(path),
    ]))["packets"]


def prepare_original(generated, effect):
    # Isolate the first pop; the generated take contains a second, unwanted hit.
    preparation = (
        "atrim=start=0.025:end=0.25,asetpts=PTS-STARTPTS,"
        "highpass=f=65,lowpass=f=14000,"
        "afade=t=in:d=0.004,afade=t=out:st=0.185:d=0.04"
    )
    peak = max(abs(value) for value in samples(generated, preparation, channels=2))
    gain = 10 ** (-4.0 / 20.0) / peak
    run([
        "ffmpeg", "-v", "error", "-y", "-i", generated,
        "-af", f"{preparation},volume={gain:.9f}", "-ar", RATE,
        "-c:a", "pcm_s24le", effect,
    ])
    return {"source_trim_seconds": [0.025, 0.25], "effect_peak_dbfs": -4.0}


def prepare_heavy(generated, effect):
    work = PACKAGE / "work/cocoon-heavy-layered.wav"
    work.parent.mkdir(exist_ok=True)
    # Parallel pitched Foley adds body; audible harmonics keep the thump useful on phones.
    body = (
        "(1-exp(-t/0.0015))*exp(-t/0.075)*("
        "0.35*sin(2*PI*(135*t+3.2*(1-exp(-t/0.04))))+"
        "0.20*sin(4*PI*(135*t+3.2*(1-exp(-t/0.04))))+"
        "0.08*sin(6*PI*(135*t+3.2*(1-exp(-t/0.04)))))"
    )
    graph = (
        "[0:a]aresample=48000,atrim=end=0.42,asetpts=PTS-STARTPTS,"
        "volume=0.45,highpass=f=75,lowpass=f=12000,asplit=2[dry][low];"
        "[dry]acompressor=threshold=0.13:ratio=3:attack=3:release=65:makeup=2[attack];"
        "[low]asetrate=38400,aresample=48000,lowpass=f=1200,volume=0.65[body];"
        "[attack][body][1:a]amix=inputs=3:duration=longest:normalize=0,"
        "asoftclip=type=tanh:threshold=0.85:output=0.85,"
        "afade=t=in:d=0.001,afade=t=out:st=0.36:d=0.165[layered]"
    )
    run([
        "ffmpeg", "-v", "error", "-y", "-i", generated, "-f", "lavfi", "-i",
        f"aevalsrc='{body}':s={RATE}:d=0.36", "-filter_complex", graph,
        "-map", "[layered]", "-ar", RATE, "-c:a", "pcm_f32le", work,
    ])
    peak = max(abs(value) for value in samples(work, channels=2))
    gain = 10 ** (-2.2 / 20.0) / peak
    run([
        "ffmpeg", "-v", "error", "-y", "-i", work, "-af", f"volume={gain:.9f}",
        "-c:a", "pcm_s24le", effect,
    ])
    work.unlink()
    return {"source_trim_seconds": [0, 0.42], "effect_peak_dbfs": -2.2,
            "layers": ["compressed cork attack", "0.8x pitched cork body", "short harmonic thump"]}


def main(version):
    output = PACKAGE / f"exports/auto-shrooms-spore-mortar-v{version}.mp4"
    stem = "cocoon-heavy-pop" if version == 9 else "cocoon-cork-pop"
    generated = PACKAGE / f"sources/{stem}-generated.mp3"
    effect = PACKAGE / f"exports/{stem}.wav"
    preparation = prepare_heavy(generated, effect) if version == 9 else prepare_original(generated, effect)
    effect_samples = samples(effect)
    window = round(RATE * 0.003)
    energies = [sum(value * value for value in effect_samples[start:start + window])
                for start in range(0, len(effect_samples), window)]
    transient_sample = max(range(len(energies)), key=energies.__getitem__) * window
    packets = video_packets(SOURCE)
    video_start = min(float(packet["pts_time"]) for packet in packets)
    reveal_time = video_start + 150 / 60
    delay_samples = round(reveal_time * RATE) - transient_sample
    # Briefly soften the original chime and music to give the pop its own space.
    attack_length = 0.18 if version == 9 else 0.06
    bed_gain = 0.07 if version == 9 else 0.22
    attack, hold, recover = reveal_time - attack_length, reveal_time + 0.24, reveal_time + 0.5
    duck = (
        f"if(lt(t,{attack}),1,if(lt(t,{reveal_time}),"
        f"1-{1-bed_gain}*(t-{attack})/{attack_length},if(lt(t,{hold}),{bed_gain},"
        f"if(lt(t,{recover}),{bed_gain}+{1-bed_gain}*(t-{hold})/0.26,1))))"
    )
    graph = (
        f"[0:a]aresample={RATE},volume='{duck}':eval=frame[bed];"
        f"[1:a]adelay={delay_samples}S:all=1[pop];"
        "[bed][pop]amix=inputs=2:duration=first:normalize=0[a]"
    )
    run([
        "ffmpeg", "-v", "error", "-y", "-copyts", "-i", SOURCE, "-i", effect,
        "-filter_complex", graph, "-map", "0:v:0", "-map", "[a]",
        "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-ar", RATE,
        "-ac", "2", "-movflags", "+faststart", output,
    ])
    assert video_packets(output) == packets, "Video packets or timing changed"
    run(["ffmpeg", "-v", "error", "-i", output, "-f", "null", "-"])
    probe = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", str(output)
    ]))
    video = next(stream for stream in probe["streams"] if stream["codec_type"] == "video")
    assert (video["width"], video["height"], video["nb_frames"]) == (1080, 1920, "960")
    assert video["r_frame_rate"] == "60/1"
    loudness = run([
        "ffmpeg", "-hide_banner", "-i", output, "-af",
        "loudnorm=I=-16:TP=-1.5:LRA=9:print_format=json", "-f", "null", "-",
    ], capture_output=True, text=True).stderr
    metrics, _ = json.JSONDecoder().raw_decode(loudness[loudness.rfind("{"):])
    assert float(metrics["input_tp"]) < -1.0, "Insufficient peak headroom"
    before, after = samples(SOURCE), samples(output)
    correlations = {}
    for label, start, end in [("before_reveal", 0.2, 2.3), ("landing_and_battles", 3.1, 15.9)]:
        a, b = before[round(start * RATE):round(end * RATE)], after[round(start * RATE):round(end * RATE)]
        assert len(a) == len(b)
        correlation = sum(x * y for x, y in zip(a, b)) / math.sqrt(
            sum(x * x for x in a) * sum(y * y for y in b)
        )
        assert correlation > 0.99, f"Unexpected audio change in {label}"
        correlations[label] = correlation
    report = {
        "file": output.name, "source_picture": SOURCE.name,
        "width": 1080, "height": 1920, "fps": 60, "frames": 960,
        "duration": float(probe["format"]["duration"]), "bytes": output.stat().st_size,
        "full_decode": "passed", "video_packets_and_timestamps_identical": True,
        "audio": {"codec": "aac", "sample_rate": RATE,
                  "integrated_lufs": metrics["input_i"], "true_peak_dbtp": metrics["input_tp"],
                  "unchanged_region_correlations": correlations},
        "cocoon_sound": {"effect": effect.name, "generated_source": generated.name,
                         **preparation,
                         "transient_local_seconds": transient_sample / RATE,
                         "timeline_start_seconds": delay_samples / RATE,
                         "transient_timeline_seconds": reveal_time,
                         "original_chime_gain_at_pop": bed_gain,
                         "original_mix_restored_seconds": recover,
                         "explosion_sound": False},
        "visual_validation": "validation-v7.json (identical picture)",
    }
    if version == 9:
        comparison = {}
        previous = PACKAGE / "exports/auto-shrooms-spore-mortar-v8.mp4"
        for name, filters in [("full_band", None), ("low_mid_120_600_hz", "highpass=f=120,lowpass=f=600")]:
            energies = []
            for path in [previous, output]:
                signal = samples(path, filters)
                hit = signal[round(reveal_time * RATE):round((reveal_time + 0.15) * RATE)]
                energies.append(sum(value * value for value in hit) / len(hit))
            comparison[name + "_gain_db"] = 10 * math.log10(energies[1] / energies[0])
        assert comparison["full_band_gain_db"] > 3.0, "New hit needs substantially more body"
        report["impact_vs_v8_first_150ms"] = comparison
    (PACKAGE / f"validation-v{version}.json").write_text(json.dumps(report, indent=2) + "\n")
    run([
        "ffmpeg", "-v", "error", "-y", "-i", output, "-vn", "-ss", "1.9",
        "-t", "1.6", "-c:a", "pcm_s24le", PACKAGE / f"preview/cocoon-reveal-v{version}.wav",
    ])
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", type=int, choices=[8, 9], default=9)
    main(parser.parse_args().version)
