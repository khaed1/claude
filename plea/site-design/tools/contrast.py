# WCAG contrast of colour pairs: python3 tools/contrast.py name=#FG/#BG:min ...  (exit 1 if any pair is under its minimum)
import sys
def lin(c):
    c/=255
    return c/12.92 if c<=0.04045 else ((c+0.055)/1.055)**2.4
def L(h):
    h=h.lstrip('#'); r,g,b=(int(h[i:i+2],16) for i in (0,2,4))
    return 0.2126*lin(r)+0.7152*lin(g)+0.0722*lin(b)
def cr(a,b):
    la,lb=sorted((L(a),L(b)),reverse=True); return (la+0.05)/(lb+0.05)
# usage: pairs "fg/bg:min" ...
bad=0
for p in sys.argv[1:]:
    name,rest=p.split('=') if '=' in p else ('',p)
    fgbg,mn=rest.split(':'); fg,bg=fgbg.split('/')
    v=cr(fg,bg); ok=v>=float(mn); bad+= not ok
    print(f"{'OK ' if ok else 'BAD'} {v:5.2f} (min {mn}) {name} {fg} on {bg}  L={L(fg):.3f}/{L(bg):.3f}")
sys.exit(1 if bad else 0)
