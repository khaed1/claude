"""Contact sheet: python3 -I tools/contact.py <out.png> <cols> <width per tile> <png...>  (labels = file names)."""
import sys
from PIL import Image, ImageDraw

out, cols, tw, *files = sys.argv[1:]
cols, tw = int(cols), int(tw)
ims = [Image.open(f).convert("RGB") for f in files]
th = round(tw * ims[0].height / ims[0].width)
rows = (len(ims) + cols - 1) // cols
pad, lab = 8, 22
sheet = Image.new("RGB", (cols * (tw + pad) + pad, rows * (th + lab + pad) + pad), (40, 40, 40))
d = ImageDraw.Draw(sheet)
for i, (im, f) in enumerate(zip(ims, files)):
    x = pad + (i % cols) * (tw + pad)
    y = pad + (i // cols) * (th + lab + pad)
    sheet.paste(im.resize((tw, th), Image.LANCZOS), (x, y + lab))
    d.text((x + 2, y + 4), f.rsplit("/", 1)[-1], fill=(230, 230, 230))
sheet.save(out)
print(out, sheet.size)
