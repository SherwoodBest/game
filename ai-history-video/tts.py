"""Synthesize the narration with Piper and lay out the video timeline.

Writes, under build/:
  tts/<scene>_<n>.wav   one clip per narration sentence
  narration.wav         every clip placed at its start time (22.05 kHz mono)
  timeline.json         scene and sentence timings, read by render.mjs
and ai-history.srt next to this file.

Usage: python tts.py --voice path/to/en_US-ryan-high.onnx
"""

import argparse
import json
import wave
from pathlib import Path

import numpy as np
from piper import PiperVoice
from piper.config import SynthesisConfig

HERE = Path(__file__).resolve().parent
BUILD = HERE / "build"

LEAD = 0.9    # seconds before the first sentence of a scene
GAP = 0.45    # silence between sentences
TAIL = 1.1    # silence after the last sentence of a scene
FIRST_LEAD = 2.2  # the opening title gets a little longer to land
LAST_TAIL = 7.0   # hold the end card


def srt_time(t):
    ms = int(round(t * 1000))
    h, ms = divmod(ms, 3_600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02}:{m:02}:{s:02},{ms:03}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--voice", required=True)
    ap.add_argument("--length-scale", type=float, default=1.0)
    args = ap.parse_args()

    script = json.loads((HERE / "script.json").read_text())
    voice = PiperVoice.load(args.voice)
    cfg = SynthesisConfig(length_scale=args.length_scale, volume=0.8)
    rate = voice.config.sample_rate

    (BUILD / "tts").mkdir(parents=True, exist_ok=True)
    scenes = script["scenes"]
    timeline = {"sampleRate": rate, "scenes": []}
    clips = []
    t = 0.0
    for si, scene in enumerate(scenes):
        start = t
        t += FIRST_LEAD if si == 0 else LEAD
        sentences = []
        for i, text in enumerate(scene["narration"]):
            spoken = scene.get("say", {}).get(str(i), text)
            path = BUILD / "tts" / f"{scene['id']}_{i}.wav"
            stamp = path.with_suffix(".txt")
            key = f"{args.voice}|{args.length_scale}|{spoken}"
            if not (path.exists() and stamp.exists() and stamp.read_text() == key):
                with wave.open(str(path), "wb") as wf:
                    voice.synthesize_wav(spoken, wf, syn_config=cfg)
                stamp.write_text(key)
            with wave.open(str(path), "rb") as wf:
                audio = np.frombuffer(wf.readframes(wf.getnframes()), dtype=np.int16)
            dur = len(audio) / rate
            sentences.append({"text": text, "start": round(t, 3), "end": round(t + dur, 3)})
            clips.append((t, audio))
            t += dur + GAP
        t += (LAST_TAIL if si == len(scenes) - 1 else TAIL) - GAP
        timeline["scenes"].append({"id": scene["id"], "start": round(start, 3),
                                   "end": round(t, 3), "sentences": sentences})
        print(f"{scene['id']:<12} {start:7.2f}s -> {t:7.2f}s")
    timeline["duration"] = round(t, 3)

    mix = np.zeros(int(t * rate) + rate, dtype=np.int32)
    for start, audio in clips:
        i = int(start * rate)
        mix[i:i + len(audio)] += audio
    with wave.open(str(BUILD / "narration.wav"), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(rate)
        wf.writeframes(np.clip(mix, -32768, 32767).astype(np.int16).tobytes())

    (BUILD / "timeline.json").write_text(json.dumps(timeline, indent=1))

    lines = []
    n = 1
    for scene in timeline["scenes"]:
        for s in scene["sentences"]:
            lines += [str(n), f"{srt_time(s['start'])} --> {srt_time(s['end'] + 0.2)}", s["text"], ""]
            n += 1
    (HERE / "ai-history.srt").write_text("\n".join(lines))
    print(f"total {t:.1f}s, {n - 1} captions")


if __name__ == "__main__":
    main()
