/* R3 review only. Shared entry state, in-place SVG appearance and operable dock.
   Inject before study-bridge.js; never render or replay when appearance changes. */
const materialInteractions = (() => {
  'use strict';
  const presetSources = new Map(Object.entries(REVIEW_ASSETS)
    .filter(([key]) => key.startsWith('wish-')).map(([key, url]) => [url, key]));
  const mascotSource = mascot().match(/src="([^"]+)"/)?.[1];
  const variants = new Map();
  const mascotRoles = {
    '#8976bd': '--model-top', '#4c317b': '--model-shade',
    '#563496': '--model-mid', '#7860c9': '--model-lower',
    '#a698ed': '--model-edge', '#f3e8ff': '--model-rim-top',
    '#c6b3f9': '--model-rim-mid', '#7561b5': '--model-rim-shade',
    '#e8ddff': '--model-rim-bottom', '#a99dff': '--model-glint'
  };

  function sourceSVG(url) {
    const comma = url.indexOf(',');
    return url.slice(0, comma).includes(';base64') ? atob(url.slice(comma + 1)) : decodeURIComponent(url.slice(comma + 1));
  }
  function recolor(url, colors) {
    const key = url + JSON.stringify(colors);
    if (!variants.has(key)) {
      const svg = sourceSVG(url).replace(/#[0-9a-f]{6}\b/gi, color => colors[color.toLowerCase()] || color);
      variants.set(key, 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg));
    }
    return variants.get(key);
  }
  function syncArt() {
    const style = getComputedStyle(app);
    const modelColors = Object.fromEntries(Object.entries(mascotRoles).map(([color, role]) => [color, style.getPropertyValue(role).trim()]));
    app.querySelectorAll('img.mascot').forEach(img => {
      if (!mascotSource) return;
      const next = recolor(mascotSource, modelColors);
      if (img.getAttribute('src') !== next) img.setAttribute('src', next);
      img.dataset.materialArt = 'mascot';
    });
    app.querySelectorAll('.preset-art > img, .wish-preset-grid img').forEach(img => {
      const key = img.dataset.materialPreset || presetSources.get(img.getAttribute('src'));
      if (!key || !REVIEW_ASSETS[key]) return;
      img.dataset.materialPreset = key;
      const ink = getComputedStyle(img).getPropertyValue('--icon-accent').trim();
      const next = recolor(REVIEW_ASSETS[key], {'#86639f': ink});
      if (img.getAttribute('src') !== next) img.setAttribute('src', next);
    });
  }

  function availability(w) {
    if (!w || w.achieved) return {state: 'done', label: '兑换，心愿已实现'};
    if (!wishHasPrice(w)) return {state: 'unpriced', label: '兑换不可用，请先填写心愿金额'};
    const p = wishProgress(w);
    if (p.ratio == null) return {state: 'unquoted', label: '兑换不可用，待核对汇率'};
    if (p.ratio < 1) return {state: 'incomplete', label: `兑换不可用，当前进度 ${p.percent}%，达到 100% 后可兑换`};
    return {state: 'ready', label: '兑换，核对实际购买'};
  }
  function buttonMarkup(w) {
    const status = availability(w), ready = status.state === 'ready';
    return `<button class="primary wish-redeem-button${ready ? ' is-redeemable' : ''}" data-action="wish-purchase" data-id="${esc(w.id)}" data-redeem-status="${status.state}" aria-disabled="${!ready}" aria-label="${esc(status.label)}" ${ready ? '' : 'disabled'}>兑换</button>`;
  }
  const originalBack = wishFaceBack;
  wishFaceBack = function materialWishBack(w, ...args) {
    return originalBack(w, ...args).replace(/<button class="primary wish-redeem-button[^>]*>兑换<\/button>/, buttonMarkup(w));
  };
  const originalStart = startRedemption;
  startRedemption = function materialStartRedemption(id) {
    if (availability(data.wishes.find(w => w.id === id)).state !== 'ready') return;
    return originalStart(id);
  };
  const originalAction = handleAction;
  handleAction = function materialAction(action, el) {
    if (action === 'wish-purchase' && (el?.disabled || el?.closest('.wish-flip-card')?.dataset.turning === 'true')) return;
    return originalAction(action, el);
  };
  function syncButtons() {
    app.querySelectorAll('.wish-redeem-button').forEach(button => {
      const status = availability(data.wishes.find(w => w.id === button.dataset.id));
      const turning = button.closest('.wish-flip-card')?.dataset.turning === 'true';
      const ready = status.state === 'ready' && !turning;
      button.disabled = !ready;
      button.setAttribute('aria-disabled', String(!ready));
      button.setAttribute('aria-label', turning ? '兑换，等待卡片翻面完成' : status.label);
      button.dataset.redeemStatus = turning ? 'turning' : status.state;
      button.classList.toggle('is-redeemable', ready);
      button.classList.remove('has-purchase-draft');
    });
  }
  function syncDock() {
    const button = app.querySelector('.dock .agent-launch');
    if (button) {
      button.setAttribute('aria-haspopup', 'dialog');
      button.setAttribute('aria-expanded', String(ui.sheet?.type === 'agent'));
      button.setAttribute('title', '小朵');
    }
  }
  function sync() { syncArt(); syncButtons(); syncDock(); }
  const originalNotes = updateNotes;
  updateNotes = function materialInteractionNotes() { originalNotes(); sync(); };

  // Only asset/card additions and flip completion matter here. Odometer frames
  // and bubble style updates must not trigger appearance work every frame.
  new MutationObserver(records => {
    if (records.some(record => record.type === 'attributes' || [...record.addedNodes].some(node =>
      node.nodeType === 1 && (node.matches('img,.wish-flip-card,.dock-tabs,.agent-launch') || node.querySelector('img,.wish-flip-card,.dock-tabs,.agent-launch'))))) sync();
  }).observe(app, {childList: true, subtree: true, attributes: true, attributeFilter: ['data-turning']});
  sync();
  return {sync};
})();
