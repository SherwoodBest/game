"""Generate a quiet ambient score that follows the video's eras.

A slow pad loops through four chords. During the two AI winters it turns
darker and the plucked notes stop; later eras get busier arpeggios.

Usage: python music.py   (reads build/timeline.json, writes build/music.wav)
"""

import json
import wave
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
BUILD = HERE / "build"
SR = 44100
CHORD_LEN = 8.0

# A minor, slow and open: Am9, Fmaj7, C(add9), G6 (MIDI note numbers)
CHORDS = [
    [45, 52, 59, 60, 64, 71],
    [41, 48, 57, 60, 64, 67],
    [48, 55, 62, 64, 67, 74],
    [43, 50, 59, 62, 64, 71],
]
PENTATONIC = [69, 72, 74, 76, 79, 81, 84, 86, 88]

# How bright/busy each scene is, 0..1
MOOD = {
    "intro": 0.45, "turing": 0.5, "dartmouth": 0.55, "perceptron": 0.55, "symbolic": 0.5,
    "winter1": 0.0, "expert": 0.6, "winter2": 0.0, "nineties": 0.55, "data": 0.65,
    "alexnet": 0.8, "deepspread": 0.8, "alphago": 0.85, "transformer": 0.9, "scaling": 0.9,
    "alphafold": 0.9, "chatgpt": 1.0, "race": 1.0, "agents": 1.0, "today": 0.7, "outro": 0.4,
}


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def mood_curve(timeline, n):
    t = np.arange(n) / SR
    m = np.zeros(n)
    for sc in timeline["scenes"]:
        m[(t >= sc["start"]) & (t < sc["end"])] = MOOD.get(sc["id"], 0.6)
    # smooth over ~3 s so changes swell rather than jump
    k = int(3 * SR) // 64
    coarse = m[::64]
    coarse = np.convolve(np.pad(coarse, k, mode="edge"), np.ones(2 * k + 1) / (2 * k + 1), mode="valid")
    return np.interp(np.arange(n), np.arange(len(coarse)) * 64, coarse)


def pad_voice(freq, n, brightness, rng):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for detune in (-0.12, 0.0, 0.13):
        f = freq * 2 ** (detune / 12)
        ph = rng.uniform(0, 2 * np.pi)
        out += np.sin(2 * np.pi * f * t + ph)
        out += brightness * 0.28 * np.sin(2 * np.pi * 2 * f * t + ph)
        out += brightness * 0.10 * np.sin(2 * np.pi * 3 * f * t + ph)
    # slow tremolo keeps it alive
    out *= 0.85 + 0.15 * np.sin(2 * np.pi * rng.uniform(0.05, 0.12) * t + rng.uniform(0, 6))
    return out / 3


def envelope(n, attack, release):
    env = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    env[:a] = np.linspace(0, 1, a) ** 2
    env[-r:] *= np.linspace(1, 0, r) ** 2
    return env


def reverb(x, seconds=3.2, seed=0):
    rng = np.random.default_rng(seed)
    n_ir = int(seconds * SR)
    ir = rng.standard_normal(n_ir) * np.exp(-np.arange(n_ir) / (SR * seconds / 6))
    ir[: int(0.02 * SR)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    block = 1 << 18
    nfft = 1 << int(np.ceil(np.log2(block + n_ir)))
    H = np.fft.rfft(ir, nfft)
    out = np.zeros(len(x) + n_ir)
    for i in range(0, len(x), block):
        seg = x[i:i + block]
        y = np.fft.irfft(np.fft.rfft(seg, nfft) * H, nfft)[: len(seg) + n_ir]
        out[i:i + len(y)] += y
    return out[: len(x)]


def main():
    timeline = json.loads((BUILD / "timeline.json").read_text())
    total = timeline["duration"]
    n = int(total * SR)
    mood = mood_curve(timeline, n)
    rng = np.random.default_rng(7)
    left = np.zeros(n)
    right = np.zeros(n)

    # Pad
    k = 0
    t0 = 0.0
    while t0 < total:
        chord = CHORDS[k % len(CHORDS)]
        start = int(t0 * SR)
        length = int((CHORD_LEN + 3.0) * SR)
        end = min(n, start + length)
        seg = end - start
        bright = float(mood[min(start + seg // 2, n - 1)])
        env = envelope(length, 2.5, 3.5)[:seg]
        for j, note in enumerate(chord):
            v = pad_voice(hz(note), seg, 0.3 + 0.7 * bright, rng) * env
            gain = 0.11 if note < 50 else 0.07
            pan = 0.5 + 0.35 * np.sin(j * 1.7 + k)
            left[start:end] += v * gain * (1 - pan)
            right[start:end] += v * gain * pan
        k += 1
        t0 += CHORD_LEN

    # Plucked arpeggio notes, denser in busier eras
    t = 0.5
    while t < total - 1:
        i = int(t * SR)
        m = float(mood[i])
        if m > 0.05 and rng.random() < 0.35 + 0.6 * m:
            chord = CHORDS[int(t // CHORD_LEN) % len(CHORDS)]
            pcs = {c % 12 for c in chord}
            choices = [p for p in PENTATONIC if p % 12 in pcs] or PENTATONIC
            note = choices[rng.integers(len(choices))]
            dur = int(2.5 * SR)
            end = min(n, i + dur)
            tt = np.arange(end - i) / SR
            f = hz(note)
            v = (np.sin(2 * np.pi * f * tt) + 0.25 * np.sin(2 * np.pi * 2 * f * tt)) * np.exp(-tt * 2.2)
            v *= np.minimum(1, tt / 0.004)
            g = 0.035 * (0.4 + 0.6 * m)
            pan = rng.uniform(0.2, 0.8)
            left[i:end] += v * g * (1 - pan)
            right[i:end] += v * g * pan
        t += 0.5 if m < 0.85 else 0.25

    left = 0.75 * left + 0.55 * reverb(left, seed=1)
    right = 0.75 * right + 0.55 * reverb(right, seed=2)

    fade = np.ones(n)
    fi, fo = int(3 * SR), int(6 * SR)
    fade[:fi] = np.linspace(0, 1, fi)
    fade[-fo:] = np.linspace(1, 0, fo)
    stereo = np.stack([left * fade, right * fade], axis=1)
    stereo *= 0.5 / np.max(np.abs(stereo))

    with wave.open(str(BUILD / "music.wav"), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes((stereo * 32767).astype(np.int16).tobytes())
    print(f"music.wav: {total:.1f}s")


if __name__ == "__main__":
    main()
