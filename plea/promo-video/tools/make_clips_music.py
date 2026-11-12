"""Music for the explainer clips ("How PLEA works"): "Spy Glass" (Kevin MacLeod, 110 BPM), a different track
from the promo so the series sounds like its own thing.
usage: python3 -I tools/make_clips_music.py <spy.wav> <data/spy-beats-original.json> <out dir> [bars]
The edit: the song's first 6 bars (its spy-bass riff, beats 0-23), then its last 2 bars (beats 392-399: the same
riff, chord for chord, as beats 24-31) with the closing hit on beat 399 and the ring-out, faded at 22.0 s.
bars = 10 (the contest clip, ~29.7 s): the first 10 bars, then the same last 2 bars (bar 10 opens the riff's next
phrase like bar 98 does: beat chroma 0.92 against bar 98; bars 2, 6, 10 and 14 open the song's 4-bar phrases).
Writes <out>/clip.wav (-14 LUFS) and <out>/beats-clip.json (beats, downbeats and the hit, from the measured beats)."""
import json, subprocess, sys

wav, fit, out = sys.argv[1:4]
bars = int(sys.argv[4]) if len(sys.argv) > 4 else 6
bt = json.load(open(fit))["beats"]
PRE = 0.025                                   # cut a hair before each downbeat
parts = [(0.35, bt[4 * bars] - PRE), (bt[392] - PRE, 222.0)]
beats, t = [], 0.0
for a, b in parts:
    beats += [x - a + t for x in bt if a <= x < b]
    t += b - a
hit = bt[399] - parts[1][0] + (parts[0][1] - parts[0][0])
filt = [f"[0:a]atrim=start={a:.4f}:end={b:.4f},asetpts=PTS-STARTPTS[p{i}]" for i, (a, b) in enumerate(parts)]
filt.append(f"[p0][p1]acrossfade=d=0.02:c1=tri:c2=tri,afade=t=out:st={t - 1.4:.3f}:d=1.4,loudnorm=I=-14:TP=-1.5:LRA=11[o]")
subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-filter_complex", ";".join(filt), "-map", "[o]", "-ar", "48000", f"{out}/clip.wav"], check=True)
beats = [round(x, 4) for x in beats]
json.dump({"bpm": 60 / ((bt[-1] - bt[0]) / (len(bt) - 1)), "beats": beats, "downbeats": beats[::4], "hit": round(hit, 4), "length": round(t, 3)},
          open(f"{out}/beats-clip.json", "w"))
print(f"{t:.2f} s, {len(beats)} beats, downbeats {[round(x, 2) for x in beats[::4]]}, hit {hit:.3f}")
