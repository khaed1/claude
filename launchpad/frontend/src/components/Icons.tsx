// One drawn icon set (24px grid, filled, currentColor). No emoji or glyphs as icons (brand book).
const P = {
  home: 'M12 3 2 12h3v8h5v-5h4v5h5v-8h3z',
  coin: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 4a6 6 0 1 1 0 12 6 6 0 0 1 0-12z',
  plus: 'M11 5h2v6h6v2h-6v6h-2v-6H5v-2h6z',
  pond: 'M2 14q5-5 10 0t10 0v6H2z M7 8a3 3 0 1 1 6 0 3 3 0 0 1-6 0z',
  user: 'M12 3a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9zM3 21a9 9 0 0 1 18 0z',
  search: 'M10 3a7 7 0 0 1 5.6 11.2l5.1 5.1-1.4 1.4-5.1-5.1A7 7 0 1 1 10 3zm0 2a5 5 0 1 0 0 10 5 5 0 0 0 0-10z',
  clock: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 10.4 3.6 2.1-1 1.7-4.6-2.7V6h2z',
  chorus: 'M7 5a3 3 0 1 1 0 6 3 3 0 0 1 0-6zm10 0a3 3 0 1 1 0 6 3 3 0 0 1 0-6zM2 20c0-4 3-7 10-7s10 3 10 7z',
  alert: 'M12 2 1 21h22zm1 15h-2v-2h2zm0-4h-2V9h2z',
  info: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-6h2zm0-8h-2V7h2z',
  leap: 'M3 20q4-14 18-16-3 3-4 7l3 1-5 2q-3 6-12 6z',
  x: 'M17.8 3h3.1l-6.8 7.8 8 10.2h-6.3l-4.9-6.4L5.3 21H2.2l7.3-8.3L1.8 3h6.4l4.4 5.9zm-1.1 16.2h1.7L7.4 4.7H5.6z',
  web: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm6.9 6h-3a15 15 0 0 0-1.3-3.9A8 8 0 0 1 18.9 8zM12 4c.8 1.1 1.5 2.5 1.9 4h-3.8c.4-1.5 1.1-2.9 1.9-4zM4.3 14a8 8 0 0 1 0-4h3.4a16 16 0 0 0 0 4zm.8 2h3a15 15 0 0 0 1.3 3.9A8 8 0 0 1 5.1 16zm3-8h-3a8 8 0 0 1 4.3-3.9A15 15 0 0 0 8.1 8zM12 20c-.8-1.1-1.5-2.5-1.9-4h3.8c-.4 1.5-1.1 2.9-1.9 4zm2.3-6H9.7a14 14 0 0 1 0-4h4.6a14 14 0 0 1 0 4zm.3 5.9c.6-1.2 1-2.5 1.3-3.9h3a8 8 0 0 1-4.3 3.9zm1.7-5.9a16 16 0 0 0 0-4h3.4a8 8 0 0 1 0 4z',
  copy: 'M8 3h11a2 2 0 0 1 2 2v11h-2V5H8zM4 7h11a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2z',
  ext: 'M14 3h7v7h-2V6.4l-8.3 8.3-1.4-1.4L17.6 5H14zM5 5h6v2H5v12h12v-6h2v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2z',
  book: 'M4 3h7a3 3 0 0 1 2 1 3 3 0 0 1 2-1h7v16h-7a2 2 0 0 0-2 2 2 2 0 0 0-2-2H4z',
} as const;

export type IconName = keyof typeof P;
export function Icon({ name, size = 18, className = 'pp-ico', label }: { name: IconName; size?: number; className?: string; label?: string }) {
  return (
    <svg className={className} viewBox="0 0 24 24" width={size} height={size} aria-hidden={label ? undefined : true} role={label ? 'img' : undefined} aria-label={label}>
      <path d={P[name]} fillRule="evenodd" />
    </svg>
  );
}

export function LilyMark({ size = 30 }: { size?: number }) {
  return (
    <svg viewBox="0 0 96 96" width={size} height={size} aria-hidden="true">
      <path fill="var(--lily)" d="M50 46L71.95 20.39A42 36 0 1 1 61.58 15.40Z" />
    </svg>
  );
}
