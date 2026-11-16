/* Organic period light: text remains the accessible source of truth. */
(function () {
  'use strict';
  const TAU = Math.PI * 2;
  const clamp = value => Math.max(0, Math.min(1, value));
  const smooth = value => { const t = clamp(value); return t * t * (3 - 2 * t); };

  function create(container, options = {}) {
    const reduced = !!options.reduced || (window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
    const dark = !!options.dark;
    const root = document.createElement('div');
    root.className = 'cll-orb';
    root.dataset.dark = String(dark);
    root.dataset.renderer = dark ? 'organic-clear-core' : 'fine-light';
    root.innerHTML = '<div class="cll-orb__ring"><canvas class="cll-orb__canvas" aria-hidden="true"></canvas><div class="cll-orb__center" aria-hidden="true"><span class="cll-orb__label"></span><div class="cll-orb__main"><span class="cll-orb__value"></span><span class="cll-orb__unit"></span></div></div></div><div class="cll-orb__date" aria-hidden="true"></div><span class="cll-orb__sr" role="status" aria-live="polite" aria-atomic="true"></span>';
    container.appendChild(root);
    const canvas = root.querySelector('canvas');
    const ctx = canvas.getContext('2d');
    const label = root.querySelector('.cll-orb__label');
    const value = root.querySelector('.cll-orb__value');
    const unit = root.querySelector('.cll-orb__unit');
    const date = root.querySelector('.cll-orb__date');
    const live = root.querySelector('.cll-orb__sr');
    // A fixed seed keeps the same constellation through card changes and
    // re-entry. Minimum spacing prevents clumps without introducing rows.
    let seed = 713193;
    const random = () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; };
    const lights = [];
    for (let attempt = 0; lights.length < 88 && attempt < 5000; attempt++) {
      const position = random(), angle = position * TAU - Math.PI / 2;
      const across = (random() * 2 - 1) * (.74 + .26 * Math.sin(angle * 3 + .8));
      const radius = .361 + across * .063 + Math.sin(angle * 3 + .6) * .009;
      const x = Math.cos(angle) * radius, y = Math.sin(angle) * radius;
      if (lights.some(p => Math.hypot(p.x - x, p.y - y) < .025)) continue;
      lights.push({ position, angle, radius, x, y, size: .62 + random() * .92, depth: random(), phase: random() * TAU, faint: false });
    }
    // A few quiet distant points provide depth; they never turn into a second
    // dense lattice or a field of identically bright dots.
    for (let i = 0; i < 28; i++) {
      const position = random(), angle = position * TAU - Math.PI / 2;
      lights.push({ position, angle, radius: .36 + (random() - .5) * .16, size: .35 + random() * .35, depth: random() * .5, phase: random() * TAU, faint: true });
    }
    // Light appearance returns to the original fine-grain shell. Its seed
    // and rendering are independent, so the existing dark field stays intact.
    const grainHash = n => { const x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); };
    const grains = dark ? [] : Array.from({ length: 800 }, (_, i) => ({
      angle: (i + grainHash(i + 1)) / 800 * TAU,
      radial: i % 4 === 0 ? -.09 - grainHash(i + 47) * .13 : (grainHash(i + 19) + grainHash(i + 47) + grainHash(i + 83) - 1.5) * .14,
      rear: i % 4 === 0,
      depth: grainHash(i + 131),
      size: .38 + Math.pow(grainHash(i + 251), 2) * .52,
      phase: grainHash(i + 419) * TAU,
      accent: false
    }));
    const accents = [];
    for (const grain of [...grains].filter(p => !p.rear && Math.abs(p.radial) < .09).sort((a, b) => b.depth - a.depth)) {
      if (accents.length === 12) break;
      if (accents.some(p => Math.min(Math.abs(p.angle - grain.angle), TAU - Math.abs(p.angle - grain.angle)) < .32)) continue;
      grain.accent = true;
      accents.push(grain);
    }
    let model = null, displayed = 0, target = null, known = 0, targetKnown = 0;
    let lastTime = 0, elapsed = 0, changeTime = -1000;
    let paused = false, visible = true, destroyed = false, frame = 0, width = 0;
    let resizeObserver, intersectionObserver;

    function resize() {
      if (destroyed) return;
      const size = Math.max(1, canvas.getBoundingClientRect().width);
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      width = size;
      canvas.width = Math.round(size * dpr);
      canvas.height = Math.round(size * dpr);
      if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      draw();
    }
    function drawFineLight() {
      const cx = width / 2, cy = width / 2, scale = width / 208;
      const clock = reduced ? 0 : elapsed;
      const breathing = reduced ? 1 : 1 + Math.sin(clock * .00028) * .009;
      const change = reduced ? 1 : clamp((elapsed - changeTime) / 720);
      const projected = grains.map(point => {
        const angle = point.angle + (reduced ? 0 : Math.sin(clock * .00022 + point.phase) * .014);
        const ripple = reduced ? 0 : Math.sin(point.angle * 3 - clock * .00055) * .008;
        const radial = width * .394 * (1 + point.radial + ripple) * breathing;
        const x = cx + Math.cos(angle) * radial;
        const y = cy + Math.sin(angle) * radial * .91 + Math.cos(angle) * radial * .045;
        const position = ((point.angle + Math.PI / 2 + TAU) % TAU) / TAU;
        const lit = known * smooth((displayed - position) * 32 + .5);
        const shimmer = reduced ? 1 : .86 + .14 * Math.sin(clock * .00072 + point.phase);
        const passage = Math.sin(change * Math.PI) * Math.max(0, 1 - Math.abs(position / Math.max(.03, displayed) - change) * 5);
        const alpha = (.42 + lit * .44) * shimmer * (.65 + .35 * point.depth) * (point.rear ? .43 : 1);
        return { ...point, x, y, lit, alpha, radius: point.size * scale, shine: lit * (reduced ? .85 : .66 + .34 * Math.pow(.5 + .5 * Math.sin(clock * .0009 + point.phase), 2)) * (1 + passage * .2) };
      });
      ctx.globalCompositeOperation = 'source-over';
      // Sparse, local glows: most of the ring is unblurred fine grain.
      for (const point of projected) {
        if (!point.accent || point.shine < .002) continue;
        const { x, y, shine } = point, r = (5.5 + point.depth * 1.5) * scale;
        const halo = ctx.createRadialGradient(x, y, 0, x, y, r);
        halo.addColorStop(0, `rgba(115,181,209,${shine * .52})`);
        halo.addColorStop(.28, `rgba(115,181,209,${shine * .26})`);
        halo.addColorStop(.60, `rgba(132,191,214,${shine * .09})`);
        halo.addColorStop(1, 'rgba(150,202,220,0)');
        ctx.fillStyle = halo;
        ctx.fillRect(x - r, y - r, r * 2, r * 2);
      }
      for (const point of projected) {
        const r = Math.round(109 - point.lit * 63), g = Math.round(131 - point.lit * 12), b = Math.round(143 + point.lit * 7);
        ctx.fillStyle = `rgba(${r},${g},${b},${point.alpha})`;
        ctx.beginPath();ctx.arc(point.x, point.y, point.radius, 0, TAU);ctx.fill();
      }
      for (const point of projected) {
        if (!point.accent || point.shine < .002) continue;
        const { x, y, shine } = point, r = (1.06 + point.depth * .25) * scale;
        const core = ctx.createRadialGradient(x, y, 0, x, y, r);
        core.addColorStop(0, `rgba(70,147,177,${clamp(shine * 1.15)})`);
        core.addColorStop(.62, `rgba(104,175,198,${clamp(shine)})`);
        core.addColorStop(1, 'rgba(146,198,216,0)');
        ctx.fillStyle = core;ctx.fillRect(x - r, y - r, r * 2, r * 2);
      }
    }
    function draw() {
      if (!ctx || !width || destroyed) return;
      ctx.clearRect(0, 0, width, width);
      if (!dark) { drawFineLight(); return; }
      const cx = width / 2, cy = width / 2, scale = width / 208;
      const clock = reduced ? 0 : elapsed;
      const change = reduced ? 1 : clamp((elapsed - changeTime) / 720);
      const projected = lights.map(light => {
        const drift = Math.sin(clock * .00042 + light.phase);
        const angle = light.angle + Math.sin(clock * .00027 + light.phase) * .012;
        const radius = light.radius * width + drift * .85 * scale;
        const x = cx + Math.cos(angle) * radius;
        const y = cy + Math.sin(angle) * radius * .98;
        const lit = known * smooth((displayed - light.position) * 32 + .5);
        const passage = Math.sin(change * Math.PI) * Math.max(0, 1 - Math.abs(light.position / Math.max(.03, displayed) - change) * 5);
        const breathe = reduced ? 1 : .85 + .15 * Math.sin(clock * .00085 + light.phase);
        const strength = lit * breathe * (light.faint ? .35 : .75 + light.depth * .25) * (1 + passage * .16);
        const core = (light.faint ? .8 : 1.72) * light.size * scale;
        return { x, y, lit, strength, core, base: (.5 + light.size * .36) * scale, depth: light.depth, faint: light.faint };
      }).sort((a, b) => a.depth - b.depth);
      for (const point of projected) {
        // Dim points fade out under a lit point; no hard disk sits beneath
        // the bloom and no dark rim creates the appearance of a hollow bead.
        const alpha = (dark ? .40 : .32) * (point.faint ? .44 : .65 + point.depth * .35) * (1 - point.lit);
        const r = point.base * (1.25 + (1 - known) * .24);
        const dot = ctx.createRadialGradient(point.x, point.y, 0, point.x, point.y, r);
        const rgb = dark ? '167,190,209' : '71,115,144';
        dot.addColorStop(0, `rgba(${rgb},${alpha})`);
        dot.addColorStop(.45, `rgba(${rgb},${alpha * .8})`);
        dot.addColorStop(1, `rgba(${rgb},0)`);
        ctx.fillStyle = dot;
        ctx.fillRect(point.x - r, point.y - r, r * 2, r * 2);
      }
      ctx.globalCompositeOperation = dark ? 'screen' : 'source-over';
      for (const point of projected) {
        if (point.lit < .002) continue;
        const { x, y, strength } = point;
        const r = Math.min((point.faint ? 6 : 12 + point.depth * 3) * scale, x - 1, y - 1, width - x - 1, width - y - 1);
        const halo = ctx.createRadialGradient(x, y, 0, x, y, r);
        const rgb = dark ? '104,158,255' : '48,140,213';
        halo.addColorStop(0, `rgba(${rgb},${strength * (dark ? .82 : .38)})`);
        halo.addColorStop(.22, `rgba(${rgb},${strength * (dark ? .50 : .20)})`);
        halo.addColorStop(.48, `rgba(${rgb},${strength * (dark ? .22 : .075)})`);
        halo.addColorStop(.75, `rgba(${rgb},${strength * (dark ? .065 : .026)})`);
        halo.addColorStop(1, `rgba(${rgb},0)`);
        ctx.fillStyle = halo;
        ctx.fillRect(x - r, y - r, r * 2, r * 2);
      }
      // Finish every halo before drawing any core. Nearby halos must never
      // wash over an already rendered point, especially on a light surface.
      ctx.globalCompositeOperation = 'source-over';
      for (const point of projected) {
        if (point.lit < .002) continue;
        const { x, y, core } = point;
        const opacity = clamp(point.strength * (point.faint ? 1 : 1.22));
        const r = core * 1.10;
        const glow = ctx.createRadialGradient(x, y, 0, x, y, r);
        if (dark) {
          glow.addColorStop(0, `rgba(255,255,255,${opacity})`);
          glow.addColorStop(.58, `rgba(247,252,255,${opacity})`);
          glow.addColorStop(.78, `rgba(221,239,255,${opacity * .88})`);
          glow.addColorStop(1, 'rgba(156,202,255,0)');
        } else {
          // A small solid blue centre and a narrow feathered edge: no white
          // pinhole, dark outline, or broad inner blur.
          glow.addColorStop(0, `rgba(36,117,172,${opacity})`);
          glow.addColorStop(.58, `rgba(40,126,179,${opacity})`);
          glow.addColorStop(.78, `rgba(65,150,201,${opacity * .86})`);
          glow.addColorStop(1, 'rgba(102,180,225,0)');
        }
        ctx.fillStyle = glow;
        ctx.fillRect(x - r, y - r, r * 2, r * 2);
      }
      ctx.globalCompositeOperation = 'source-over';
    }
    function canAnimate() { return !destroyed && !reduced && !paused && visible && !document.hidden; }
    function tick(time) {
      frame = 0;
      if (!canAnimate()) { lastTime = 0; return; }
      const delta = lastTime ? Math.min(time - lastTime, 50) : 0;
      lastTime = time;
      elapsed += delta;
      if (target !== null) {
        displayed += (target - displayed) * (1 - Math.exp(-delta / 180));
        if (Math.abs(target - displayed) < .001) displayed = target;
      }
      known += (targetKnown - known) * (1 - Math.exp(-delta / 160));
      if (Math.abs(targetKnown - known) < .001) known = targetKnown;
      draw();
      frame = requestAnimationFrame(tick);
    }
    function reconcile() {
      if (canAnimate()) { if (!frame) frame = requestAnimationFrame(tick); }
      else { if (frame) cancelAnimationFrame(frame); frame = 0; lastTime = 0; draw(); }
    }
    function update(next, { immediate = false } = {}) {
      if (destroyed || !next) return;
      const first = model === null;
      if (!first && model.ariaLabel !== next.ariaLabel && !reduced) changeTime = elapsed;
      model = next;
      root.dataset.state = next.state || 'active';
      label.textContent = next.label || '';
      label.hidden = !next.label;
      value.textContent = next.value || '';
      unit.textContent = next.unit || '';
      date.textContent = next.dateText || '';
      live.textContent = next.ariaLabel || [next.label, next.value, next.unit, next.dateText].filter(Boolean).join(' ');
      target = next.remaining == null || !Number.isFinite(Number(next.remaining)) ? null : clamp(Number(next.remaining));
      targetKnown = target === null ? 0 : 1;
      if (first || immediate || reduced || !canAnimate()) { if (target !== null) displayed = target; known = targetKnown; }
      draw();
      reconcile();
    }
    function onVisibility() { reconcile(); }
    document.addEventListener('visibilitychange', onVisibility);
    if (window.ResizeObserver) { resizeObserver = new ResizeObserver(resize); resizeObserver.observe(root); }
    else window.addEventListener('resize', resize);
    if (window.IntersectionObserver) {
      intersectionObserver = new IntersectionObserver(entries => { visible = entries[0].isIntersecting; reconcile(); });
      intersectionObserver.observe(root);
    }
    resize();
    reconcile();
    return {
      update,
      setReturnProgress(progress) {
        const p = clamp(Number(progress) || 0);
        root.style.setProperty('--cll-orb-return-opacity', String(1 - p));
        root.style.setProperty('--cll-orb-return-scale', String(1 - .08 * p));
      },
      setPaused(value) { paused = !!value; reconcile(); },
      destroy() {
        destroyed = true;
        if (frame) cancelAnimationFrame(frame);
        document.removeEventListener('visibilitychange', onVisibility);
        if (resizeObserver) resizeObserver.disconnect(); else window.removeEventListener('resize', resize);
        if (intersectionObserver) intersectionObserver.disconnect();
        root.remove();
      }
    };
  }
  window.CheckLinePeriodOrb = { create };
})();
