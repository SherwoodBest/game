#!/usr/bin/env bash
# Build ai-history.mp4 from script.json.
#
#   PYTHON=path/to/python VOICE=path/to/en_US-ryan-high.onnx ./build.sh
#
# PYTHON must have piper-tts and numpy installed. Steps that are already
# up to date can be skipped with SKIP_AUDIO=1 (reuse build/*.wav).
set -euo pipefail
cd "$(dirname "$0")"
PYTHON=${PYTHON:-python3}
JOBS=${JOBS:-4}

if [ -z "${SKIP_AUDIO:-}" ]; then
  : "${VOICE:?set VOICE to a Piper .onnx voice model}"
  "$PYTHON" tts.py --voice "$VOICE"
  "$PYTHON" music.py
fi

total=$(node -e "const t=require('./build/timeline.json'); console.log(Math.ceil(t.duration*30))")
per=$(( (total + JOBS - 1) / JOBS ))
rm -f build/seg_*.mp4 build/segments.txt
pids=()
for ((j = 0; j < JOBS; j++)); do
  from=$(( j * per )); to=$(( (j + 1) * per ))
  node render.mjs --from "$from" --to "$to" --out "build/seg_$j.mp4" &
  pids+=($!)
  echo "file 'seg_$j.mp4'" >> build/segments.txt
done
for p in "${pids[@]}"; do wait "$p"; done

ffmpeg -y -loglevel error -f concat -safe 0 -i build/segments.txt -c copy build/video.mp4

# Narration over the score, with the music ducking under the voice.
ffmpeg -y -loglevel error -i build/video.mp4 -i build/narration.wav -i build/music.wav -filter_complex "\
[1:a]aresample=48000,pan=stereo|c0=c0|c1=c0,asplit=2[v1][v2];\
[2:a]aresample=48000,volume=0.32[m];\
[m][v1]sidechaincompress=threshold=0.02:ratio=5:attack=80:release=900[md];\
[v2][md]amix=inputs=2:normalize=0,loudnorm=I=-16:TP=-1.5:LRA=11[a]" \
  -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 160k -ar 48000 -shortest -movflags +faststart ai-history.mp4

echo "wrote $(pwd)/ai-history.mp4"
