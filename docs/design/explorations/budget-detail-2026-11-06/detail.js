function installBudgetDetailStudy() {
  const params = new URL(location.href).searchParams;
  const mainCard = cardById('month');
  const recentDay = (offset) => {
    const date = shiftDay(today(), -offset);
    return date < mainCard.start ? mainCard.start : date;
  };
  const coffee = data.expenses.find((expense) => expense.id === 'e2');
  coffee.status = 'pending';
  coffee.date = today();
  const grouped = [
    ['早餐', 24, 1], ['通勤打车', 56, 1], ['日用品补货', 86, 2],
    ['工作午餐', 48, 2], ['周末聚餐', 236, 3], ['水果', 72, 3],
    ['家庭采购', 268, 5], ['餐厅', 185, 6], ['便利店', 45, 6], ['生活缴费', 100, 8],
  ];
  const original = data.expenses.find((expense) => expense.id === 'e6');
  data.expenses = data.expenses.filter((expense) => expense !== original);
  data.expenses.push(...grouped.map(([merchant, amount, offset], index) => ({
    ...original, id: 'study-' + index, merchant, amount: amount * 100, budgetAmount: amount * 100, date: recentDay(offset),
  })));
  if (params.get('case') === 'empty') data.expenses = [];
  if (params.get('case') === 'due') mainCard.end = shiftDay(today(), -1);
  if (params.get('text') === 'large') {
    app.classList.add('large-text');
    app.style.setProperty('--font-scale', '1.35');
  }

  let rowToRestore;
  const baseDetail = readerDrawerRoutes.detail;
  const baseRecord = readerDrawerRoutes.record;
  const baseRender = readerDrawerRender;

  const pageType = () => ui.route === 'detail' && ui.params.section !== 'records' && ui.filter !== 'pending'
    ? 'overview' : ui.route === 'record' ? 'record' : 'other';

  readerDrawerRoutes.detail = () => {
    if (pageType() !== 'overview') return baseDetail();
    const card = cardById(ui.params.id);
    if (!card) return missingPage();
    const records = cardExpenses(card);
    const due = card.end && card.end < today();
    const days = new Map();
    for (const expense of records.slice(0, 10)) {
      if (!days.has(expense.date)) days.set(expense.date, []);
      days.get(expense.date).push(expense);
    }
    const destinations = [
      ['calendar', '消费日历', 'trend'],
      ['history', '历史周期', 'history'],
      ['settings', '卡片信息', 'info'],
    ];
    return `<section class="detail-page bd-overview">
      ${detailHead(card.name, ib('more', '预算操作', 'card-menu', `data-id="${card.id}"`))}
      <div class="detail-content bd-content">
        <div class="bd-liquid-anchor">${dmDetailCard(card)}</div>
        <div class="bd-liquid-space" aria-hidden="true"></div>
        <section class="bd-recent" aria-labelledby="bd-recent-title">
          <div class="bd-recent-heading">
            <h3 id="bd-recent-title">近期消费</h3>
            ${records.length ? `<button data-action="cart-records" data-id="${card.id}" aria-label="查看全部消费">全部<span aria-hidden="true">›</span></button>` : ''}
          </div>
          <div class="bd-record-list">
            ${records.length ? [...days].map(([date, expenses]) =>
              `<h4 class="bd-record-date">${dateLabel(date)}</h4>${expenses.map((expense) => recordRow(expense, false)).join('')}`).join('')
              : '<p class="empty-inline">还没有这张预算的消费。</p>'}
          </div>
        </section>
        <nav class="bd-shortcuts" aria-label="预算详情入口">
          ${destinations.map(([symbol, label, action]) =>
            `<button data-action="${action}" data-id="${card.id}">${icon(symbol, 'small')}${label}</button>`).join('')}
        </nav>
      </div>
      <footer class="bd-actions">
        ${due ? `<button class="secondary" data-action="settlement" data-id="${card.id}">${icon('document', 'small')}本期已到期 · 去结算</button>` : ''}
        <button class="bd-record-action" data-action="capture" data-id="${card.id}">${icon('add', 'small')}记一笔</button>
      </footer>
    </section>`;
  };

  readerDrawerRoutes.record = () => baseRecord().replace('class="detail-page', 'class="detail-page bd-record-page');

  function syncScroll(body) {
    const card = body.querySelector('.bd-liquid-anchor');
    if (!card) return;
    const travel = reducedMotion() ? (body.scrollTop >= 112 ? 1 : 0) : Math.min(1, body.scrollTop / 126);
    card.style.setProperty('--bd-fold', travel.toFixed(4));
    body.dataset.folded = String(travel >= 1);
  }

  readerDrawerRender = function renderStudyDrawer() {
    const oldDrawer = app.querySelector('.reader-drawer');
    const previous = oldDrawer?.dataset.studyPage;
    const next = pageType();
    const nextRecordID = ui.route === 'record' ? ui.params.id : null;
    if (previous === 'overview' && nextRecordID) rowToRestore = nextRecordID;
    const goingToRecord = previous === 'overview' && next === 'record';
    const returning = previous === 'record' && next === 'overview';
    const outgoing = goingToRecord || returning ? oldDrawer.querySelector('.reader-drawer-body') : null;
    const outgoingScroll = outgoing?.scrollTop;
    const outgoingHeight = outgoing?.clientHeight;
    const outgoingTop = outgoing?.offsetTop;
    baseRender();
    const drawer = app.querySelector('.reader-drawer');
    const body = drawer?.querySelector('.reader-drawer-body');
    if (!body) return;
    drawer.dataset.studyPage = next;
    const title = drawer.querySelector('#reader-drawer-title');
    if (next === 'overview') title.textContent = '预算详情';
    const footer = body.querySelector('.bd-actions');
    if (footer) drawer.append(footer);
    // Restore after moving the footer, which changes the viewport's scroll limit.
    body.scrollTop = readerDrawer.positions[readerDrawer.bodyKey] || 0;
    syncScroll(body);
    body.addEventListener('scroll', () => syncScroll(body), { passive: true });
    if (outgoing) {
      for (const animation of body.getAnimations()) animation.cancel();
      if (!reducedMotion()) {
        const direction = goingToRecord ? 1 : -1;
        outgoing.inert = true;
        outgoing.setAttribute('aria-hidden', 'true');
        outgoing.classList.add('bd-outgoing');
        // Outgoing content stays where it was while the destination slides in.
        outgoing.style.height = outgoingHeight + 'px';
        outgoing.style.setProperty('--bd-transition-top', outgoingTop + 'px');
        drawer.append(outgoing);
        outgoing.scrollTop = outgoingScroll;
        outgoing.animate([
          { transform: 'translateX(0)', opacity: 1 },
          { transform: `translateX(${-direction * 21}%)`, opacity: 0 },
        ], { duration: 240, easing: 'ease-out' }).finished.finally(() => outgoing.remove()).catch(() => {});
        body.animate([
          { transform: `translateX(${direction * 38}%)`, opacity: 0 },
          { transform: 'translateX(0)', opacity: 1 },
        ], { duration: 270, easing: 'cubic-bezier(.22,.7,.25,1)' });
      }
    }
    if (goingToRecord) body.focus({ preventScroll: true });
    if (returning) {
      body.querySelector(`[data-action="record"][data-id="${CSS.escape(rowToRestore || '')}"]`)?.focus({ preventScroll: true });
      rowToRestore = undefined;
    }
  };
}
