# SEED

A 48-second film where every frame and every note is computed in `film.py`. It uses no footage, samples or image assets; the only inputs are system fonts.

| Time | Scene | Technique |
| --- | --- | --- |
| 0:00 | A single point | Radial glow and twinkling dust |
| 0:04 | Bloom | Phyllotaxis: each point turns by the golden angle (137.508°), and the 21 Fibonacci spiral arms light up in time with the music |
| 0:13 | Wind | 14,000 particles, starting from the bloom's dots, follow a time-varying flow field and leave fading trails |
| 0:22 | Horizon | Fractal value-noise mountain ranges with parallax, haze, a setting sun and fireflies; a new star appears on each melody note |
| 0:31 | Closer | A Julia set whose parameter drifts as the camera zooms and turns |
| 0:40 | Seed | The bloom collapses back into a point on the downbeat, then the title |

The score is synthesized in the same file: additive pads over a D-major progression at 90 BPM, plucks (one for each of the first new points in the bloom), a kick that pulses the particle trails, bell melodies, a riser, and a convolution reverb built from shaped noise. The visuals use the same beat grid, so picture and sound stay in sync.

```sh
python3 showcase/film.py            # renders showcase/seed.mp4 (about 5 minutes on 4 cores)
python3 showcase/film.py --stills   # writes test frames to showcase/stills/
```

Needs Python 3 with numpy and Pillow, plus ffmpeg.
