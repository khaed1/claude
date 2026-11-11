#!/usr/bin/env python3
"""Render a Murmuration HTML page as plain text for reviewers.
Usage: render_text.py IN.html OUT.txt
Keeps headings, paragraphs, lists, tables (pipe rows), code blocks and the text of diagrams.
Drops style, script and the navigation index."""
import sys, re, html
from html.parser import HTMLParser

BLOCK = {'p','div','section','article','header','footer','main','aside','figure','figcaption','details','summary','blockquote','dl','dt','dd','nav'}
SKIP = {'style','script','head','title'}

class R(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out=[]; self.buf=[]; self.skip=0; self.pre=0
        self.lists=[]; self.table=None; self.row=None; self.cell=None
        self.svg=0; self.svgtexts=[]; self.nav=0
    def flush(self, prefix=''):
        t=''.join(self.buf); self.buf=[]
        if not self.pre:
            t=re.sub(r'\s+',' ',t).strip()
        if t:
            self.out.append(prefix+t)
    def handle_starttag(self, tag, attrs):
        a=dict(attrs)
        if tag in SKIP: self.skip+=1; return
        if self.skip: return
        if tag=='nav': self.flush(); self.nav+=1; return
        if self.nav: return
        if tag=='svg': self.flush(); self.svg+=1; self.svgtexts=[]; return
        if self.svg:
            if tag in('text','tspan','title','desc'): self.svgtexts.append('')
            return
        if tag=='sup':
            (self.cell if self.cell is not None else self.buf).append('^'); return
        if tag=='sub':
            (self.cell if self.cell is not None else self.buf).append('_'); return
        if self.cell is not None:
            if tag=='br': self.cell.append(' / ')
            elif tag=='code': self.cell.append('`')
            elif tag=='li': self.cell.append(' - ')
            return
        if tag in('h1','h2','h3','h4','h5'):
            self.flush(); self.out.append(''); self.htag=tag; self.hid=a.get('id')
        elif tag in BLOCK: self.flush()
        elif tag=='br': self.buf.append('\n' if self.pre else ' ')
        elif tag=='pre': self.flush(); self.pre+=1; self.out.append('```')
        elif tag=='code':
            if not self.pre: self.buf.append('`')
        elif tag in('ul','ol'): self.flush(); self.lists.append([tag,0])
        elif tag=='li':
            self.flush()
        elif tag=='table': self.flush(); self.table=[]
        elif tag=='tr' and self.table is not None: self.row=[]
        elif tag in('td','th') and self.row is not None: self.cell=[]
        elif tag=='hr': self.flush(); self.out.append('-----')
    def handle_endtag(self, tag):
        if tag in SKIP: self.skip-=1; return
        if self.skip: return
        if tag=='nav': self.nav-=1; self.buf=[]; return
        if self.nav: return
        if tag=='svg':
            self.svg-=1
            ts=[re.sub(r'\s+',' ',t).strip() for t in self.svgtexts]
            ts=[t for t in ts if t]
            if ts: self.out.append('[Diagram, text only: '+' | '.join(ts)+']')
            return
        if self.svg: return
        if self.cell is not None:
            if tag=='code': self.cell.append('`')
            elif tag in('td','th'):
                self.row.append(re.sub(r'\s+',' ',''.join(self.cell)).strip()); self.cell=None
            return
        if tag in('h1','h2','h3','h4','h5'):
            t=re.sub(r'\s+',' ',''.join(self.buf)).strip(); self.buf=[]
            lvl=int(tag[1]); self.out.append('#'*lvl+' '+t); self.out.append('')
        elif tag in BLOCK: self.flush(); self.out.append('')
        elif tag=='pre':
            t=''.join(self.buf).strip('\n'); self.buf=[]; self.out.append(t); self.out.append('```'); self.out.append(''); self.pre-=1
        elif tag=='code':
            if not self.pre: self.buf.append('`')
        elif tag=='li':
            depth=len(self.lists)
            if self.lists:
                l=self.lists[-1]; l[1]+=1
                mark=(str(l[1])+'. ') if l[0]=='ol' else '- '
            else: mark='- '
            self.flush('  '*(depth-1)+mark)
        elif tag in('ul','ol'):
            self.flush()
            if self.lists: self.lists.pop()
            if not self.lists: self.out.append('')
        elif tag=='tr' and self.table is not None and self.row is not None:
            self.table.append(self.row); self.row=None
        elif tag=='table' and self.table is not None:
            for r in self.table: self.out.append('| '+' | '.join(r)+' |')
            self.out.append(''); self.table=None
    def handle_data(self, d):
        if self.skip or self.nav: return
        if self.svg:
            if self.svgtexts: self.svgtexts[-1]+=d
            return
        if self.cell is not None: self.cell.append(d); return
        self.buf.append(d)

def render(src):
    r=R(); r.feed(src); r.flush()
    lines=[]; blank=0
    for l in r.out:
        if l.strip()=='' :
            blank+=1
            if blank>1: continue
        else: blank=0
        lines.append(l.rstrip())
    return '\n'.join(lines).strip()+'\n'

if __name__=='__main__':
    s=open(sys.argv[1],encoding='utf-8').read()
    t=render(s)
    open(sys.argv[2],'w',encoding='utf-8').write(t)
    print(len(t),'chars',t.count('\n'),'lines')
