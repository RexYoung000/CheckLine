function installCardLibraryStudy() {
  'use strict';
  app.dataset.libraryStudy = 'period-return';
  const params = new URL(location.href).searchParams;
  const legacy = window.CheckLineLibrary;
  const originalOpen = readerLibrary;
  const originalTheme = setTheme;
  const originalReduced = setReduced;
  const originalSettle = readerSettle;
  const originalFace = cartridgeFace;
  const originalBudgetRoot = budgetRoot;
  const clamp = (value, low = 0, high = 1) => Math.min(high, Math.max(low, value));
  const lerp = (a, b, t) => a + (b - a) * t;
  const state = { controller: null, transport: null, homeRect: null, commits: 0, focused: null, mode: 'arc', frame: 0 };
  const scenario = params.get('sample') || 'normal';

  function applyFixture() {
    const c = cardById('month');
    const trip = cardById('trip');
    // The prototype clock and dates remain local. No real ledger is accessed.
    trip.start = shiftDay(today(), -2); trip.end = shiftDay(today(), 3);
    const setUsed = (confirmed, pending = 0) => {
      data.expenses = data.expenses.filter(e => e.budgetId !== c.id);
      [[confirmed, 'confirmed'], [pending, 'pending']].forEach(([amount, status], i) => {
        if (amount) data.expenses.push({ id: 'library-fixture-' + i, merchant: i ? '待确认消费' : '本期消费', amount, budgetAmount: amount, currency: c.currency, date: today(), periodStart: c.start, budgetId: c.id, status, source: '样稿' });
      });
    };
    if (scenario === 'single') data.cards = [c];
    if (scenario === 'empty') { data.cards = []; data.expenses = []; data.selected = null; }
    if (scenario === 'many') {
      const names = ['日常餐饮', '通勤出行', '家居添置', '运动计划', '旅行准备', '阅读与学习', '朋友聚会', '咖啡时间', '数码计划'];
      data.cards.push(...names.map((name, i) => ({ ...c, id: 'sample-' + i, name, limit: (i + 5) * 10000, start: shiftDay(today(), -i - 2), end: shiftDay(today(), i + 4) })));
    }
    if (scenario === 'long') { c.name = '和家人一起出发的年度长途旅行预算'; c.limit = 12345678900; c.currency = 'USD'; }
    if (scenario === 'over') setUsed(c.limit + 42000);
    if (scenario === 'pending-over') setUsed(c.limit - 10000, 28000);
    if (scenario === 'pending') setUsed(98000, 24000);
    if (scenario === 'zero') setUsed(c.limit);
    if (scenario === 'full') setUsed(0);
    if (scenario === 'upcoming') { c.start = shiftDay(today(), 5); c.end = shiftDay(c.start, 29); setUsed(0); }
    if (scenario === 'due') c.end = shiftDay(today(), -1);
    if (scenario === 'no-deadline') { c.kind = 'once'; c.end = null; }
  }
  applyFixture();
  cartridgeFace = function (card) {
    // Share the glass shell; retain the home's live water and insertion splash.
    return originalFace(card).replace(/(<div class="liquid-card reader-card-face"[^>]*>)/, '$1<div class="cll-home-optics">' + window.CheckLineLibraryCard.optics({ ...cardModel(card), fill: 0 }) + '</div>');
  };
  budgetRoot = function () {
    if (data.cards.length) return originalBudgetRoot();
    return `<section class="cartridge-home"><header class="page-head budget-home-head"><h2>预算</h2>${ib('add','创建预算卡','new-budget')}${ib('settings','设置','settings')}</header><div class="cartridge-world${reader.library ? ' library-open' : ''}">${cartridgeLibrary()}<div class="cll-home-empty"><p class="cll-empty"><strong>还没有预算卡</strong>创建一张，为在意的支出设条线。</p><button data-action="new-budget">创建预算卡</button></div></div></section>`;
  };

  function cardModel(c) {
    const t = totals(c), upcoming = c.start > today();
    const amount = upcoming ? c.limit : t.remaining;
    const risk = t.confirmed > c.limit ? '已越线' : t.remaining < 0 ? '可能越线' : '';
    return {
      id: c.id, name: c.name, currency: c.currency,
      mainLabel: upcoming ? '待开始 · 预算额度' : risk || '还能花',
      amountText: (amount < 0 ? '−' : '') + money(Math.abs(amount), c.currency),
      usedText: '已用 ' + money(t.used, c.currency),
      pendingText: t.pending.length ? '其中待确认 ' + money(t.pendingAmount, c.currency) : '',
      riskText: risk, upcoming,
      fill: upcoming ? 0 : clamp(t.remaining / c.limit),
      period: periodModel(c),
    };
  }
  function periodModel(c) {
    const day = value => { const d = localDate(value); return Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()); };
    const days = value => Math.round((day(value) - day(today())) / 86400000);
    const dateText = c.end ? rangeLabel(c.start, c.end) : '一次性 · 未设截止日期';
    let model;
    if (c.start > today()) model = { label: '距离开始', value: String(days(c.start)), unit: '天', state: 'upcoming', remaining: null };
    else if (!c.end) model = { label: '本次预算', value: '进行中', unit: '', state: 'open', remaining: null };
    else if (c.end < today()) model = { label: '本期已结束', value: '待结算', unit: '', state: 'due', remaining: 0 };
    else model = { label: days(c.end) ? '本期还剩' : '本期', value: days(c.end) ? String(days(c.end)) : '今天结束', unit: days(c.end) ? '天' : '', state: 'active', remaining: clamp((days(c.end) + 1) / Math.max(1, (day(c.end) - day(c.start)) / 86400000 + 1)) };
    return { ...model, dateText, ariaLabel: [c.name, model.label, model.value, model.unit, dateText].join('，') };
  }
  function readHomeRect() {
    const world = $('.cartridge-world', page), face = $('.cartridge-card .reader-card-face', page);
    if (!world || !face) return null;
    const library = world.classList.contains('library-open');
    // Read the landing layout within this task, restoring the class before paint.
    // This also refreshes a gallery left open across rotation/window resizing.
    if (library) world.classList.remove('library-open');
    const box = world.getBoundingClientRect(), r = face.getBoundingClientRect(), scale = box.width / world.clientWidth;
    const result = { x: (r.x - box.x) / scale, y: (r.y - box.y) / scale, w: r.width / scale, h: r.height / scale, worldTop: box.y };
    if (library) world.classList.add('library-open');
    return result;
  }
  function sourceRect(node) {
    return (node?.querySelector('.cll-card') || node)?.getBoundingClientRect();
  }
  function paintTransport(dy, settling = null) {
    const t = state.transport;
    if (!t) return;
    t.dy = Math.max(0, dy);
    let progress = clamp(t.dy / 230, 0, .48);
    let pose = { ...t.source, y: t.source.y + t.dy * .42, w: t.source.w * (1 - progress * .055), h: t.source.h * (1 + progress * .055) };
    pose.x = t.source.x + (t.source.w - pose.w) / 2;
    if (settling !== null) {
      progress = lerp(t.startProgress, 1, settling);
      pose = Object.fromEntries(['x', 'y', 'w', 'h'].map(key => [key, lerp(t.startPose[key], t.target[key], settling)]));
    }
    t.progress = progress; t.pose = pose;
    Object.assign(t.ghost.style, { left: pose.x + 'px', top: pose.y + 'px', width: pose.w + 'px', height: pose.h + 'px', transform: 'perspective(900px) rotateX(' + (settling === null ? -progress * 5 : -t.startProgress * 5 * (1 - settling)) + 'deg)' });
    t.unit.style.setProperty('transform', `translateY(${t.shift * (1 - progress)}px)`, 'important');
    t.world.style.setProperty('--cll-holder-return', settling === null ? 0 : clamp((settling - .46) / .36));
    t.world.style.setProperty('--reader-library-return', progress);
    t.world.classList.add('cll-transporting', 'library-drag-return');
    state.controller?.paintReturn(progress, t.id);
    const blend = settling === null ? 0 : clamp((settling - .38) / .60);
    t.ghost.querySelector('.cll-flight-from').style.opacity = 1 - blend;
    t.ghost.querySelector('.cll-flight-to').style.opacity = blend;
    t.world.dataset.returnProgress = progress.toFixed(3);
  }
  function beginTransport(id, rect) {
    if (state.transport) { cancelAnimationFrame(state.frame); state.frame = 0; return true; }
    const c = cardById(id), world = $('.cartridge-world', page), unit = $('.machine-unit', page);
    if (!c || !world || !unit || !rect || !rect.width) return false;
    const box = world.getBoundingClientRect(), scale = box.width / world.clientWidth;
    const source = { x: (rect.x - box.x) / scale, y: (rect.y - box.y) / scale, w: rect.width / scale, h: rect.height / scale };
    const target = { ...(state.homeRect || { x: 34, y: 70, w: world.clientWidth - 68, h: (world.clientWidth - 68) * .82 }) };
    if (target.worldTop !== undefined) target.y += (target.worldTop - box.y) / scale;
    // The final 180 ms insertion is owned by the existing home feedback.
    target.y -= READER_SEAT_Y + 18;
    const ghost = document.createElement('div');
    ghost.className = 'cll-flight'; ghost.inert = true; ghost.setAttribute('aria-hidden', 'true');
    ghost.innerHTML = '<div class="cll-flight-from">' + window.CheckLineLibraryCard.markup(cardModel(c)) + '</div><div class="cll-flight-to">' + cartridgeFace(c) + '</div>';
    world.appendChild(ghost);
    const shift = new DOMMatrix(getComputedStyle(unit).transform).m42;
    state.transport = { id, world, unit, ghost, source, target, shift, dy: 0, progress: 0, oldTransform: unit.style.transform, oldPriority: unit.style.getPropertyPriority('transform'), settling: false };
    paintTransport(0);
    return true;
  }
  function clearTransport() {
    cancelAnimationFrame(state.frame); state.frame = 0;
    const t = state.transport; if (!t) return;
    state.transport = null;
    for (const animation of t.animations || []) animation.cancel();
    t.ghost.remove();
    t.world.classList.remove('cll-transporting', 'library-drag-return');
    t.world.style.removeProperty('--reader-library-return'); delete t.world.dataset.returnProgress;
    t.world.style.removeProperty('--cll-holder-return');
    if (t.oldTransform) t.unit.style.setProperty('transform', t.oldTransform, t.oldPriority); else t.unit.style.removeProperty('transform');
    state.controller?.paintReturn(0, null);
  }
  function cancelTransport(immediate = false) {
    const t = state.transport; if (!t) return;
    cancelAnimationFrame(state.frame); state.frame = 0;
    if (immediate || reducedMotion()) { clearTransport(); return; }
    const from = t.dy, start = performance.now(); t.settling = false;
    const step = time => {
      if (state.transport !== t) return;
      const p = clamp((time - start) / 190), e = 1 - Math.pow(1 - p, 3);
      paintTransport(from * (1 - e));
      if (p < 1) state.frame = requestAnimationFrame(step); else clearTransport();
    };
    state.frame = requestAnimationFrame(step);
  }
  function completeSelection(id) {
    const c = cardById(id); if (!c) { cancelTransport(true); return; }
    const controller = state.controller;
    clearTransport();
    controller?.destroy(); state.controller = null;
    readerCancel(); reader.library = false; reader.drag = null; reader.active = null;
    reader.staged = id; reader.knownSelection = id; reader.phase = 'unplugged';
    data.selected = id; state.commits += 1; persist();
    page.classList.remove('reader-library-open');
    readerRender();
    readerInsert().then(() => {
      if (!reader.library && reader.staged === id) $('.card-open-zone', page)?.focus({ preventScroll: true });
    });
  }
  function finishTransport(id, rect) {
    if (state.transport?.settling) return;
    if (!beginTransport(id, rect)) { completeSelection(id); return; }
    const t = state.transport;
    if (t.settling) return;
    cancelAnimationFrame(state.frame); t.settling = true;
    t.startPose = { ...t.pose }; t.startProgress = t.progress;
    if (reducedMotion()) { completeSelection(id); return; }
    const duration = 360;
    const options = { duration, easing: 'cubic-bezier(.32,0,.2,1)', fill: 'both' };
    t.animations = [];
    const animate = (node, frames, extra = {}) => {
      if (!node) return null;
      const animation = node.animate(frames, { ...options, ...extra }); t.animations.push(animation); return animation;
    };
    // The browser owns the return timeline; resizing the optical surface also
    // keeps text sharp instead of scaling a rasterized card layer.
    t.ghost.style.transformOrigin = '0 0';
    t.animation = animate(t.ghost, [
      { left:t.pose.x+'px',top:t.pose.y+'px',width:t.pose.w+'px',height:t.pose.h+'px',transform:'none' },
      { left:t.target.x+'px',top:t.target.y+'px',width:t.target.w+'px',height:t.target.h+'px',transform:'none' }
    ]);
    animate(t.ghost.querySelector('.cll-flight-from'), [{ opacity: 1 }, { opacity: 1, offset: .36 }, { opacity: 0 }]);
    animate(t.ghost.querySelector('.cll-flight-to'), [{ opacity: 0 }, { opacity: 0, offset: .36 }, { opacity: 1 }]);
    const unitFrom = getComputedStyle(t.unit).transform;
    t.unit.style.setProperty('transform', unitFrom);
    animate(t.unit, [{ transform: unitFrom }, { transform: 'translateY(0px)' }]);
    animate(t.world, [{ '--cll-holder-return': '0' }, { '--cll-holder-return': '0', offset: .46 }, { '--cll-holder-return': '1', offset: .82 }, { '--cll-holder-return': '1' }]);
    animate($('.cll-library', page), [{ opacity: 1 }, { opacity: 0 }], { duration: 240 });
    t.animation.finished.then(() => { if (state.transport === t) completeSelection(id); }).catch(() => {});
  }

  function createLibrary(root, props) {
    const cards = props.cards;
    const selected = Math.max(0, cards.findIndex(c => c.id === props.selectedId));
    const ordered = cards.length ? [cards[selected], ...cards.filter((_, i) => i !== selected)] : [];
    let position = 0, mode = 'arc', orb, pointer = null, motion = 0, destroyed = false, lastClick = 0, stage, arc, period, status, search = '';
    const signal = new AbortController();
    const glyph = (paths) => `<svg viewBox="0 0 24 24" aria-hidden="true">${paths}</svg>`;
    const layoutIcon = glyph('<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>');
    root.innerHTML = `<section class="cll-library" data-mode="arc" aria-label="预算卡库"><header class="cll-header"><div class="cll-controls"><button class="cll-layout" aria-label="切换到球面卡库">${layoutIcon}</button><button class="cll-find" aria-label="查找预算卡">${glyph('<circle cx="10.5" cy="10.5" r="6.5"/><path d="m16 16 5 5"/>')}</button><button class="cll-close" aria-label="选用当前卡并返回首页">${glyph('<path d="m7 14 5-5 5 5"/>')}</button></div></header><div class="cll-body"></div><footer class="cll-footer"><button class="cll-return" aria-label="选用当前卡并返回首页"><span class="cll-grip"><svg viewBox="0 0 18 10" aria-hidden="true"><path d="m4 3 5 4 5-4"/></svg></span><span class="cll-return-label">下拉选用</span></button><span class="cll-count">${cards.length} 张</span></footer></section>`;
    const shell = root.firstElementChild, body = shell.querySelector('.cll-body');
    const machine = root.closest('.cartridge-world')?.querySelector('.machine-unit');
    if (machine) { machine.inert = true; machine.setAttribute('aria-hidden', 'true'); }
    const focused = () => ordered.length ? ordered[((Math.round(position) % ordered.length) + ordered.length) % ordered.length] : null;
    const currentElement = () => stage?.querySelector('[data-centered=true]');
    const large = props.large;
    const listen = (element, event, callback, options = {}) => element.addEventListener(event, callback, { signal: signal.signal, ...options });
    const cardName = m => [m.name, m.mainLabel, m.amountText].filter(Boolean).join('，');

    function publish() {
      const m = focused(); state.focused = m?.id || null; state.mode = mode;
      shell.dataset.focused = m?.id || ''; shell.dataset.mode = mode;
      if (m && orb) orb.update(m.period);
      if (status) { status.textContent = ''; status.hidden = true; }
      const label = mode === 'arc' && m ? '选用' + m.name + '并返回首页' : '返回首页';
      shell.querySelector('.cll-close').setAttribute('aria-label', label);
      shell.querySelector('.cll-return').setAttribute('aria-label', label);
      shell.querySelector('.cll-return-label').textContent = mode === 'arc' && m ? '下拉选用' : '下拉返回';
    }
    function geometry() {
      const width = stage?.clientWidth || root.clientWidth;
      const available = stage?.clientHeight || 250;
      const w = Math.min(340, width * .73, Math.max(168, available - 24) * 4 / 3);
      return { w, h: w * .75, pitch: w + 18 };
    }
    function paintCards() {
      if (!stage || !ordered.length || mode !== 'arc') return;
      const g = geometry(), middle = Math.round(position);
      const slots = ordered.length === 1 ? [0] : [middle - 2, middle - 1, middle, middle + 1, middle + 2];
      const keep = new Set(slots.map(String));
      for (const node of stage.children) if (!keep.has(node.dataset.slot)) node.remove();
      for (const slot of slots) {
        let node = stage.querySelector(`[data-slot="${slot}"]`);
        const model = ordered[((slot % ordered.length) + ordered.length) % ordered.length];
        if (!node) {
          node = document.createElement('button'); node.className = 'cll-slot'; node.dataset.slot = slot; node.dataset.budget = model.id;
          node.setAttribute('aria-label', cardName(model)); node.innerHTML = window.CheckLineLibraryCard.markup(model); stage.append(node);
        }
        const delta = slot - position, distance = Math.abs(delta), centered = slot === middle;
        const scale = props.reduced ? 1 : 1 - Math.min(.15, distance * .10);
        const x = delta * g.pitch, y = Math.min(26, distance * distance * 18);
        node.dataset.centered = String(centered); node.setAttribute('aria-current', String(centered)); node.tabIndex = centered ? 0 : -1;
        node.setAttribute('aria-hidden', String(distance > 1.4));
        Object.assign(node.style, { width: g.w + 'px', height: g.h + 'px', transform: `translate(-50%,-50%) translate3d(${x}px,${y}px,0) rotateY(${props.reduced ? 0 : -delta * 12}deg) rotateZ(${props.reduced ? 0 : delta * 2}deg) scale(${scale})`, opacity: String(clamp(1 - distance * .42, .16, 1)), zIndex: String(10 - Math.round(distance * 3)) });
      }
      if (state.focused !== focused()?.id) publish();
    }
    function moveTo(next, immediate = false) {
      cancelAnimationFrame(motion);
      if (ordered.length < 2) return;
      const from = position, start = performance.now();
      const frame = time => {
        if (destroyed || mode !== 'arc') return;
        const p = immediate || props.reduced ? 1 : clamp((time - start) / 280);
        position = lerp(from, next, 1 - Math.pow(1 - p, 3)); paintCards();
        if (p < 1) motion = requestAnimationFrame(frame); else { motion = 0; position = next; paintCards(); publish(); }
      };
      motion = requestAnimationFrame(frame);
    }
    function chooseCurrent() {
      if (state.transport?.settling) return;
      if (mode === 'arc' && focused()) finishTransport(focused().id, sourceRect(currentElement()));
      else originalOpen(false);
    }
    function chooseGrid(id, element) {
      if (mode === 'dome') element = body.querySelector('[role=dialog] img');
      finishTransport(id, sourceRect(element));
    }
    function grid() {
      const result = cards.filter(c => c.name.toLocaleLowerCase().includes(search.trim().toLocaleLowerCase()));
      const host = body.querySelector('.cll-grid');
      host.innerHTML = result.length ? result.map(m => `<button data-grid-card="${esc(m.id)}" aria-label="${esc(cardName(m))}">${window.CheckLineLibraryCard.markup(m, { compact: !large })}</button>`).join('') : '<p class="cll-empty">没有找到这张预算卡。</p>';
    }
    function show(nextMode) {
      cancelTransport(true); cancelAnimationFrame(motion); orb?.destroy(); orb = null; legacy?.unmount();
      mode = nextMode; shell.dataset.mode = mode; body.innerHTML = ''; stage = null; arc = null; period = null; status = null;
      shell.querySelector('.cll-layout').setAttribute('aria-label', mode === 'dome' ? '切换到弧线卡库' : '切换到球面卡库');
      shell.querySelector('.cll-find').setAttribute('aria-pressed', String(mode === 'search'));
      if (!cards.length) { body.innerHTML = '<p class="cll-empty"><strong>还没有预算卡</strong>创建一张，为在意的支出设条线。</p>'; publish(); return; }
      if (mode === 'arc') {
        body.innerHTML = '<div class="cll-arc"><div class="cll-period"></div><div class="cll-stage" aria-label="左右滑动浏览预算卡，下拉选用当前卡"></div><p class="cll-status"></p></div>';
        arc = body.firstElementChild; period = body.querySelector('.cll-period'); stage = body.querySelector('.cll-stage'); status = body.querySelector('.cll-status');
        orb = window.CheckLinePeriodOrb.create(period, { reduced: props.reduced, dark: props.dark });
        orb.update(focused().period, { immediate: true }); paintCards();
      } else if (mode === 'search') {
        body.innerHTML = '<div class="cll-search-wrap"><input class="cll-search" type="search" placeholder="查找预算卡" aria-label="查找预算卡" autocomplete="off"></div><div class="cll-grid"></div>';
        const input = body.querySelector('input'); input.value = search; listen(input, 'input', () => { search = input.value; grid(); }); grid(); input.focus({ preventScroll: true });
      } else {
        body.innerHTML = '<div class="cll-legacy"></div><div class="cll-edge cll-edge-left"></div><div class="cll-edge cll-edge-right"></div>';
        legacy.mount(body.querySelector('.cll-legacy'), { ...props, cards: cards.map(m => ({ ...m, value: m.amountText, symbol: '', libraryFill: m.fill, fill: m.fill * 100 })), onChoose: id => chooseGrid(id), onClose: () => originalOpen(false) });
      }
      publish();
    }
    listen(shell, 'click', event => {
      event.stopPropagation();
      if (performance.now() - lastClick < 260) { event.preventDefault(); return; }
      if (event.target.closest('.cll-layout')) show(mode === 'dome' ? 'arc' : 'dome');
      else if (event.target.closest('.cll-find')) show(mode === 'search' ? 'arc' : 'search');
      else if (event.target.closest('.cll-close,.cll-return')) chooseCurrent();
      else if (event.target.closest('[data-grid-card]')) { const b = event.target.closest('[data-grid-card]'); chooseGrid(b.dataset.gridCard, b); }
      else if (event.target.closest('.cll-slot')) { const b = event.target.closest('.cll-slot'); const slot = Number(b.dataset.slot); if (slot === Math.round(position)) finishTransport(focused().id, sourceRect(b)); else moveTo(slot); }
    });
    listen(shell, 'pointerdown', event => {
      // Preserve the retained sphere's two-axis input; own only its edges/footer.
      if (event.isPrimary !== false) lastClick = 0;
      const returnOnly = !!event.target.closest('.cll-return,.cll-edge');
      if (event.button !== 0 || event.isPrimary === false || pointer || state.transport?.settling || event.target.closest('input,.cll-controls') || (mode !== 'arc' && !returnOnly)) return;
      event.stopPropagation(); cancelAnimationFrame(motion);
      if (state.transport && !state.transport.settling) { cancelAnimationFrame(state.frame); state.frame = 0; }
      const continuation = state.transport && !state.transport.settling ? state.transport.dy : 0;
      pointer = { id: event.pointerId, x: event.clientX, y: event.clientY, origin: position, axis: null, dx: 0, dy: continuation, baseDy: continuation, lastX: event.clientX, lastY: event.clientY, lastTime: performance.now(), vx: 0, vy: 0, returnOnly };
    });
    listen(shell, 'pointermove', event => {
      const p = pointer; if (!p || p.id !== event.pointerId) return;
      const scale = shell.getBoundingClientRect().width / shell.clientWidth;
      p.dx = (event.clientX - p.x) / scale; p.dy = Math.max(0, p.baseDy + (event.clientY - p.y) / scale);
      if (!p.axis) {
        if (Math.hypot(p.dx, event.clientY - p.y) < 9) return;
        if (!p.returnOnly && mode === 'arc' && Math.abs(p.dx) > Math.abs(event.clientY - p.y) * 1.15) p.axis = 'horizontal';
        else if (p.dy > Math.abs(p.dx) * 1.05) p.axis = 'return';
        else return;
        shell.setPointerCapture(event.pointerId);
        if (p.axis === 'horizontal' && state.transport) cancelTransport(true);
        if (p.axis === 'return' && mode === 'arc' && focused()) { position = Math.round(position); paintCards(); beginTransport(focused().id, sourceRect(currentElement())); }
      }
      event.preventDefault(); event.stopPropagation();
      const time = performance.now(), dt = Math.max(1, time - p.lastTime);
      p.vx = (event.clientX - p.lastX) / dt; p.vy = (event.clientY - p.lastY) / dt; p.lastTime = time; p.lastX = event.clientX; p.lastY = event.clientY;
      if (p.axis === 'horizontal') { position = ordered.length > 1 ? p.origin - p.dx / geometry().pitch : 0; paintCards(); }
      else if (mode === 'arc') paintTransport(p.dy);
    });
    function release(event, cancelled) {
      const p = pointer; if (!p || p.id !== event.pointerId) return;
      pointer = null; event.stopPropagation();
      if (shell.hasPointerCapture(p.id)) shell.releasePointerCapture(p.id);
      if (!p.axis) { if (state.transport && !state.transport.settling) cancelTransport(); return; }
      lastClick = performance.now(); event.preventDefault();
      if (p.axis === 'horizontal') moveTo(Math.round(cancelled ? p.origin : position - clamp(p.vx * .18, -.45, .45)));
      else if (cancelled || p.dy < 72) cancelTransport();
      else if (mode === 'arc') finishTransport(focused().id, sourceRect(currentElement()));
      else originalOpen(false);
    }
    listen(shell, 'pointerup', e => release(e, false)); listen(shell, 'pointercancel', e => release(e, true));
    listen(window, 'pointerup', e => release(e, false), { capture: true });
    listen(window, 'pointercancel', e => release(e, true), { capture: true });
    listen(shell, 'pointerleave', e => { if (pointer && !pointer.axis && !shell.hasPointerCapture(pointer.id)) release(e, true); });
    listen(window, 'blur', () => { if (pointer) release({ pointerId: pointer.id, stopPropagation() {}, preventDefault() {} }, true); });
    listen(shell, 'keydown', event => {
      if (event.target.matches('input')) { if (event.key === 'Escape') { event.stopPropagation(); show('arc'); } return; }
      if (event.key === 'Escape') { event.preventDefault(); event.stopPropagation(); chooseCurrent(); }
      if (mode === 'arc' && ['ArrowLeft', 'ArrowRight'].includes(event.key)) { event.preventDefault(); moveTo(Math.round(position) + (event.key === 'ArrowRight' ? 1 : -1)); }
    });
    const resize = new ResizeObserver(() => { if (!state.transport) paintCards(); }); resize.observe(root);
    show('arc');
    return {
      get mode() { return mode; }, get focused() { return focused(); }, get moving() { return !!motion; }, chooseCurrent,
      paintReturn(progress, id) {
        if (mode !== 'arc') body.style.opacity = String(1 - clamp(progress * 2));
        if (period) period.style.opacity = String(1 - clamp(progress * 2.3));
        if (status) status.style.opacity = String(1 - clamp(progress * 2));
        for (const node of stage?.children || []) {
          if (id && node.dataset.centered === 'true') node.style.visibility = 'hidden'; else node.style.visibility = '';
          if (id && node.dataset.centered !== 'true') node.style.opacity = String(clamp(1 - Math.abs(Number(node.dataset.slot) - position) * .42, .16, 1) * (1 - clamp(progress * 2)));
        }
        shell.querySelector('.cll-header').style.opacity = String(1 - clamp(progress * 1.6));
        shell.querySelector('.cll-footer').style.opacity = String(1 - clamp(progress * 1.6));
        if (!id) paintCards();
      },
      destroy() { if (destroyed) return; destroyed = true; signal.abort(); cancelAnimationFrame(motion); resize.disconnect(); orb?.destroy(); legacy?.unmount(); if (machine) { machine.inert = false; machine.removeAttribute('aria-hidden'); } root.innerHTML = ''; }
    };
  }

  window.CheckLineLibrary = {
    mount(root, props) { state.controller?.destroy(); state.controller = createLibrary(root, props); },
    unmount() { state.controller?.destroy(); state.controller = null; }
  };
  readerMountLibrary = function () {
    if (!reader.library) return;
    const root = $('#reader-library-root', page); if (!root) return;
    window.CheckLineLibrary.mount(root, { cards: data.cards.map(cardModel), selectedId: reader.staged, dark: app.dataset.theme === 'dark', reduced: reducedMotion(), large: app.classList.contains('large-text') });
    requestAnimationFrame(() => { if (reader.library) readerFoldPrepare(); });
  };
  readerLibrary = async function (open) {
    if (open) { clearTransport(); state.homeRect = readHomeRect(); return originalOpen(true); }
    if (state.controller?.mode === 'arc' && state.controller.focused) { state.controller.chooseCurrent(); return reader.token; }
    clearTransport(); return originalOpen(false);
  };
  setTheme = function (theme) { cancelTransport(true); originalTheme(theme); };
  setReduced = function (on) { cancelTransport(true); originalReduced(on); };
  // Backgrounding must not replace the gallery DOM or commit a browsed card.
  // The gallery owns its own return cancellation/completion below.
  readerSettle = function () {
    if (reader.library) { readerClearHold(); return; }
    return originalSettle();
  };
  const viewportObserver = new ResizeObserver(() => {
    if (!readerRootVisible()) return;
    if (!state.transport) { readerFoldPrepare(); state.homeRect = readHomeRect(); }
  });
  viewportObserver.observe(app);
  window.addEventListener('resize', () => { if (state.transport) { if (state.transport.settling) completeSelection(state.transport.id); else cancelTransport(true); } });
  document.addEventListener('visibilitychange', () => { if (document.hidden && state.transport) { if (state.transport.settling) completeSelection(state.transport.id); else cancelTransport(true); } });
  window.CheckLineLibraryPreview = {
    snapshot: () => ({ mode: state.mode, selected: data.selected, focused: state.focused, browsing: !!state.controller?.moving, library: reader.library, phase: reader.phase, progress: state.transport?.animation ? lerp(state.transport.startProgress, 1, clamp(Number(state.transport.animation.currentTime) / 360)) : state.transport?.progress || 0, commits: state.commits, count: data.cards.length, reduced: reducedMotion(), theme: app.dataset.theme }),
  };
}
