"""Build the original Mycelium SFX pack with Python's standard library.

No recordings or third-party samples. Run from any directory. All synthesis
randomness is local and seeded; rerunning reproduces the WAV files exactly.
"""

from array import array
import json
import math
from pathlib import Path
import random
import sys
import wave

RATE = 44100
ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "assets/audio/sfx"
TAU = math.tau
RNG = random.Random(73129)


def blank(seconds):
    return [0.0] * round(seconds * RATE)


def layer(dest, source, start=0.0, gain=1.0):
    offset = round(start * RATE)
    for i, value in enumerate(source[: max(0, len(dest) - offset)]):
        dest[offset + i] += value * gain
    return dest


def tone(seconds, frequency, decay=18, end=None, harmonics=(1, 0.23, 0.08)):
    """Soft resonant body; a glide gives mushroom pops their elastic attack."""
    end = frequency if end is None else end
    result = blank(seconds)
    phase = 0.0
    for i in range(len(result)):
        t = i / RATE
        hz = end + (frequency - end) * math.exp(-t * 35)
        phase += TAU * hz / RATE
        attack = min(1.0, t / 0.0025)
        result[i] = attack * math.exp(-t * decay) * sum(
            amplitude * math.sin(phase * (h + 1))
            for h, amplitude in enumerate(harmonics)
        )
    return result


def noise(seconds, low=500, high=5000, decay=15, swell=False):
    """Band-limited paper/soil/air texture, without harsh white-noise fizz."""
    result = blank(seconds)
    lower = upper = 0.0
    a_low = 1 - math.exp(-TAU * low / RATE)
    a_high = 1 - math.exp(-TAU * high / RATE)
    for i in range(len(result)):
        t = i / RATE
        value = RNG.uniform(-1, 1)
        lower += a_low * (value - lower)
        upper += a_high * (value - upper)
        envelope = math.sin(math.pi * t / seconds) ** 1.5 if swell else math.exp(-t * decay)
        result[i] = (upper - lower) * envelope * min(1.0, t / 0.001)
    return result


def wood(pitch=440, seconds=0.16):
    result = tone(seconds, pitch, 35, harmonics=(1, 0.10))
    layer(result, tone(seconds, pitch * 2.73, 65, harmonics=(1,)), gain=0.32)
    return layer(result, noise(seconds, 1000, 6000, 80), gain=0.65)


def pop(pitch=360, seconds=0.24):
    result = tone(seconds, pitch * 2.4, 20, pitch, (1, 0.13))
    return layer(result, noise(seconds, 150, 2300, 38), gain=0.5)


def rustle(seconds=0.24):
    return noise(seconds, 900, 6500, swell=True)


def chime(notes, spacing=0.11, seconds=0.7):
    result = blank(seconds)
    for i, note in enumerate(notes):
        hz = 440 * 2 ** ((note - 69) / 12)
        layer(result, tone(seconds - i * spacing, hz, 10, harmonics=(1, 0.06)), i * spacing, 0.42)
        layer(result, wood(hz * 0.5, 0.12), i * spacing, 0.18)
    return result


def impact(blunt=False):
    result = blank(0.24)
    layer(result, pop(110 if blunt else 230, 0.24), gain=0.75)
    layer(result, wood(190 if blunt else 640, 0.16), gain=0.55)
    return layer(result, noise(0.22, 250 if blunt else 1500, 3200 if blunt else 8000, 27), gain=0.8)


def build():
    clips = {}
    clips["ui_hover"] = wood(1150, 0.06)
    clips["ui_click"] = wood(620, 0.10)
    clips["ui_toggle"] = layer(wood(410, 0.15), wood(770, 0.08), 0.04, 0.6)
    clips["ui_tick"] = wood(880, 0.055)
    clips["ui_open"] = layer(rustle(0.20), pop(490, 0.13), 0.06, 0.35)
    clips["ui_close"] = layer(rustle(0.16), wood(330, 0.10), 0.05, 0.6)
    clips["ui_error"] = layer(wood(220, 0.24), wood(170, 0.12), 0.10, 0.8)
    clips["select"] = pop(660, 0.13)
    clips["move"] = layer(rustle(0.17), wood(360, 0.12), 0.05, 0.75)
    clips["purchase"] = chime([76, 83], 0.065, 0.38)
    clips["sell"] = chime([79, 72], 0.07, 0.35)
    clips["reroll"] = blank(0.40)
    for i, hz in enumerate([520, 710, 460, 830, 630]):
        layer(clips["reroll"], wood(hz, 0.10), i * 0.055, 0.65)
    clips["lock"] = layer(wood(390, 0.17), wood(250, 0.09), 0.045, 0.6)
    clips["unlock"] = layer(wood(280, 0.28), pop(560, 0.17), 0.08, 0.75)
    clips["plant"] = layer(noise(0.32, 80, 2700, 14), pop(220, 0.22), 0.055, 0.8)
    clips["fertilize"] = blank(0.48)
    for i in range(7):
        layer(clips["fertilize"], pop(650 + i * 43, 0.12), i * 0.047, 0.4)
    layer(clips["fertilize"], noise(0.48, 600, 4500, swell=True), gain=0.35)
    clips["mutate"] = blank(0.60)
    for i, hz in enumerate([230, 310, 480, 670]):
        layer(clips["mutate"], pop(hz, 0.20), i * 0.10, 0.6)
    layer(clips["mutate"], rustle(0.60), gain=0.3)
    clips["harvest"] = layer(chime([72, 76, 79, 84], 0.075, 0.65), pop(290, 0.23), gain=0.65)
    clips["train"] = layer(rustle(0.55), pop(210, 0.25), 0.14, 0.7)
    layer(clips["train"], wood(330, 0.18), 0.34, 0.6)
    clips["compost"] = layer(noise(0.4, 80, 1800, 10), pop(95, 0.3), 0.04, 0.8)
    clips["seal"] = layer(chime([64, 71, 76], 0.10, 0.65), wood(160, 0.2), gain=0.8)
    clips["slash"] = noise(0.18, 700, 7500, swell=True)
    clips["heavy_swing"] = layer(noise(0.27, 120, 3000, swell=True), tone(0.27, 160, 10, 65), gain=0.16)
    clips["bow"] = layer(tone(0.25, 490, 21, 200, (1, 0.5, 0.2)), noise(0.20, 1600, 8000, 25), gain=0.7)
    clips["throw"] = layer(noise(0.23, 500, 6000, swell=True), wood(750, 0.08), gain=0.24)
    clips["horn"] = tone(0.40, 290, 6, 195, (1, 0.5, 0.3, 0.12))
    layer(clips["horn"], noise(0.40, 200, 2400, 9), gain=0.2)
    clips["charge"] = blank(0.38)
    layer(clips["charge"], noise(0.38, 180, 3800, swell=True), gain=0.8)
    for i in range(3):
        layer(clips["charge"], wood(135 + i * 30, 0.10), i * 0.10, 0.5)
    clips["hit_slash"] = impact()
    clips["hit_blunt"] = impact(True)
    clips["block"] = layer(wood(430, 0.24), wood(1300, 0.22), gain=0.65)
    clips["death"] = layer(pop(140, 0.36), noise(0.36, 250, 3100, 12), 0.025, 0.7)
    clips["ground"] = layer(wood(250, 0.20), noise(0.20, 450, 3900, 29), gain=0.55)
    clips["explosion"] = layer(tone(0.65, 125, 9, 38, (1, 0.16)), noise(0.65, 80, 6000, 8), gain=2.0)
    for i in range(5):
        layer(clips["explosion"], pop(260 + i * 150, 0.12), 0.055 + i * 0.055, 0.18)
    clips["spore"] = layer(noise(0.42, 1000, 6500, 10), pop(790, 0.20), gain=0.27)
    clips["revive"] = layer(chime([55, 62, 67, 74], 0.10, 0.75), pop(260, 0.28), gain=0.65)
    clips["acid_rain"] = blank(0.8)
    for i in range(22):
        layer(clips["acid_rain"], noise(0.09, 700, 9000, 48), RNG.uniform(0, 0.64), 0.8)
        layer(clips["acid_rain"], pop(RNG.uniform(450, 1700), 0.06), RNG.uniform(0, 0.66), 0.16)
    clips["battle_start"] = layer(chime([48, 55, 60], 0.10, 0.7), wood(120, 0.3), gain=0.9)
    clips["battle_win"] = chime([67, 72, 76, 79], 0.105, 0.9)
    clips["run_win"] = chime([60, 64, 67, 72, 76, 79, 84], 0.12, 1.5)
    clips["run_loss"] = chime([64, 60, 55, 48], 0.17, 1.2)
    return clips


def master(samples):
    # Remove DC, reserve 3 dB headroom, and taper both ends to avoid clicks.
    average = sum(samples) / len(samples)
    samples = [x - average for x in samples]
    for i in range(min(round(0.002 * RATE), len(samples))):
        samples[i] *= i / (0.002 * RATE)
    tail = min(round(0.025 * RATE), len(samples))
    for i in range(tail):
        samples[-1 - i] *= i / tail
    peak = max(abs(x) for x in samples)
    gain = 0.70 / peak
    return [round(x * gain * 32767) for x in samples]


def write_wav(path, samples):
    pcm = array("h", samples)
    if sys.byteorder != "little":
        pcm.byteswap()
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    report = []
    preview = []
    for name, samples in build().items():
        pcm = master(samples)
        write_wav(OUTPUT / f"{name}.wav", pcm)
        report.append({
            "cue": name,
            "duration_seconds": round(len(pcm) / RATE, 3),
            "peak_dbfs": round(20 * math.log10(max(abs(x) for x in pcm) / 32768), 2),
            "rms_dbfs": round(20 * math.log10(math.sqrt(sum(x * x for x in pcm) / len(pcm)) / 32768), 2),
            "preview_start_seconds": round(len(preview) / RATE, 3),
        })
        preview += [round(x * 0.6) for x in pcm] + [0] * round(RATE * 0.45)
    write_wav(Path(__file__).with_name("preview.wav"), preview)
    Path(__file__).with_name("audio_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"Created {len(report)} original mono PCM WAV effects and preview.wav")
