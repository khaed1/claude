"""The contest clip's X action icons, cut from the pinned post's own action bar (pinned.png, the owner's screenshot,
1174 px wide: rows 858-908) as transparent PNGs: <name>-gray for every icon, repost-green and like-pink (the heart filled).
usage: python3 -I tools/cut_x_icons.py <CAPTURES>/contest   (writes <dir>/icons/)"""
import os, sys
import numpy as np
from PIL import Image

d = sys.argv[1]
os.makedirs(f"{d}/icons", exist_ok=True)
b = np.array(Image.open(f"{d}/pinned.png").convert("RGB")).astype(float)
Y0, Y1 = 858, 908
ICONS = {"reply": (108, 146), "repost": (340, 383), "like": (577, 615), "views": (814, 846), "bookmark": (1048, 1080), "share": (1109, 1144)}

def save(name, tag, rgb, alpha):
    im = np.zeros(alpha.shape + (4,), np.uint8); im[..., :3] = rgb; im[..., 3] = (alpha * 255).round()
    Image.fromarray(im, "RGBA").save(f"{d}/icons/{name}-{tag}.png")

def fill(a):   # the outline plus everything it encloses (flood from the border, 4-neighbour)
    wall = a > 0.35
    out = np.zeros_like(wall)
    h, w = wall.shape
    stack = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    while stack:
        y, x = stack.pop()
        if 0 <= y < h and 0 <= x < w and not out[y, x] and not wall[y, x]:
            out[y, x] = True
            stack += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    return np.maximum(a, (~out).astype(float))

for name, (x0, x1) in ICONS.items():
    a = np.clip(b[Y0:Y1, x0:x1].max(2) / 117.0, 0, 1)   # X's icon grey #71767B is ~117 at its brightest channel
    save(name, "gray", (113, 118, 123), a)
    if name == "repost": save(name, "green", (0, 186, 124), a)
    if name == "like": save(name, "pink", (249, 24, 128), fill(a))
print("icons in", f"{d}/icons")
