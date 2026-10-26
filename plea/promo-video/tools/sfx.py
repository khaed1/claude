"""Sound effects, synthesized in code and placed on the music's beat grid.
usage: python3 -I tools/sfx.py <beats json> <music wav> <out dir>                     (the promo)
       python3 -I tools/sfx.py clip <clipN> <data dir> <music wav> <out dir>            (an explainer clip)
writes <out>/sfx.wav (48 kHz mono) and <out>/mix.wav (music + effects, -14 LUFS via ffmpeg loudnorm).
A clip replays the promo's cues inside each promo bar range it borrows (same tempo, same offsets), plus
its own shots' cues (data/clips.json: hook and end card, and "cues" per segment: [bar, beat, kind, gain])."""
import json, math, subprocess, sys, wave
import numpy as np

SR = 48000
def grid(G):
    BAR = lambda n: G["downbeats"][n] if 0 <= n < len(G["downbeats"]) else G["downbeats"][0] + n * 240 / G["bpm"]
    return BAR, (lambda n, b=0: BAR(n) + b * 60 / G["bpm"])
rng = np.random.default_rng(14)

def env(n, attack, decay):
    t = np.arange(n) / SR
    return np.minimum(1, t / max(attack, 1e-4)) * np.exp(-t / decay)

def lowpass(x, cutoff):
    a = math.exp(-2 * math.pi * cutoff / SR); y = np.empty_like(x); acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc; y[i] = acc
    return y

def noise(n):
    return rng.uniform(-1, 1, n)

def thump(big=1.0):            # the stamp: a falling sine and a short paper slap
    n = int(0.45 * SR); t = np.arange(n) / SR
    body = np.sin(2 * math.pi * (110 * t - 70 * t * t)) * env(n, 0.002, 0.12)
    slap = lowpass(noise(n), 2500) * env(n, 0.0005, 0.018) * 1.6
    return (body * 0.9 + slap) * big

def tap(f=1400, d=0.03):       # a card or receipt landing
    n = int(0.08 * SR); t = np.arange(n) / SR
    return (np.sin(2 * math.pi * f * t) * env(n, 0.0005, d) * 0.4 + lowpass(noise(n), 4000) * env(n, 0.0003, 0.006) * 0.6)

def key():                     # one keystroke
    n = int(0.03 * SR)
    return lowpass(noise(n), 6000 + rng.uniform(-1500, 1500)) * env(n, 0.0002, 0.004) * 0.5

def pop(f0=500, f1=1100, d=0.05):
    n = int(0.12 * SR); t = np.arange(n) / SR
    return np.sin(2 * math.pi * (f0 * t + (f1 - f0) * t * t / 0.12 / 2)) * env(n, 0.001, d) * 0.45

def whoosh(dur=0.35, lo=400, hi=3000):
    n = int(dur * SR); t = np.arange(n) / SR
    x = noise(n); y = np.empty(n); acc = 0.0
    for i in range(n):        # a sweeping one-pole low-pass
        c = lo + (hi - lo) * math.sin(math.pi * i / n)
        a = math.exp(-2 * math.pi * c / SR); acc = (1 - a) * x[i] + a * acc; y[i] = acc
    return y * np.sin(np.pi * t / dur) ** 2 * 1.4

def tick(f=2200, d=0.012, g=0.35):
    n = int(0.05 * SR); t = np.arange(n) / SR
    return np.sin(2 * math.pi * f * t) * env(n, 0.0003, d) * g

def bell(f=880, d=0.6, g=0.35):
    n = int(1.4 * SR); t = np.arange(n) / SR
    return sum(np.sin(2 * math.pi * f * m * t) * a for m, a in [(1, 1), (2.01, 0.5), (3.02, 0.25), (4.1, 0.12)]) * env(n, 0.002, d) * g

def slam():                    # OBJECTION!: a stamp with a snare crack
    n = int(0.45 * SR)
    crack = lowpass(noise(n), 7000) * env(n, 0.0005, 0.06) * 0.9
    return thump(1.2) + crack

def scratch(dur=0.28):         # a pen strike
    n = int(dur * SR); t = np.arange(n) / SR
    return lowpass(noise(n), 3500) * (np.sin(np.pi * t / dur) ** 0.5) * 0.35

def flatline(dur=1.1, f=1000):  # the heart monitor when the Cabal dies
    n = int(dur * SR); t = np.arange(n) / SR
    fade = np.minimum(1, t / 0.01) * np.minimum(1, (dur - t) / 0.08)
    return np.sin(2 * math.pi * f * t) * fade * 0.22

def switch():                  # lights out
    n = int(0.12 * SR); t = np.arange(n) / SR
    return (np.sin(2 * math.pi * 70 * t) * env(n, 0.001, 0.05) * 0.8 + lowpass(noise(n), 3000) * env(n, 0.0003, 0.008) * 0.8)

def ratchet(n_clicks=8, span=0.4):
    out_ = np.zeros(int((span + 0.06) * SR))
    for i in range(n_clicks):
        s = tick(1500 + 120 * i, 0.006, 0.3); at = int(i * span / n_clicks * SR); out_[at:at + len(s)] += s
    return out_

def promo_cues(G):
    BAR, AT = grid(G)
    cues = []   # (time, sound, gain)
    def add(t, s, g=1.0): cues.append((t, s, g))

    # 1 · Opening: a key per word, the stamp on the band's entrance, a pop for the small line.
    for at in [AT(-1, b) for b in (0, 0.5, 1, 2, 2.5, 3, 3.5)]: add(at, tap(900, 0.02), 0.5)
    add(BAR(0), thump(1.3), 1.0); add(BAR(1), pop(), 0.5)
    # 2 · Writing: keystrokes on sixteenths, a pan whoosh, the button press.
    t = AT(2, 2)
    while t < AT(4, 1.5):
        add(t + rng.uniform(-0.012, 0.012), key(), 6.0); t += 60 / G["bpm"] / 4
    add(AT(4, 2), whoosh(0.3, 300, 1500), 0.35); add(AT(4, 3.5), tap(1800, 0.015), 0.8)
    # 3 · Sent: lift, fold, whoosh to the docket, the pending stamp, the receipt.
    add(BAR(5), pop(400, 800), 0.4); add(AT(5, 1), scratch(0.12), 0.9); add(AT(5, 1.3), tap(700, 0.03), 0.6)
    add(AT(5, 2.5), whoosh(0.45), 0.6); add(AT(5, 3.2), thump(0.45), 0.6); add(AT(6, 1), tap(1100, 0.04), 0.7)
    # 4 · Judges: a tick per answering seat, pitched by its score; the sort; the answer rises.
    scores = [35, 39, 35, 37, 35, 35, 34, 35, 34, 33, 30, 38, 33, 33, 34, 35, 35]
    add(BAR(7), whoosh(0.25, 800, 4000), 0.3)
    for k, sc in enumerate(scores): add(AT(7, 1) + k * 0.1225, tick(1200 + 60 * (sc - 30), 0.02), 3.5)
    add(BAR(9), whoosh(0.3, 600, 2500), 0.5); add(AT(9, 2), bell(1046, 0.5), 0.8); add(BAR(10), thump(0.5), 0.6); add(AT(10, 1), pop(), 0.4)
    # 5 · The bar: a card per fact, the need marker ratchets, the score sweeps up.
    for b in range(4): add(AT(11, b), tap(1000, 0.03), 0.6)
    add(BAR(12), ratchet(10, 0.45), 0.7); add(AT(12, 2), whoosh(0.5, 300, 2200), 0.4)
    # 6 · DENIED: the stamp on the last hit, then the silence; the wipe on the roll.
    add(29.54, thump(1.5), 1.1); add(31.9, whoosh(0.35), 0.5)
    # 7 · APPROVED → SOLD: the card slides in, the stamp with the band, the window ticks, the press, SOLD.
    add(32.15, whoosh(0.4, 300, 1800), 0.35); add(BAR(16), thump(1.3), 1.0); add(BAR(17), pop(), 0.4)
    for s in range(4): add(BAR(17) + s, tick(1600, 0.01, 0.4), 2.5)
    add(BAR(18), tap(1800, 0.015), 0.9); add(AT(18, 2), thump(0.9), 0.9)
    # 8 · OBJECTION!: the slam, the slab off, the second panel flickers, SUSTAINED, the strike, the page.
    add(BAR(19), slam(), 1.1); add(AT(19, 2), whoosh(0.35), 0.5)
    for k in range(10): add(AT(19, 2) + 0.09 * k, tick(1400 + 80 * (k % 4), 0.01), 2.0)
    add(BAR(20), thump(1.1), 1.0); add(AT(20, 1.5), scratch(), 1.0); add(BAR(21), whoosh(0.4, 300, 2000), 0.45)
    # 9 · Letters: the card, the hex chatter as it decodes, sent, pending.
    add(BAR(22), pop(), 0.4)
    t = AT(22, 1)
    while t < BAR(24) - 0.3:
        add(t, tick(2600 + rng.uniform(-300, 300), 0.004, 0.25), 2.0); t += 60 / G["bpm"] / 8
    add(BAR(24), whoosh(0.45), 0.6); add(AT(24, 1), thump(0.45), 0.6)
    # 10 · Seasons: the page, the outline drawn, PRIZE PAID with a bell.
    add(BAR(25), pop(350, 700), 0.4); add(BAR(26), scratch(0.4), 0.8); add(BAR(27), thump(1.0), 0.9); add(BAR(27) + 0.05, bell(1318, 0.4), 0.5)
    # 11 · The dead-man: a rattle on each clock jump, the flatline at zero, the seats go dark, lights out.
    for h in [57.845, 58.815, 59.305, 60.765]: add(h, ratchet(6, 0.18), 0.8)
    add(61.18, flatline(), 1.0)
    for k in range(30): add(61.18 + 0.045 * k, tick(900, 0.01, 0.2), 0.5)
    add(62.58, switch(), 1.0)
    # 12 · The end: receipts land, the end card slides, the final stamp on the hard stop.
    for n in (33, 34, 35): add(BAR(n), tap(900, 0.05), 0.8)
    add(BAR(36), whoosh(0.5, 300, 1800), 0.45); add(BAR(38), thump(1.6), 1.2)

    return cues

def mix(cues, dur, music_path, out):
  track = np.zeros(int(dur * SR) + SR)
  for at, s, g in cues:
      i = int(round(at * SR))
      if i < 0: continue
      seg = s[: len(track) - i] * g
      track[i:i + len(seg)] += seg
  track = track[: int(dur * SR)]
  track *= 0.5 / max(1e-9, np.abs(track).max())          # effects peak at -6 dBFS before the mix
  pcm = (np.clip(track, -1, 1) * 32767).astype(np.int16)
  with wave.open(f"{out}/sfx.wav", "wb") as w:
      w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
  subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", music_path, "-i", f"{out}/sfx.wav", "-filter_complex",
                  "[1:a]volume=0.9,pan=stereo|c0=c0|c1=c0[s];[0:a][s]amix=inputs=2:duration=first:normalize=0,loudnorm=I=-14:TP=-1.5:LRA=11[o]",
                  "-map", "[o]", "-ar", "48000", f"{out}/mix.wav"], check=True)
  print(len(cues), "cues;", f"{out}/sfx.wav", f"{out}/mix.wav")


KINDS = {"thump": lambda: thump(1.1), "thump_small": lambda: thump(0.5), "tap": lambda: tap(1000, 0.04), "pop": pop, "whoosh": lambda: whoosh(0.4),
         "slam": slam, "scratch": scratch, "tick": lambda: tick(1600, 0.012, 0.4), "bell": lambda: bell(1046, 0.5), "ratchet": lambda: ratchet(8, 0.35),
         "flatline": flatline, "switch": switch}

if sys.argv[1] == "clip":
    name, data, music_path, out = sys.argv[2:6]
    cfg = json.load(open(f"{data}/clips.json"))[name]
    PG = json.load(open(f"{data}/beats-16x9.json")); PBAR, _ = grid(PG)
    CG = json.load(open(f"{data}/beats-clip-{cfg['music']}.json")); CBAR, CAT = grid(CG)
    promo = promo_cues(PG)
    cues = []
    for seg in cfg["segments"]:
        a = CBAR(seg["from"]); b = CBAR(seg["to"]) if seg["to"] < 99 else CG["length"]
        if "promo" in seg:
            p0 = PBAR(seg["promo"])
            p1 = min(p0 + (b - a), PBAR(seg["promo"] + seg["to"] - seg["from"]))
            cues += [(t - p0 + a, s, g) for t, s, g in promo if p0 <= t < p1]
        if seg.get("shot") == "hook":
            nwords = sum(len(l) for l in seg["opts"]["lines"])
            cues += [(CAT(0, 0), pop(400, 800), 0.4)] + [(CAT(0, 0.5 + 0.5 * k), tap(900, 0.02), 0.5) for k in range(nwords)]
            if seg["opts"].get("small"): cues.append((CAT(0, 3), pop(), 0.5))
        if seg.get("shot") == "endcard":
            cues += [(CBAR(9), whoosh(0.5, 300, 1800), 0.45), (CBAR(10), thump(1.6), 1.2)]
        for bar, beat, kind, gain in seg.get("cues", []):
            cues.append((CAT(seg["from"] + bar, beat), KINDS[kind](), gain))
    mix(cues, CG["length"], music_path, out)
else:
    beats_path, music_path, out = sys.argv[1:4]
    mix(promo_cues(json.load(open(beats_path))), 78.37, music_path, out)
