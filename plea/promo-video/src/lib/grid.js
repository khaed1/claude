// The music's beat grid (data/beats-16x9.json): bar n's downbeat in video seconds, and beats.
let G = null;
export async function loadGrid(url) {
  G = await (await fetch(url)).json();
  return G;
}
export const BAR = (n) => {
  const d = G.downbeats;
  if (n < 0) return d[0] + n * barLen();
  if (n < d.length) return d[n];
  return d[d.length - 1] + (n - d.length + 1) * barLen();
};
export const barLen = () => 60 / G.bpm * 4;
export const beatLen = () => 60 / G.bpm;
// Beat b after bar n's downbeat (fractions allowed: 0.5 = an eighth note).
export const AT = (n, b = 0) => BAR(n) + b * beatLen();
