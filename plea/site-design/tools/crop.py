#!/usr/bin/env python3
"""Cuts a tall screenshot into parts you can look at: python3 tools/crop.py shot.png outdir [part_height]"""
import os
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
step = int(sys.argv[3]) if len(sys.argv) > 3 else None
im = Image.open(src)
w, h = im.size
step = step or (1600 if w > 500 else 2000)
os.makedirs(out, exist_ok=True)
base = os.path.splitext(os.path.basename(src))[0]
for i, y in enumerate(range(0, h, step)):
    p = os.path.join(out, f'{base}-part{i}.png')
    im.crop((0, y, w, min(h, y + step))).save(p)
    print(p)
