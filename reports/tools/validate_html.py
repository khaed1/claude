"""Validate the specification HTML: tag balance, unique ids, in-page links."""
import sys, re
from html.parser import HTMLParser
VOID = {'meta','link','br','hr','img','input','path','circle','rect','line','polyline','polygon','ellipse','use','stop','col'}
class V(HTMLParser):
    def __init__(s):
        super().__init__(convert_charrefs=True); s.stack=[]; s.ids=[]; s.hrefs=[]; s.errs=[]
    def handle_starttag(s, tag, attrs):
        a=dict(attrs)
        if 'id' in a: s.ids.append(a['id'])
        if tag=='a' and a.get('href','').startswith('#'): s.hrefs.append(a['href'][1:])
        if tag not in VOID: s.stack.append((tag, s.getpos()[0]))
    def handle_startendtag(s, tag, attrs):
        a=dict(attrs)
        if 'id' in a: s.ids.append(a['id'])
    def handle_endtag(s, tag):
        if tag in VOID: return
        if not s.stack: s.errs.append(f'line {s.getpos()[0]}: closing </{tag}> with empty stack'); return
        t,l = s.stack[-1]
        if t==tag: s.stack.pop()
        else:
            s.errs.append(f'line {s.getpos()[0]}: </{tag}> closes <{t}> opened at line {l}')
            for k in range(len(s.stack)-1,-1,-1):
                if s.stack[k][0]==tag: del s.stack[k:]; break
import pathlib
p = sys.argv[1] if len(sys.argv)>1 else str(pathlib.Path(__file__).resolve().parent.parent / 'Murmuration v4 specification.html')
src=open(p,encoding='utf-8').read()
v=V(); v.feed(src)
ok=True
for e in v.errs[:20]: print('TAG', e); ok=False
for t,l in v.stack: print('UNCLOSED', t, 'line', l); ok=False
dups={i for i in v.ids if v.ids.count(i)>1}
if dups: print('DUPLICATE IDS', sorted(dups)); ok=False
missing=sorted({h for h in v.hrefs if h and h not in v.ids})
if missing: print('BROKEN LINKS', missing); ok=False
print('ids', len(v.ids), 'in-page links', len(v.hrefs), 'OK' if ok else 'FAILED')
sys.exit(0 if ok else 1)
