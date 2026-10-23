/* Independent material-review shell. Inject inside the original DOMContentLoaded
   closure, immediately after outcomeSetupReview(). It changes presentation only. */
(() => {
  'use strict';
  const materialQuery = new URL(location.href).searchParams;
  const materialViews = [
    ['home', '预算首页'], ['records', '首页记录层'], ['library', '预算卡库'],
    ['detail', '预算工作区'], ['record', '消费详情'], ['trend', '消费日历'],
    ['history', '历史周期'], ['info', '预算信息'], ['wish', '心愿清单'],
    ['wish-back', '心愿大卡背面'], ['wallet', '心愿余额'],
    ['wallet-entry', '余额变动详情'], ['capture', '记一笔'],
    ['new-budget', '创建预算卡'], ['new-wish', '添加心愿'],
    ['wish-cover', '心愿封面'], ['agent', '小朵与输入'], ['settings', '设置'],
    ['settlement', '结算确认'], ['redemption', '心愿购买确认']
  ];
  const materialLabels = new Map(materialViews);
  let materialRequestedView = 'home';
  let materialSyncQueued = false;

  // Settings originally re-rendered the overlay after changing appearance.
  // Handle only its appearance buttons before the original delegated listener.
  // The theme setter itself deliberately never renders, settles, or navigates.
  setTheme = function materialSetTheme(value) {
    const theme = value === 'dark' ? 'dark' : 'light';
    app.dataset.theme = theme;
    window.CheckLineLibrary?.appearance?.(theme === 'dark');
    materialSyncThemeControls();
    materialUpdateShell();
  };

  function materialSyncThemeControls() {
    const dark = app.dataset.theme === 'dark';
    const oldToggle = document.getElementById('theme-toggle');
    if (oldToggle) {
      const label = dark ? '深色 / 浅色' : '浅色 / 深色';
      if (oldToggle.textContent !== label) oldToggle.textContent = label;
      oldToggle.setAttribute('aria-label', dark ? '切换至浅色外观' : '切换至深色外观');
      oldToggle.setAttribute('aria-pressed', String(dark));
    }
    document.querySelectorAll('[data-material-theme]').forEach(button => {
      const selected = button.dataset.materialTheme === (dark ? 'dark' : 'light');
      button.classList.toggle('selected', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
    app.querySelectorAll('[data-action="theme-light"],[data-action="theme-dark"]').forEach(button => {
      const selected = button.dataset.action === (dark ? 'theme-dark' : 'theme-light');
      button.classList.toggle('selected', selected);
      button.setAttribute('aria-pressed', String(selected));
    });
  }

  function materialSyncOptics() {
    const card = page.querySelector('.cartridge-card');
    if (!card || card.offsetHeight < 1) return;
    // offsetTop ignores live gesture transforms, so dragging never moves the light.
    let top = card.offsetTop + 8;
    for (let parent = card.offsetParent; parent && parent !== app; parent = parent.offsetParent) top += parent.offsetTop;
    const lengths = {'--r3-seat': top + card.offsetHeight, '--r3-card-top': top, '--r3-card-height': card.offsetHeight};
    for (const [key, length] of Object.entries(lengths)) {
      const value = Math.round(length) + 'px';
      if (app.style.getPropertyValue(key) !== value) app.style.setProperty(key, value);
    }
    // A single optical surface runs from the curved lip to the holder bottom.
    // Two translucent rectangles, even with the same color, create a hard seam.
    const shell = page.querySelector('.console-shell');
    if (shell) {
      let shellTop = shell.offsetTop;
      for (let parent = shell.offsetParent; parent && parent !== app; parent = parent.offsetParent) shellTop += parent.offsetTop;
      const w = shell.offsetWidth, h = Math.max(shell.offsetHeight + 20, app.clientHeight - shellTop + 22);
      const height = h + 'px';
      if (shell.style.getPropertyValue('--r3-pocket-height') !== height) shell.style.setProperty('--r3-pocket-height', height);
      const shape = `path("M0 0 C${w * .0425} 0 ${w * .075} 29 ${w * .1425} 32 H${w * .8575} C${w * .925} 29 ${w * .9575} 0 ${w} 0 V${h} H0 Z")`;
      if (shell.style.getPropertyValue('--r3-pocket-shape') !== shape) shell.style.setProperty('--r3-pocket-shape', shape);
      const svg = shell.querySelector('.console-lip svg'), edge = svg?.querySelector('path');
      if (svg?.getAttribute('viewBox') !== '0 0 400 34') svg?.setAttribute('viewBox', '0 0 400 34');
      const d = 'M0 .5 C17 .5 30 29.5 57 32.5 H343 C370 29.5 383 .5 400 .5';
      if (edge?.getAttribute('d') !== d) edge?.setAttribute('d', d);
    }
  }
  new ResizeObserver(materialSyncOptics).observe(app);

  function materialSyncNavigationLabels() {
    app.querySelectorAll('[data-action="tab-budget"]').forEach(button => button.setAttribute('aria-label', '预算'));
    app.querySelectorAll('[data-action="tab-wish"]').forEach(button => button.setAttribute('aria-label', '心愿'));
  }

  function materialInferView() {
    const sheet = ui.sheet;
    if (sheet?.type === 'manual') return ({capture: 'capture', budget: 'new-budget', wish: 'new-wish'})[ui.task?.kind] || 'capture';
    if (sheet?.type === 'agent') return 'agent';
    if (sheet?.type === 'settings') return 'settings';
    if (sheet?.type === 'wish-cover') return 'wish-cover';
    if (sheet?.type === 'settlement') return 'settlement';
    if (sheet?.type === 'redeem' || sheet?.type === 'completion' && sheet.target === 'wish') return 'redemption';
    if (sheet?.type === 'wish-card' || sheet?.type === 'wish-price') return sheet.face === 'back' || sheet.previous?.face === 'back' ? 'wish-back' : 'wish';
    if (ui.route === 'root') {
      if (ui.tab === 'wish') return 'wish';
      if (reader.library) return 'library';
      return readerFold.open || readerFold.progress > .5 ? 'records' : 'home';
    }
    if (ui.route === 'detail') return ui.params.section === 'records' || ui.filter === 'pending' ? 'records' : 'detail';
    if (ui.route === 'history-detail') return 'history';
    return materialLabels.has(ui.route) ? ui.route : materialRequestedView;
  }

  function materialText(selector, value) {
    const element = document.querySelector(selector);
    if (element && element.textContent !== value) element.textContent = value;
  }

  function materialUpdateShell() {
    const view = materialInferView();
    const label = materialLabels.get(view) || '当前页面';
    const theme = app.dataset.theme === 'dark' ? '暗色' : '浅色';
    const select = document.getElementById('material-page');
    if (select && materialLabels.has(view)) select.value = view;
    materialText('.review-label', '10/23 · 浅暗玻璃材质研究');
    materialText('.review-sidebar > .eyebrow', '浅暗材质 · 全页面核对');
    materialText('.review-notes > .eyebrow', '本轮材质研究');
    materialText('#note-title', '以 R3 为基准，保留透光与层次。');
    materialText('#note-copy', '保留 R3 的受光边缘、深色背衬和透色卡夹；浅暗主题分别配光。页面交互沿用 R34，全部操作只影响隔离示例。');
    materialText('#note-path', `当前：${label} · ${theme}。可原位切换外观；查看页面只切换本页示例，不修改 App。`);
    materialText('#screen-caption', `${label} · ${theme}材质`);
    materialText('.preview-footnote', '浅暗材质全页面样稿 · 延续 R34 交互 · 未修改 App');
    materialSyncNavigationLabels();
    materialSyncOptics();
  }

  const materialOriginalUpdateNotes = updateNotes;
  updateNotes = function materialNotes() {
    materialOriginalUpdateNotes();
    materialUpdateShell();
    materialSyncThemeControls();
  };

  function materialCloseLayers() {
    // Use each original dismissal path so task and purchase drafts survive.
    for (let count = 0; ui.sheet && count < 8; count++) {
      if (ui.sheet.type === 'wish-cover') wishCancelCover();
      else if (ui.sheet.type === 'wish-price') wishClosePrice();
      else closeSheet(false);
    }
    if (readerDrawer.active) readerDrawerReleaseHome(false, false);
    panelReturn = null;
  }

  function materialRoot(tab = 'budget') {
    materialCloseLayers();
    // Reset only presentation layers when explicitly selecting a review entry.
    // No card, expense, wish, wallet, or draft is created or edited here.
    readerFoldStop(false);
    readerFold.open = false;
    readerFold.progress = 0;
    reader.library = false;
    setTab(tab);
    if (tab === 'budget') {
      readerSync();
      if (readerCurrent()) {
        readerCancel();
        reader.active = reader.staged;
        reader.phase = 'connected';
        reader.pending = null;
        readerRender();
      }
    }
  }

  function materialNeedBudget() {
    const card = selectedCard() || data.cards[0];
    if (!card) toast('当前示例没有预算卡，可以先创建一张。');
    return card;
  }

  function materialOpenView(value) {
    const view = materialLabels.has(value) ? value : 'home';
    materialRequestedView = view;
    if (view === 'settlement' || view === 'redemption') {
      // These existing review fixtures stop at confirmation, never at save.
      outcomeLoadCase(view === 'settlement' ? 'transfer' : 'wish');
    } else if (['wish', 'wish-back', 'wallet', 'wallet-entry', 'new-wish', 'wish-cover'].includes(view)) {
      materialRoot('wish');
      if (view === 'wish' || view === 'wish-back') {
        wishCollectionSwitch('phase', 'active');
        wishCollectionSwitch('view', 'cards');
      }
      if (view === 'new-wish') openTask('wish');
      else if (view === 'wish-cover') { openTask('wish'); wishOpenCover(); }
      else if (view === 'wallet') navigate('wallet');
      else if (view === 'wallet-entry') {
        const entry = data.walletEntries[0];
        if (entry) navigate('wallet-entry', {id: entry.id});
        else { navigate('wallet'); toast('当前示例还没有余额变动。'); }
      } else if (view === 'wish-back') {
        const wish = data.wishes.find(item => !item.achieved) || data.wishes[0];
        if (wish?.achieved) wishCollectionSwitch('phase', 'done');
        const expand = [...page.querySelectorAll('[data-action="wish-expand"]')].find(button => button.dataset.id === wish?.id);
        if (expand) {
          handleAction('wish-expand', expand);
          const card = overlayRoot.querySelector('.wish-flip-card');
          if (card) wishTurnTo(card, 180);
        } else toast('当前示例还没有心愿，可以先添加一个。');
      }
    } else {
      materialRoot('budget');
      if (view === 'records') {
        if (materialNeedBudget()) readerLevel('up');
      } else if (view === 'library') {
        if (materialNeedBudget()) readerLibrary(true);
      } else if (['detail', 'record', 'trend', 'history', 'info'].includes(view)) {
        const card = materialNeedBudget();
        if (card && view === 'record') {
          const expense = cardExpenses(card)[0] || data.expenses.find(item => !item.deleted);
          if (expense) navigate('record', {id: expense.id});
          else { navigate('detail', {id: card.id, section: 'records'}); toast('当前示例还没有消费记录。'); }
        } else if (card) {
          if (view === 'trend') ui.calendarDay = today();
          navigate(view, {id: card.id});
        }
      } else if (view === 'capture') openTask('capture', selectedCard()?.id || null);
      else if (view === 'new-budget') openTask('budget');
      else if (view === 'agent') openTask('capture', null, 'agent');
      else if (view === 'settings') {
        const button = page.querySelector('[data-action="settings"]');
        if (button) handleAction('settings', button);
      }
    }
    materialSyncThemeControls();
    materialUpdateShell();
  }

  document.title = 'CheckLine · 浅暗玻璃材质全页面研究';
  document.body.classList.toggle('material-embedded', materialQuery.get('embed') === '1');
  const materialStyle = document.createElement('style');
  materialStyle.id = 'material-study-shell-style';
  materialStyle.textContent = `
    .material-theme-controls{display:flex;align-items:center;gap:4px;padding:4px;border:1px solid #677b8533;border-radius:999px;background:#ffffff38}
    .material-theme-controls button{min-height:34px;padding:0 15px;border-radius:999px;font-size:12px;color:#435d6b}
    .material-theme-controls button.selected{background:#edfaff;color:#183e55;box-shadow:inset 0 1px #fff,0 1px 4px #173e5520}
    .material-theme-controls button[aria-pressed=true][data-material-theme=dark]{background:#17364c;color:#e7f8ff;box-shadow:inset 0 1px #94d5f13d}
    .material-page-control{margin:0 0 22px}.material-page-control select{width:100%}
    #note-path{white-space:normal;line-height:1.6}
    body.material-embedded{margin:0;padding:0;background:transparent}
    body.material-embedded .review-header,body.material-embedded .review-sidebar,body.material-embedded .review-notes,body.material-embedded .preview-caption,body.material-embedded .preview-footnote{display:none!important}
    body.material-embedded .review-layout{display:block;max-width:none;margin:0;padding:0}
    body.material-embedded .preview-area{display:block;margin:0;padding:0;min-width:0}
    body.material-embedded .app{max-height:none}
  `;
  document.head.appendChild(materialStyle);

  const materialHeader = document.querySelector('.review-header');
  if (materialHeader && !materialHeader.querySelector('[data-material-theme]')) {
    const controls = document.createElement('div');
    controls.className = 'material-theme-controls';
    controls.setAttribute('role', 'group');
    controls.setAttribute('aria-label', '材质外观');
    controls.innerHTML = '<button type="button" data-material-theme="light" aria-pressed="true">浅色</button><button type="button" data-material-theme="dark" aria-pressed="false">暗色</button>';
    materialHeader.appendChild(controls);
  }
  const materialCompareHref = /(?:^|\/)material-themes-20261023\.html$/.test(location.pathname) ? 'material-compare-20261023.html' : 'compare.html';
  document.querySelectorAll('.material-compare').forEach(link => link.setAttribute('href', materialCompareHref));
  const materialSidebar = document.querySelector('.review-sidebar');
  if (materialSidebar) {
    const control = document.createElement('div');
    control.className = 'scenario-control material-page-control';
    const label = document.createElement('label');
    label.htmlFor = 'material-page';
    label.textContent = '查看页面';
    const select = document.createElement('select');
    select.id = 'material-page';
    select.setAttribute('aria-label', '查看材质研究页面');
    materialViews.forEach(([value, text]) => {
      const option = document.createElement('option');
      option.value = value;
      option.textContent = text;
      select.appendChild(option);
    });
    select.addEventListener('change', event => materialOpenView(event.target.value));
    control.append(label, select);
    materialSidebar.prepend(control);
  }

  document.addEventListener('click', event => {
    const button = event.target?.closest?.('[data-material-theme],[data-action="theme-light"],[data-action="theme-dark"],#theme-toggle');
    if (!button || button.disabled) return;
    event.preventDefault();
    event.stopImmediatePropagation();
    const theme = button.dataset.materialTheme || (button.id === 'theme-toggle' ? (app.dataset.theme === 'dark' ? 'light' : 'dark') : button.dataset.action === 'theme-dark' ? 'dark' : 'light');
    setTheme(theme);
  }, true);

  // Sync only labels and selected states after the original app creates DOM.
  // childList-only observation cannot react to its own aria/class updates.
  const materialObserver = new MutationObserver(() => {
    if (materialSyncQueued) return;
    materialSyncQueued = true;
    queueMicrotask(() => {
      materialSyncQueued = false;
      materialSyncNavigationLabels();
      materialSyncThemeControls();
      materialSyncOptics();
    });
  });
  materialObserver.observe(app, {childList: true, subtree: true});

  if (materialQuery.get('reduce') === '1') {
    app.classList.add('reduced');
    document.getElementById('reduce-motion').checked = true;
  }
  setTheme(materialQuery.get('theme') === 'dark' ? 'dark' : 'light');
  const requestedView = materialQuery.get('view');
  // Honor the original screen/motion deep links when no material view is given.
  if (materialLabels.has(requestedView)) materialOpenView(requestedView);
  else if (!materialQuery.has('motion') && materialQuery.get('screen') !== 'wish') materialOpenView('home');
  materialSyncThemeControls();
  materialUpdateShell();
})();
