// A music edit's beat grid (data/beats-*.json): bar n's downbeat in seconds, and beats.
export function makeGrid(G) {
  const barLen = () => 60 / G.bpm * 4;
  const beatLen = () => 60 / G.bpm;
  const BAR = (n) => {
    const d = G.downbeats;
    if (n < 0) return d[0] + n * barLen();
    if (n < d.length) return d[n];
    return d[d.length - 1] + (n - d.length + 1) * barLen();
  };
  // Beat b after bar n's downbeat (fractions allowed: 0.5 = an eighth note).
  const AT = (n, b = 0) => BAR(n) + b * beatLen();
  return { BAR, AT, barLen, beatLen };
}
