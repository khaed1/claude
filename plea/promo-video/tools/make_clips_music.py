"""Music for the explainer clips, cut from the same "The Builder" wav as the promo.
usage: python3 -I tools/make_clips_music.py <builder.wav> <fit.json (measured beats of the original)> <out dir>
Each clip: 9 bars from a section's first downbeat, then the song's last bar and its hard stop (A, B, C),
or break 3 straight to the end (D, the dead-man). Writes <out>/clip_<X>.wav (-14 LUFS) and
<out>/beats-clip-<X>.json (the clip's beats and downbeats, taken from the original's measured beats)."""
import json, subprocess, sys

wav, fit, out = sys.argv[1:4]
bt = json.load(open(fit))["beats"]          # beat 0 = the band's entrance (bar 0), four beats a bar
B = lambda bar: bt[4 * bar]
PRE, END = 0.025, 114.5                      # cut a hair before each downbeat; stop 1.3 s after the final hit
CLIPS = {"A": [(0, 9), (53, None)], "B": [(16, 9), (53, None)], "C": [(32, 9), (53, None)], "D": [(44, None)]}

for name, segs in CLIPS.items():
    parts, beats, t = [], [], 0.0
    for start, n in segs:
        a = B(start) - PRE
        b = (B(start + n) - PRE) if n else END
        parts.append((a, b))
        beats += [x - a + t for x in bt if a <= x < b]
        t += b - a
    filt, labels = [], []
    for i, (a, b) in enumerate(parts):
        filt.append(f"[0:a]atrim=start={a:.4f}:end={b:.4f},asetpts=PTS-STARTPTS[p{i}]")
        labels.append(f"p{i}")
    chain = labels[0]
    for i in range(1, len(labels)):
        filt.append(f"[{chain}][{labels[i]}]acrossfade=d=0.02:c1=tri:c2=tri[x{i}]")
        chain = f"x{i}"
    filt.append(f"[{chain}]afade=t=out:st={t - 0.9:.3f}:d=0.9,loudnorm=I=-14:TP=-1.5:LRA=11[o]")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-filter_complex", ";".join(filt), "-map", "[o]", "-ar", "48000", f"{out}/clip_{name}.wav"], check=True)
    beats = [round(x, 4) for x in beats]
    json.dump({"bpm": 60 / ((bt[-1] - bt[0]) / (len(bt) - 1)), "beats": beats, "downbeats": beats[::4], "length": round(t, 3)},
              open(f"{out}/beats-clip-{name}.json", "w"))
    print(name, f"{t:.2f} s", len(beats), "beats; final hit at", round(beats[-1], 3))
