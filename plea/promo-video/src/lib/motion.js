// Pure functions of time: every frame is computed from t alone, never from the previous frame.
export const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
export const mix = (a, b, k) => a + (b - a) * k;
export const ramp = (t, a, b) => clamp((t - a) / (b - a));

// Closed-form damped spring from 0 to 1 (stiffness k, damping d, unit mass).
export function spring(t, k = 170, d = 26) {
  if (t <= 0) return 0;
  const w0 = Math.sqrt(k), z = d / (2 * w0);
  if (z < 1) {
    const wd = w0 * Math.sqrt(1 - z * z);
    return 1 - Math.exp(-z * w0 * t) * (Math.cos(wd * t) + (z * w0 / wd) * Math.sin(wd * t));
  }
  return 1 - Math.exp(-w0 * t) * (1 + w0 * t);
}

// The style guide's springs: a hair of overshoot on UI, none on type.
export const SPRINGS = {
  snappy: [320, 30],   // buttons, pills, cursor
  ui: [170, 26],       // cards, panels
  heavy: [120, 22],    // big type, camera
  type: [140, 26],     // headlines: critically damped, no overshoot
  stamp: [420, 26],    // the stamp's landing
};
export const sp = (t, kind = 'ui') => spring(t, ...SPRINGS[kind]);

// A value with several targets: one spring per change, so motion stays continuous and seekable.
export function track(t, keys, kind = 'ui') {
  let v = keys[0][1];
  for (let i = 1; i < keys.length; i++) v += (keys[i][1] - keys[i - 1][1]) * sp(t - keys[i][0], kind);
  return v;
}

// Seeded noise (mulberry32): the same frame always renders the same.
export function rng(seed) {
  return () => {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let x = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    x = (x + Math.imul(x ^ (x >>> 7), 61 | x)) ^ x;
    return ((x ^ (x >>> 14)) >>> 0) / 4294967296;
  };
}

// The stamp lands: big and tilted, then down to its -3 degree rest. Returns the transform parts.
export function stampLand(t, { from = 1.7, tiltFrom = -14, tilt = -3 } = {}) {
  if (t < 0) return { visible: false, scale: from, rot: tiltFrom, shadow: 0 };
  const k = sp(t, 'stamp');
  const scale = mix(from, 1, k);
  return { visible: true, scale, rot: mix(tiltFrom, tilt, k), shadow: clamp((1.12 - scale) / 0.12) };
}

// A short camera jolt after an impact: a decaying shake, zero after ~0.15 s.
export function jolt(t, amp = 6) {
  if (t < 0 || t > 0.2) return 0;
  return amp * Math.exp(-t * 28) * Math.cos(t * 60);
}
