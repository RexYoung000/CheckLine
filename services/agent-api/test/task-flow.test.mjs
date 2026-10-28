import test from 'node:test';
import assert from 'node:assert/strict';
import { makeReviewCases } from '../review/scenarios.mjs';
import { createReviewTask, planReviewTask, advanceReviewTask, suspendReviewTask } from '../review/task-flow.mjs';
import { decimalAdd, decimalSubtract, decimalCompare, demoConvert, demoMonthlyWindow } from '../review/demo-values.mjs';
import { interpret, SYSTEM_PROMPT } from '../src/workflow.mjs';
import { requestFor } from '../review/fixtures.mjs';

const cases = await makeReviewCases();
const task = id => createReviewTask(cases.find(c => c.id === id));
const plan = planReviewTask;
const act = (t,id) => advanceReviewTask(t,{type:'action',id,token:plan(t).token});
const choose = (t,id) => advanceReviewTask(t,{type:'choose',id});
const reply = (t,values) => advanceReviewTask(t,{type:'reply',values});
const check = (t,key) => advanceReviewTask(t,{type:'check',key,value:true});
const confirm = t => act(t,'confirm');
const resolve = t => advanceReviewTask(t,{type:'resolveRetry',requestToken:t.requestToken});
const spent = t => t.local.cards[0].periods.find(p=>p.id==='food-oct').spent;

function walk(initial) {
  let t = initial;
  const path=[];
  for(let i=0;i<80;i++) {
    const p=plan(t);path.push(p.stage);
    if(['complete','closed','finishedRefusal'].includes(p.stage)) {
      if(t.parentSplit){t=act(t,'continueSplit');continue;}
      return {t,path};
    }
    if(p.stage==='working'){t=resolve(t);continue;}
    if(p.stage==='error'){t=act(t,'retry');continue;}
    if(p.stage==='saveFailure'){t=act(t,'retrySave');continue;}
    if(p.stage==='attachmentFailure'){t=act(t,'retryAttachments');continue;}
    if(p.stage==='retrospective'){t=act(t,'openRetrospective');continue;}
    if(p.stage==='noMatch'){t=act(t,'showAllExpenses');continue;}
    if(p.stage==='splitComplete'){t=act(t,'close');continue;}
    if(p.fields.some(f=>f.type==='checkbox')){
      for(const f of p.fields.filter(f=>f.type==='checkbox'))t=check(t,f.key);
      t=confirm(t);continue;
    }
    if(p.fields.length){
      const defaults={amount:'35元',actualAmount:'399',newAmount:'1200',currencyCode:'CNY',name:'午餐预算',cycleType:'repeating',occurredAt:'2026-10-13',startDate:'2026-10-14',endDate:'2026-10-20',searchDate:'2026-10-13',scheduleKind:'window',startDay:'5',endDay:'20'};
      t=reply(t,Object.fromEntries(p.fields.map(f=>[f.key,defaults[f.key]??f.value??'午餐'])));continue;
    }
    if(p.choices.length){t=choose(t,p.choices[0].id);continue;}
    const a=['confirm','confirmPending','acceptCaptureRate','retryCaptureRate','acceptConversion','retryConversion','finishReadOnly','close'].find(id=>p.actions.some(a=>a.id===id));
    assert(a,`${t.itemID}: no continuation at ${p.stage}`);
    t=act(t,a);
  }
  assert.fail(`${initial.itemID}: did not finish: ${path.join(' > ')}`);
}

for(const c of cases) test(`complete isolated task: ${c.id}`,()=>{
  const {t}=walk(createReviewTask(c));
  assert(['complete','closed','finishedRefusal'].includes(plan(t).stage));
});

test('a missing amount reply keeps the same task and known merchant',()=>{
  let t=task('missing-amount');const id=t.id;
  t=reply(t,{amount:'35元'});
  assert.equal(t.id,id);assert.equal(t.draft.merchant,'午餐');assert.equal(t.draft.amount,'35');assert.equal(t.draft.currencyCode,'CNY');
  assert.equal(plan(t).stage,'chooseBudget');
});
test('missing device date is answered before attribution and remains selected',()=>{
  let t=task('relative-no-time');assert.equal(plan(t).fields[0].key,'occurredAt');
  t=reply(t,{occurredAt:'2026-10-13'});assert.equal(t.draft.occurredAt,'2026-10-13');
  assert.equal(plan(t).rows.find(r=>r[0]==='消费日期')[1],'2026-10-13');
});
test('currency must be selected and is never silently changed to budget currency',()=>{
  let t=task('missing-currency');assert.equal(plan(t).fields[0].key,'currencyCode');
  t=reply(t,{currencyCode:'USD'});assert.equal(t.draft.amount,'35');assert.equal(t.draft.currencyCode,'USD');assert.equal(plan(t).stage,'needsRate');
});
test('monthly dates are shown before creation; undo restores fictional data',()=>{
  let t=task('monthly');const before=structuredClone(t.local);
  assert(plan(t).rows.some(r=>r[1]==='2026-10-05 — 2026-10-20'));assert.equal(t.local.cards.length,1);
  t=act(t,'editSchedule');t=reply(t,{scheduleKind:'window',startDay:'20',endDay:'5'});
  assert(plan(t).rows.some(r=>r[1]==='2026-10-20 — 2026-11-05'));
  t=confirm(t);assert.equal(t.local.cards.length,2);t=act(t,'undo');assert.deepEqual(t.local,before);
});
test('amendment continues the selected draft without saving a second record',()=>{
  let t=choose(task('correction'),'editDraft');
  assert.equal(t.draft.amount,'38');assert.equal(t.draft.merchant,'午餐');assert.equal(t.draft.occurredAt,'2026-10-13');assert.equal(t.local.expenses.length,1);
});
test('one-shot dates can be reopened and edited without losing their current values',()=>{
  let t=task('monthly');Object.assign(t.draft,{cycleType:'oneShot',startDate:'2026-10-14',endDate:'2026-10-20'});
  t=act(t,'editSchedule');assert.equal(plan(t).stage,'input');assert.equal(plan(t).fields[0].value,'2026-10-14');
  t=reply(t,{startDate:'2026-10-15',endDate:'2026-10-21'});assert.equal(plan(t).stage,'confirm');assert(plan(t).rows.some(r=>r[1]==='2026-10-15 — 2026-10-21'));
});
test('saved expense correction changes exactly one record and its budget delta',()=>{
  let t=choose(task('correction'),'editExpense');assert.equal(plan(t).stage,'confirm');
  t=confirm(t);assert.equal(t.local.expenses.length,1);assert.equal(t.local.expenses[0].amount,'38');assert.equal(spent(t),'303');
});
test('partial refund keeps the original purchase and only restores the refunded part',()=>{
  let t=task('refund');assert(plan(t).rows.some(r=>r[0]==='退款后未退金额'&&r[1].includes('15')));
  t=confirm(t);assert.equal(t.local.expenses.length,1);assert.equal(t.local.expenses[0].amount,'50');assert.equal(t.local.expenses[0].refunded,'35');assert.equal(spent(t),'265');assert.equal(t.local.wallet.balance,'1280');
});
test('refund selects stable IDs when multiple records match, and no match can end',()=>{
  let t=task('refund-multiple');assert.equal(plan(t).stage,'selectExpense');
  t=choose(t,'expense:lunch-today');t=confirm(t);assert.equal(t.local.expenses[1].refunded,'35');assert.equal(t.local.expenses[0].refunded,'0');
  t=task('refund-none');const before=structuredClone(t.local);t=act(t,'close');assert.deepEqual(t.local,before);assert.equal(plan(t).stage,'closed');
});
test('refund cannot exceed the unrefunded original amount',()=>{
  let t=task('refund');t=act(t,'manual');t=reply(t,{amount:'60',currencyCode:'CNY',merchant:'午餐',occurredAt:'2026-10-13'});
  assert.equal(plan(t).stage,'input');t=reply(t,{amount:'20'});assert.equal(plan(t).ready,true);
});
test('settled refund shows the original period and wallet impact before confirmation',()=>{
  let t=task('refund-settled');assert.equal(t.local.wallet.balance,'1280');assert(plan(t).rows.some(r=>r[1].includes('2026-09-01')));
  t=confirm(t);assert.equal(t.local.wallet.balance,'1315');assert.equal(t.local.cards[0].periods[0].spent,'665');
});
test('unexpired settlement only estimates, with no wallet write or submission',()=>{
  let t=choose(task('settlement'),'period:food-oct');const before=structuredClone(t.local);
  assert.equal(plan(t).stage,'estimate');assert(!plan(t).actions.some(a=>a.id==='confirm'));t=confirm(t);assert.deepEqual(t.local,before);
  t=act(t,'finishReadOnly');assert.deepEqual(t.local,before);
});
test('due settlement needs renewed acknowledgement and rejects stale confirmation',()=>{
  let t=choose(task('settlement-due'),'period:food-sep');const stale=plan(t).token;
  assert.equal(plan(t).ready,false);t=confirm(t);assert.equal(t.local.wallet.balance,'1280');
  t=check(t,'acknowledged');t=advanceReviewTask(t,{type:'action',id:'confirm',token:stale});assert.equal(t.local.wallet.balance,'1280');
  t=confirm(t);assert.equal(t.local.wallet.balance,'1580');assert.equal(t.local.cards[0].periods[0].status,'settled');
  const result=structuredClone(t.local);t=confirm(t);assert.deepEqual(t.local,result);assert.equal(Object.keys(t.commands).length,1);
});
test('pending expense can be opened and returns to refreshed settlement',()=>{
  let t=choose(task('settlement-pending'),'period:food-sep');assert.equal(plan(t).stage,'pendingReview');
  t=choose(t,'reviewPending');assert.equal(plan(t).stage,'pendingDetail');t=act(t,'confirmPending');assert.equal(plan(t).stage,'confirm');assert.equal(t.local.cards[0].periods[0].pendingCount,0);
});
test('wish redemption needs actual purchase confirmation, reset after switching',()=>{
  let t=choose(task('redeem-wish'),'wish:headphones');t=check(t,'realPurchase');assert.equal(plan(t).ready,true);
  t=suspendReviewTask(t);assert.equal(plan(t).ready,false);t=check(t,'realPurchase');t=confirm(t);
  assert.equal(t.local.wallet.balance,'881');assert.equal(spent(t),'300');assert.equal(t.local.wishes[0].completed,true);
});
test('insufficient wish balance supports retaining the same purchase input',()=>{
  let t=choose(task('wish-insufficient'),'wish:headphones');assert.equal(plan(t).stage,'insufficient');
  t=choose(t,'pause');assert.equal(plan(t).stage,'paused');assert.equal(t.draft.actualAmount,'399');t=act(t,'resume');assert.equal(plan(t).stage,'insufficient');
});
test('multiple expenses are saved separately, never as the model combined 85',()=>{
  const {t}=walk(task('multiple'));assert.equal(t.splitCompleted.length,2);assert.equal(t.local.expenses.length,3);
  assert.deepEqual(t.local.expenses.slice(1).map(e=>e.amount),['35','50']);assert.equal(new Set(t.local.expenses.map(e=>e.id)).size,3);
});
test('read-only query and refusal have explicit completed states',()=>{
  let t=choose(task('query-budget'),'period:food-oct');const before=structuredClone(t.local);t=act(t,'finishReadOnly');assert.equal(plan(t).stage,'complete');assert.deepEqual(t.local,before);
  assert.equal(plan(task('out-of-scope')).stage,'finishedRefusal');assert.equal(plan(task('recommend-purchase')).stage,'finishedRefusal');
});
test('a retry cannot overwrite fields corrected by the user during manual takeover',()=>{
  let t=task('bad-output');assert.equal(t.draft.amount,undefined);t=act(t,'manual');t=reply(t,{amount:'30',currencyCode:'USD',merchant:'用户修正',occurredAt:'2026-10-13'});
  t.error='model_timeout';t=act(t,'retry');t=resolve(t);assert.equal(t.draft.amount,'30');assert.equal(t.draft.currencyCode,'USD');assert.equal(t.draft.merchant,'用户修正');
});
test('cancel, switch, restart and different task identity invalidate late results',()=>{
  let t=act(task('cancel-request'),'retry');const old=t.requestToken;t=act(t,'cancelRequest');
  t=advanceReviewTask(t,{type:'resolveRetry',requestToken:old});assert.equal(t.phase,'paused');assert.equal(t.draft.amount,undefined);
  t=act(task('timeout'),'retry');const request=t.requestToken;t=suspendReviewTask(t);t=advanceReviewTask(t,{type:'resolveRetry',requestToken:request});assert.equal(t.phase,'paused');
  const fresh=task('timeout');assert.notEqual(t.instanceID,fresh.instanceID);assert.deepEqual(advanceReviewTask(fresh,{type:'resolveRetry',requestToken:request}),fresh);
  assert.deepEqual(advanceReviewTask(fresh,{type:'reply',taskID:'another-task',values:{amount:'999'}}),fresh);
});
for(const id of ['save-failure','saved-interruption'])test(`idempotent recovery: ${id}`,()=>{
  let t=confirm(task(id));assert.equal(plan(t).stage,'saveFailure');assert.equal(t.local.expenses.length,id==='save-failure'?1:2);
  t=act(t,'retrySave');assert.equal(plan(t).stage,'complete');assert.equal(t.local.expenses.length,2);assert.equal(spent(t),'335');
  t=confirm(t);assert.equal(t.local.expenses.length,2);assert.equal(Object.keys(t.commands).length,1);
});
test('attachment retry only restores attachments after the same saved record',()=>{
  let t=confirm(task('attachment-partial'));const saved=structuredClone(t.local);assert.equal(plan(t).stage,'attachmentFailure');
  t=act(t,'retryAttachments');assert.deepEqual(t.local,saved);assert.equal(t.local.expenses.length,2);assert.equal(Object.keys(t.commands).length,1);
});
test('pause and resume preserve the saved-result and attachment recovery stages',()=>{
  for(const id of ['save-failure','saved-interruption','attachment-partial']){
    let t=confirm(task(id));const recoveryStage=plan(t).stage,commandID=t.commandID;t=act(t,'pause');t=act(t,'resume');assert.equal(plan(t).stage,recoveryStage);
    if(recoveryStage==='saveFailure'){t=act(t,'retrySave');assert.equal(t.commandID,commandID);}
  }
  let t=confirm(task('attachment-partial'));const saved=structuredClone(t.local);t=act(t,'finishWithoutAttachment');assert.equal(t.attachmentsPending,true);
  assert(plan(t).actions.some(a=>a.id==='retryAttachments'));t=act(t,'retryAttachments');assert.deepEqual(t.local,saved);assert.equal(t.attachmentsPending,false);
});
test('edited foreign amount invalidates the previous quote, then retries explicitly',()=>{
  let t=task('quote-expired');t=choose(t,plan(t).choices[0].id);assert.equal(plan(t).stage,'needsRate');
  t=act(t,'retryCaptureRate');assert.equal(plan(t).stage,'confirmRate');const stale=plan(t).token;
  t=act(t,'manual');t=reply(t,{amount:'3.60',currencyCode:'USD',merchant:'咖啡',occurredAt:'2026-10-14'});
  if(plan(t).choices.length)t=choose(t,plan(t).choices[0].id);assert.equal(plan(t).stage,'needsRate');
  t=advanceReviewTask(t,{type:'action',id:'confirm',token:stale});assert.equal(t.local.expenses.length,1);
  t=act(t,'retryCaptureRate');assert.equal(t.local.quote.convertedAmount,'25.78');t=act(t,'acceptCaptureRate');assert.equal(plan(t).stage,'complete');assert.equal(spent(t),'325.78');assert.equal(t.local.expenses[1].currencyCode,'USD');
});
test('retrospective selection stages an expense without writing until confirmed',()=>{
  let t=act(task('settled-period'),'openRetrospective');assert.equal(t.local.expenses.length,1);assert.equal(t.local.wallet.balance,'1280');
  t=choose(t,plan(t).choices[0].id);t=confirm(t);assert.equal(t.local.expenses.length,2);assert.equal(t.local.wallet.balance,'1245');assert.equal(t.local.expenses[1].periodID,'food-sep');
});
test('server-owned continuation retains the action while rejecting model forgery',async()=>{
  for(const intentType of ['settlePeriod','adjustPeriodAmount','deleteExpense','redeemWish','lateExpense']){
    const c=await interpret(requestFor({input:'处理这个操作'}),{complete:async()=>({intentType,amount:'38'})});
    assert.equal(c.requestedIntent,intentType);assert.equal(c.amount,'38');assert.equal(c.intentType,'needsClarification');
  }
  await assert.rejects(()=>interpret(requestFor({input:'午餐35元'}),{complete:async()=>({intentType:'capture',amount:'35',requestedIntent:'deleteExpense'})}),{code:'invalid_model_output'});
  assert(!SYSTEM_PROMPT.includes('"requestedIntent"'));
  assert(!SYSTEM_PROMPT.includes('"requiresDateReview"'));
  assert(!SYSTEM_PROMPT.includes('"requiresBudgetReview"'));
});
test('a compound budget question preserves date review before a fresh local choice',async()=>{
  const item=structuredClone(cases.find(c=>c.id==='card-entry'));
  const input='午餐35元，不是今天的，不计入餐饮预算';
  const raw=requestFor({input});raw.context.deviceTime=item.local.deviceTime;
  item.candidate=await interpret(raw,{complete:async()=>({intentType:'capture',amount:'35',currencyCode:'CNY',merchant:'午餐',budgetName:'餐饮',occurredAt:null})});
  item.input=input;item.local.userMessage=input;
  let t=createReviewTask(item);
  const before=t.local.expenses.length;
  assert.equal(t.draft.clarificationField,'budgetName');assert.equal(t.requiresDate,true);
  assert.equal(plan(t).fields[0].key,'occurredAt');assert.equal(t.local.expenses.length,before);
  t=reply(t,{occurredAt:'2026-10-13'});
  assert.equal(t.requiresDate,false);assert(!Object.hasOwn(t.draft,'requiresDateReview'));
  assert.equal(plan(t).stage,'chooseBudget');
  t=choose(t,plan(t).choices.find(c=>c.data.attribution?.kind==='unbudgeted').id);
  assert.equal(plan(t).stage,'ready');
  t=confirm(t);assert.equal(t.local.expenses.length,before+1);
  assert.equal(t.local.expenses.at(-1).periodID??null,null);
});
for (const suppliesAmount of [true, false]) test(`an amendment keeps date and budget review after choosing the same unfinished task (amount supplied: ${suppliesAmount})`,async()=>{
  const item=structuredClone(cases.find(c=>c.id==='correction'));
  const input='这笔日期改一下，不是今天的，不计入餐饮预算';
  const raw=requestFor({input});raw.context.deviceTime=item.local.deviceTime;
  item.candidate=await interpret(raw,{complete:async()=>({intentType:'capture',...(suppliesAmount?{amount:'35'}:{}),currencyCode:'CNY',merchant:'午餐',budgetName:'餐饮',occurredAt:item.local.deviceTime.timestamp})});
  item.input=input;item.local.userMessage=input;
  item.local.activeDraft={...item.local.activeDraft,amount:'35',budgetName:'餐饮',budgetID:'food',periodID:'food-oct',attachments:['synthetic-attachment']};
  item.local.entry={taskID:item.local.taskID,origin:'card',budgetID:'food'};
  let t=createReviewTask(item);const id=t.id,before=t.local.expenses.length;
  assert.equal(plan(t).stage,'chooseOperation');
  t=act(t,'editDraft');
  assert.equal(t.id,id);assert.equal(t.local.expenses.length,before);
  assert.equal(t.draft.budgetName,null);assert.equal(t.draft.budgetID,null);assert.equal(t.draft.periodID,null);
  assert.equal(t.draft.occurredAt,null);assert.equal(t.draft.requiresDateReview,true);assert.equal(t.draft.requiresBudgetReview,true);
  assert.equal(t.local.entry,undefined);assert.deepEqual(t.draft.attachments,['synthetic-attachment']);
  assert.equal(t.draft.amount,'35');assert.equal(t.draft.merchant,'午餐');assert.equal(t.input,input);
  assert.equal(plan(t).fields[0].key,'occurredAt');
  t=reply(t,{occurredAt:'2026-10-13'});assert.equal(plan(t).stage,'chooseBudget');
  t=choose(t,plan(t).choices.find(c=>c.data.attribution?.kind==='unbudgeted').id);
  assert.equal(plan(t).stage,'ready');assert(!Object.hasOwn(t.draft,'requiresBudgetReview'));
  assert.equal(t.local.expenses.length,before);
});
test('a recovered model response applies the same date and attribution review requirements',async()=>{
  const item=structuredClone(cases.find(c=>c.id==='card-entry'));
  const input='午餐35元，不是今天的，不计入餐饮预算';
  const raw=requestFor({input});raw.context.deviceTime=item.local.deviceTime;
  item.recoveryCandidate=await interpret(raw,{complete:async()=>({intentType:'capture',amount:'35',currencyCode:'CNY',merchant:'午餐',budgetName:'餐饮',occurredAt:null})});
  item.input=input;item.local.userMessage=input;item.candidate={};item.status=503;item.error='model_unavailable';
  let t=createReviewTask(item);t=resolve(act(t,'retry'));
  assert.equal(plan(t).fields[0].key,'occurredAt');assert.equal(t.local.entry,undefined);
  t=reply(t,{occurredAt:'2026-10-13'});assert.equal(plan(t).stage,'chooseBudget');
});
test('review decimal projections are exact across cents and large values',()=>{
  assert.equal(decimalAdd('0.1','0.2'),'0.3');assert.equal(decimalSubtract('1','0.01'),'0.99');assert.equal(decimalCompare('35.00','35'),0);
  assert.equal(decimalAdd('999999999999999999.99','0.01'),'1000000000000000000');assert.equal(demoConvert('3.60','7.16'),'25.78');
});
test('monthly date projection covers gaps, cross-month windows and short months',()=>{
  assert.deepEqual(demoMonthlyWindow({kind:'window',startDay:5,endDay:20},'2026-10-14'),{startDay:'2026-10-05',endDay:'2026-10-20'});
  assert.deepEqual(demoMonthlyWindow({kind:'window',startDay:5,endDay:20},'2026-10-24'),{startDay:'2026-11-05',endDay:'2026-11-20'});
  assert.deepEqual(demoMonthlyWindow({kind:'window',startDay:20,endDay:5},'2026-10-14'),{startDay:'2026-10-20',endDay:'2026-11-05'});
  assert.deepEqual(demoMonthlyWindow({kind:'cycle',startDay:31,endDay:31},'2028-03-01'),{startDay:'2028-02-29',endDay:'2028-03-30'});
});
test('foreign late expense converts into the original period before the wallet',()=>{
  let t=task('late-expense');Object.assign(t.local.expenses[0],{amount:'3.50',currencyCode:'USD'});
  t=choose(t,'period:food-sep');t=choose(t,'expense:late-lunch');assert.equal(plan(t).stage,'needsRate');assert.equal(t.local.wallet.balance,'1280');
  t=act(t,'retryConversion');assert.equal(plan(t).stage,'confirmRate');assert(plan(t).rows.some(r=>r[0]==='汇率'&&r[1].includes('7.16')));
  t=act(t,'acceptConversion');assert.equal(plan(t).stage,'confirm');t=confirm(t);
  assert.equal(t.local.cards[0].periods[0].spent,'725.06');assert.equal(t.local.wallet.balance,'1254.94');assert.equal(t.local.expenses[0].amount,'3.50');
});
test('known zero settlement differs from an unavailable exchange rate',()=>{
  let t=task('settlement-due');t.local.cards[0].currencyCode='CHF';t.local.cards[0].periods[0].spent='1000';t=choose(t,'period:food-sep');
  assert.equal(plan(t).stage,'confirm');t=check(t,'acknowledged');t=confirm(t);assert.equal(t.local.wallet.balance,'1280');
  t=task('settlement-due');t.local.cards[0].currencyCode='CHF';t=choose(t,'period:food-sep');t=act(t,'retryConversion');assert.equal(plan(t).stage,'needsRate');assert.equal(t.local.wallet.balance,'1280');
  t=act(t,'pause');assert.equal(plan(t).stage,'paused');t=act(t,'close');assert.equal(plan(t).stage,'closed');
});
test('missing original foreign allocation cannot be treated as same-currency money',()=>{
  let t=task('refund');t.local.expenses[0].currencyCode='USD';t=act(t,'showAllExpenses');
  // Explicit local selection is still required when the model currency differs.
  if(plan(t).choices.length)t=choose(t,plan(t).choices[0].id);
  assert.equal(plan(t).stage,'blocked');assert.equal(plan(t).ready,false);const before=structuredClone(t.local);t=act(t,'close');assert.deepEqual(t.local,before);
});
test('ordinary deletion never returns the already refunded part again',()=>{
  let t=task('delete-expense');t.local.expenses[0].refunded='10';assert.equal(plan(t).stage,'blocked');assert.equal(plan(t).ready,false);
});
test('destructive lookup uses the device calendar day and amount to avoid a similar record',()=>{
  const t=task('delete-expense');t.local.expenses.push({...t.local.expenses[0],id:'lunch-today',day:'2026-10-14'});
  const p=plan(t);assert.equal(p.stage,'confirm');assert.equal(p.effect.expense.id,'lunch-yesterday');
  t.draft.amount='36';assert.equal(plan(t).stage,'noMatch');
  t.input='删除上周午餐';assert.equal(plan(t).stage,'input');assert.equal(plan(t).fields[0].key,'searchDate');
});
test('editing lookup fields invalidates the selected original, and purchase edits reset consent',()=>{
  let t=choose(task('refund-multiple'),'expense:lunch-today');t=act(t,'manual');t=reply(t,{amount:'35',currencyCode:'CNY',merchant:'午餐',searchDate:'2026-10-13'});
  assert.equal(plan(t).effect.expense.id,'lunch-yesterday');
  t=choose(task('redeem-wish'),'wish:headphones');t=check(t,'realPurchase');t=act(t,'manual');t=reply(t,{actualAmount:'380',currencyCode:'CNY'});assert.equal(plan(t).ready,false);assert.equal(t.draft.actualAmount,'380');
});
test('selection and acknowledgement cannot be forged from unrelated steps',()=>{
  let t=task('out-of-scope');assert.deepEqual(act(t,'confirmPending'),t);assert.deepEqual(check(t,'realPurchase'),t);
  t=task('expense');assert.deepEqual(act(t,'acceptPending'),t);assert.equal(reply(t,{amount:'999'}).draft.amount,'35');
});
test('empty or invalidated objects offer a clear next step without execution',()=>{
  let t=task('query-budget');t.local.cards=[];assert.equal(plan(t).stage,'blocked');t=act(t,'toCreateBudget');assert.equal(t.operation,'createBudget');assert.equal(plan(t).fields[0].key,'name');
  t=choose(task('redeem-wish'),'wish:headphones');t.local.wishes[0].completed=true;assert.equal(plan(t).stage,'blocked');t=confirm(t);assert.equal(t.local.wallet.balance,'1280');
  t=choose(task('settlement-due'),'period:food-sep');t=check(t,'acknowledged');t.local.cards[0].deleted=true;assert.equal(plan(t).stage,'blocked');assert.equal(confirm(t).local.wallet.balance,'1280');
});
test('amount edit mirrors the current monthly period and future default rule',()=>{
  let t=task('adjust-budget');t.local.cards[0].periods.unshift({id:'old',startDay:'2026-09-01',endDay:'2026-09-30',status:'pendingSettlement',budgetAmount:'800',spent:'100',pendingCount:0});
  assert.deepEqual(plan(t).choices.map(c=>c.data.periodID),['food-oct']);t=choose(t,'period:food-oct');t=confirm(t);
  assert.equal(t.local.cards[0].defaultAmount,'1200');assert.equal(t.local.cards[0].periods[0].budgetAmount,'800');assert.equal(t.local.cards[0].periods[1].budgetAmount,'1200');
  t=choose(task('adjust-budget'),'period:food-oct');t.draft.newAmount='1.005';assert.equal(plan(t).stage,'input');assert.equal(t.draft.newAmount,'1.005');
});
