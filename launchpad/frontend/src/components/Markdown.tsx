import { Fragment, type ReactNode } from 'react';
import { Link } from 'react-router-dom';

// A small Markdown renderer for our own texts (legal, docs): headings, paragraphs, lists, tables, quotes,
// **bold**, *italic*, `code` and [links](url). It builds React elements, never HTML strings.
function inline(s: string, key = 0): ReactNode[] {
  const out: ReactNode[] = [];
  const re = /(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|\[[^\]]+\]\([^)]+\))/g;
  let last = 0;
  let m: RegExpExecArray | null;
  while ((m = re.exec(s))) {
    if (m.index > last) out.push(s.slice(last, m.index));
    const t = m[0];
    const k = `${key}-${m.index}`;
    if (t.startsWith('**')) out.push(<strong key={k}>{inline(t.slice(2, -2), m.index)}</strong>);
    else if (t.startsWith('`')) out.push(<code key={k}>{t.slice(1, -1)}</code>);
    else if (t.startsWith('[')) {
      const [, text, href] = /\[([^\]]+)\]\(([^)]+)\)/.exec(t)!;
      const safe = /^(https:|\/|#|mailto:)/.test(href) ? href : undefined;
      out.push(!safe ? text : safe.startsWith('/') ? <Link key={k} to={safe}>{text}</Link> : <a key={k} href={safe} target={safe.startsWith('https:') ? '_blank' : undefined} rel="noreferrer">{text}</a>);
    } else out.push(<em key={k}>{inline(t.slice(1, -1), m.index)}</em>);
    last = m.index + t.length;
  }
  if (last < s.length) out.push(s.slice(last));
  return out;
}

export const slug = (s: string) => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

export function Markdown({ text }: { text: string }) {
  const lines = text.replace(/\r/g, '').split('\n');
  const blocks: ReactNode[] = [];
  let i = 0;
  while (i < lines.length) {
    const l = lines[i];
    if (!l.trim()) { i++; continue; }
    const h = /^(#{1,4}) (.*)$/.exec(l);
    if (h) {
      const Tag = `h${h[1].length}` as 'h1';
      blocks.push(<Tag key={i} id={slug(h[2])}>{inline(h[2])}</Tag>);
      i++;
      continue;
    }
    if (l.startsWith('|')) {
      const rows: string[][] = [];
      while (i < lines.length && lines[i].startsWith('|')) {
        if (!/^\|[\s|:-]+\|$/.test(lines[i])) rows.push(lines[i].slice(1, -1).split('|').map((c) => c.trim()));
        i++;
      }
      blocks.push(
        <div className="md-table" key={i}><table><thead><tr>{rows[0].map((c, j) => <th key={j}>{inline(c)}</th>)}</tr></thead>
          <tbody>{rows.slice(1).map((r, k) => <tr key={k}>{r.map((c, j) => <td key={j}>{inline(c)}</td>)}</tr>)}</tbody></table></div>,
      );
      continue;
    }
    if (/^(\d+\.|-) /.test(l)) {
      const ordered = /^\d+\./.test(l);
      const items: string[] = [];
      while (i < lines.length && /^(\d+\.|-) /.test(lines[i])) {
        let item = lines[i].replace(/^(\d+\.|-) /, '');
        i++;
        while (i < lines.length && /^ {2,}\S/.test(lines[i])) item += ' ' + lines[i++].trim();
        items.push(item);
      }
      const List = ordered ? 'ol' : 'ul';
      blocks.push(<List key={i}>{items.map((t, k) => <li key={k}>{inline(t)}</li>)}</List>);
      continue;
    }
    if (l.startsWith('> ')) {
      const q: string[] = [];
      while (i < lines.length && lines[i].startsWith('> ')) q.push(lines[i++].slice(2));
      blocks.push(<blockquote key={i}>{inline(q.join(' '))}</blockquote>);
      continue;
    }
    const p: string[] = [];
    while (i < lines.length && lines[i].trim() && !/^(#|\||> |\d+\. |- )/.test(lines[i])) p.push(lines[i++]);
    blocks.push(<p key={i}>{inline(p.join(' '))}</p>);
  }
  return <div className="md">{blocks.map((b, k) => <Fragment key={k}>{b}</Fragment>)}</div>;
}
