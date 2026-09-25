// Cloud geometry adapted from jeremy-prt/bloub, MIT. See NOTICE.md.
// CheckLine's five poses are independent design proposals, not the upstream timeline.
export const STATES = ['idle', 'received', 'processing', 'waiting', 'done'];
const TAU = Math.PI * 2;
const CIRCLES = [
  { x: -.44, y: .2, r: .54 }, { x: .46, y: .2, r: .5 },
  { x: .02, y: .3, r: .6 }, { x: -.24, y: -.3, r: .48 },
  { x: .3, y: -.24, r: .44 }
];
// Same 64 radial samples and 1.02 normalization as bloub's Cloud Shape.
const raw = Array.from({ length: 64 }, (_, i) => {
  const a = i / 64 * TAU, dx = Math.cos(a), dy = Math.sin(a);
  return Math.max(...CIRCLES.map(c => {
    const b = dx * c.x + dy * c.y;
    const disc = b * b - (c.x * c.x + c.y * c.y - c.r * c.r);
    return disc < 0 ? 0 : b + Math.sqrt(disc);
  }));
});
export const CLOUD = raw.map(r => r * 1.02 / Math.max(...raw));
const clamp = x => Math.max(0, Math.min(1, x));
const smooth = x => { const t = clamp(x); return t * t * (3 - 2 * t); };
const pulse = (t, start, end) => t <= start || t >= end ? 0 : Math.sin((t - start) / (end - start) * Math.PI) ** 2;
export const REST = Object.freeze({ sx: 1, sy: 1, lean: 0, lift: 0, lobe: 0, gazeX: 0, gazeY: 0, angle: -26, open: 1, smile: 0 });

export function pose(state, t, reduced = false) {
  const p = { ...REST };
  if (reduced) {
    if (state === 'received') { p.open = 1.14; p.angle = -10; }
    if (state === 'processing') { p.gazeX = -8; p.gazeY = -3; p.open = .78; }
    if (state === 'waiting') { p.gazeX = -7; p.angle = 0; }
    if (state === 'done') { p.open = .16; p.smile = 1; }
    return p;
  }
  if (state === 'idle') {
    // A short glance with a long quiet interval; the body does not bob forever.
    const q = t % 10;
    p.gazeX = -8 * (smooth((q - 3.1) / .5) - smooth((q - 5.2) / .65));
    p.gazeY = 2 * pulse(q, 3, 6);
    p.open = 1 - .94 * pulse(q, 1.1, 1.34) - .9 * pulse(q, 6.7, 6.94);
  } else if (state === 'received') {
    const press = pulse(t, .1, .4), stretch = pulse(t, .3, .92);
    p.sx += .09 * press - .055 * stretch;
    p.sy += -.105 * press + .085 * stretch;
    p.lift = -5 * stretch;
    p.gazeY = -4 * pulse(t, 0, 1.05);
    p.open = 1 + .22 * pulse(t, 0, .8);
    p.angle = -26 + 12 * pulse(t, 0, 1.1);
  } else if (state === 'processing') {
    const q = t % 4.8;
    const wave = Math.sin(TAU * q / 4.8);
    p.gazeX = -7 + 8 * Math.sin(TAU * (q + .22) / 4.8);
    p.gazeY = -3;
    p.lobe = .062 * wave;
    p.lean = .035 * Math.sin(TAU * (q - .12) / 4.8);
    p.open = .83 - .77 * pulse(q, 2.5, 2.74);
  } else if (state === 'waiting') {
    p.gazeX = -7;
    p.angle = 0;
    p.lean = -.075;
    p.open = 1 - .94 * pulse(t % 7, 5, 5.24);
  } else if (state === 'done') {
    const press = pulse(t, .06, .36), stretch = pulse(t, .25, .85), nod = pulse(t, .85, 1.45);
    p.sx += .06 * press - .065 * stretch;
    p.sy += -.07 * press + .11 * stretch - .025 * nod;
    p.lift = -7 * stretch + 3 * nod;
    p.gazeY = 4 * nod;
    p.smile = smooth(t / .2) * (1 - smooth((t - 1.35) / .45));
    p.open = 1 - .87 * p.smile;
    p.angle = -26 + 18 * p.smile;
  }
  return p;
}

export function mixPose(a, b, k) {
  const t = smooth(k);
  return Object.fromEntries(Object.keys(REST).map(key => [key, a[key] + (b[key] - a[key]) * t]));
}

export function bodyPoints(p) {
  return CLOUD.map((r, i) => {
    const a = i / 64 * TAU;
    // A local radial ripple changes the lobes themselves, not the whole SVG image.
    const rr = r * (1 + p.lobe * Math.cos(a * 2 + .4));
    const x = Math.cos(a) * rr * 78, y = Math.sin(a) * rr * 78;
    return { x: x * p.sx + p.lean * (y + 65), y: (y - 65) * p.sy + 65 + p.lift };
  });
}

// Closed Catmull-Rom path, using bloub's curve construction.
export function closedPath(points) {
  const n = points.length, f = x => Number(x.toFixed(3));
  let d = `M${f(points[0].x)} ${f(points[0].y)}`;
  for (let i = 0; i < n; i++) {
    const a = points[(i + n - 1) % n], b = points[i], c = points[(i + 1) % n], e = points[(i + 2) % n];
    d += `C${f(b.x + (c.x - a.x) / 6)} ${f(b.y + (c.y - a.y) / 6)} ${f(c.x - (e.x - b.x) / 6)} ${f(c.y - (e.y - b.y) / 6)} ${f(c.x)} ${f(c.y)}`;
  }
  return d + 'Z';
}

export function eyeLayout(p, index) {
  const x = (index ? 35 : 7) + p.gazeX;
  const y = -19 - (index ? 10 * Math.abs(p.angle) / 26 : 0) + p.gazeY;
  return { x: x * p.sx + p.lean * (y + 65), y: (y - 65) * p.sy + 65 + p.lift,
    angle: p.angle, w: 11.5 + 5 * p.smile, h: Math.max(2.4, 27 * p.open) };
}

export class CloudPlayer {
  constructor() { this.state = 'idle'; this.elapsed = 0; this.transition = 1; this.from = { ...REST }; this.current = { ...REST }; this.reduced = false; }
  select(state) {
    if (!STATES.includes(state)) throw new Error('Unknown cloud state');
    this.from = { ...this.current }; this.state = state; this.elapsed = 0; this.transition = 0;
    if (this.reduced) { this.transition = 1; this.current = pose(state, 0, true); }
  }
  setReduced(value) {
    this.reduced = value; this.elapsed = 0; this.transition = 1;
    this.current = pose(this.state, 0, value);
  }
  advance(dt) {
    this.elapsed += dt;
    this.transition = Math.min(1, this.transition + dt / .32);
    const target = pose(this.state, this.elapsed, this.reduced);
    this.current = this.reduced ? target : mixPose(this.from, target, this.transition);
    return this.current;
  }
}

export function createCloud(svg) {
  const ns = 'http://www.w3.org/2000/svg';
  svg.setAttribute('viewBox', '-120 -112 240 224');
  svg.setAttribute('aria-hidden', 'true');
  const body = document.createElementNS(ns, 'path'); body.setAttribute('fill', 'var(--cloud)'); svg.append(body);
  const eyes = [0, 1].map(() => {
    const g = document.createElementNS(ns, 'g'), rect = document.createElementNS(ns, 'rect'), arc = document.createElementNS(ns, 'path');
    rect.setAttribute('fill', 'var(--eyes)'); arc.setAttribute('fill', 'none'); arc.setAttribute('stroke', 'var(--eyes)');
    arc.setAttribute('stroke-width', '4'); arc.setAttribute('stroke-linecap', 'round');
    g.append(rect, arc); svg.append(g); return { g, rect, arc };
  });
  return p => {
    body.setAttribute('d', closedPath(bodyPoints(p)));
    eyes.forEach((e, i) => {
      const q = eyeLayout(p, i);
      e.g.setAttribute('transform', `translate(${q.x} ${q.y}) rotate(${q.angle})`);
      for (const [k, v] of Object.entries({ x: -q.w / 2, y: -q.h / 2, width: q.w, height: q.h, rx: Math.min(q.w, q.h) / 2, opacity: 1 - p.smile })) e.rect.setAttribute(k, String(v));
      e.arc.setAttribute('d', `M${-q.w / 2} 2 Q0 -7 ${q.w / 2} 2`); e.arc.setAttribute('opacity', String(p.smile));
    });
  };
}
