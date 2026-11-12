"""Exact-match editing of the specification HTML. Every edit asserts what it replaces."""
import re, sys
import pathlib
SPEC = str(pathlib.Path(__file__).resolve().parent.parent / 'Murmuration v4 specification.html')

class Doc:
    def __init__(self, path=SPEC):
        self.path = path
        self.s = open(path, encoding='utf-8').read()
        self.n = 0
    def sub(self, old, new, count=1):
        c = self.s.count(old)
        assert c == count, f'expected {count} match(es), found {c}: {old[:90]!r}'
        self.s = self.s.replace(old, new)
        self.n += 1
    def block(self, start, end, new):
        """Replace from the unique marker `start` up to (not including) the unique marker `end`."""
        assert self.s.count(start) == 1, f'start marker not unique: {start[:80]!r} ({self.s.count(start)})'
        i = self.s.index(start)
        j = self.s.index(end, i)
        assert self.s.count(end) >= 1
        self.s = self.s[:i] + new + self.s[j:]
        self.n += 1
    def line(self, must_contain, new_line):
        """Replace the single line that contains `must_contain` (unique)."""
        lines = self.s.split('\n')
        hits = [k for k, l in enumerate(lines) if must_contain in l]
        assert len(hits) == 1, f'expected 1 line, found {len(hits)}: {must_contain[:80]!r}'
        lines[hits[0]] = new_line
        self.s = '\n'.join(lines)
        self.n += 1
    def save(self):
        open(self.path, 'w', encoding='utf-8').write(self.s)
        print(f'{self.n} edits applied, {len(self.s)} chars')
