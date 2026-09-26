import test from 'node:test';
import assert from 'node:assert/strict';
import { validDate, monthEnd, recordsFor, sortRecords, projection, periodStatus, budgetDate, weekSeries, retrospectiveImpact } from '../docs/design/explorations/glass-data.mjs';

const september = { id: 'daily', name: '日常生活', cents: 10000, start: '2026-09-01', end: '2026-09-30' };
const expense = (id, date, cents, extra = {}) => ({ id, date, cents, budgetID: 'daily', ...extra });

test('完整年月日隔离跨月、跨年与未纳入记录', () => {
  const rows = [expense('aug', '2026-08-24', 800), expense('sep', '2026-09-24', 900), expense('old', '2025-09-24', 700), expense('none', '2026-09-24', 600, { unbudgeted: true })];
  assert.deepEqual(recordsFor(rows, september).map(r => r.id), ['sep']);
  assert.equal(validDate('2026-02-29'), false);
  assert.equal(validDate('2024-02-29'), true);
  assert.equal(monthEnd('2024-02-01'), '2024-02-29');
});

test('日期倒序保留记录身份，同日顺序稳定', () => {
  const rows = [expense('older', '2026-09-01', 1), expense('latest-a', '2026-09-26', 2), expense('latest-b', '2026-09-26', 3)];
  assert.deepEqual(sortRecords(rows).map(r => r.id), ['latest-a', 'latest-b', 'older']);
  assert.equal(rows[0].id, 'older');
});

test('只有待确认造成越线时显示可能超出，确认后才成为确定越线', () => {
  const rows = [expense('confirmed', '2026-09-22', 9000), expense('pending', '2026-09-24', 2000, { pending: true })];
  assert.deepEqual(projection(rows, september), { confirmed: 9000, pending: 2000, total: 11000, remaining: -1000, level: 0, risk: 'possible' });
  assert.equal(projection(rows.map(r => ({ ...r, pending: false })), september).risk, 'confirmed');
  assert.equal(projection([expense('exact', '2026-09-22', 10000)], september).risk, 'none');
});

test('周期状态区分无期限、待结算、尚未开始及已结算', () => {
  assert.equal(periodStatus(september), '4 天剩余');
  assert.equal(periodStatus({ ...september, end: null }), '无截止日期');
  assert.equal(periodStatus({ ...september, end: '2026-09-20' }), '待结算');
  assert.equal(periodStatus({ ...september, start: '2026-10-01', end: '2026-10-31' }), '尚未开始');
  assert.equal(periodStatus({ ...september, settled: true }), '已结算');
  assert.equal(budgetDate({ ...september, settled: true, end: '2026-08-31' }), '2026-08-31');
});

test('趋势仅统计当前卡最近七天，包含零消费日期', () => {
  const series = weekSeries([expense('earlier', '2026-09-19', 1000), expense('a', '2026-09-20', 1200), expense('b', '2026-09-24', 800, { pending: true }), expense('other', '2026-09-24', 9900, { budgetID: 'other' })], september);
  assert.equal(series.length, 7);
  assert.equal(series[0].date, '2026-09-20');
  assert.equal(series.at(-1).date, '2026-09-26');
  assert.equal(series.reduce((n, r) => n + r.cents, 0), 2000);
  assert.equal(series.at(-1).cents, 0);
});

test('已结算消费增加先扣钱包，缺口进入待恢复差额', () => {
  const settled = { ...september, settled: true };
  const impact = retrospectiveImpact([expense('a', '2026-09-24', 5000)], [expense('a', '2026-09-24', 13000)], [settled], 6000, 0);
  assert.equal(impact.delta, -8000);
  assert.equal(impact.wallet, 0);
  assert.equal(impact.recovery, 2000);
  assert.deepEqual(impact.affected[0], { id: 'daily', name: '日常生活', before: 5000, after: -3000 });
});

test('删除已结算消费产生的结余先补待恢复差额', () => {
  const impact = retrospectiveImpact([expense('a', '2026-09-24', 5000)], [], [{ ...september, settled: true }], 0, 3000);
  assert.equal(impact.wallet, 2000);
  assert.equal(impact.recovery, 0);
  assert.equal(impact.delta, 5000);
});

test('当前周期变更不触发已结算追溯；待确认不提前改钱包', () => {
  const settled = { ...september, id: 'summer', start: '2026-08-01', end: '2026-08-31', settled: true };
  const impact = retrospectiveImpact([], [expense('new', '2026-09-24', 5000), expense('pending', '2026-08-24', 8000, { budgetID: 'summer', pending: true })], [september, settled], 2000, 0);
  assert.deepEqual(impact.affected, []);
  assert.equal(impact.wallet, 2000);
});
