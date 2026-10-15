import { planCapture, calendarDay, moneyLabel, attributionBasis } from './capture-flow.mjs';
import { decimalAdd, decimalSubtract, decimalCompare, positiveMoney, demoConvert, demoMonthlyWindow } from './demo-values.mjs';
import { resolveConsumptionDay } from '../src/device-date.mjs';

const currencies = ['CNY','USD','HKD','EUR','JPY','GBP','CAD','AUD'];
const editableOperations = ['capture','createBudget','createWish','adjustPeriodAmount','deleteExpense','editExpense','redeemWish','refund'];
const copy = value => structuredClone(value);
const field = (key, label, type = 'text', value = '', options) => ({ key, label, type, value: value ?? '', options });
const choice = (id, label, detail = '', data = {}) => ({ id, label, detail, data });
const action = (id, label, primary = false) => ({ id, label, primary });
const currencyField = value => field('currencyCode','币种','select',value,currencies.map(code=>({value:code,label:code})));
const dayNow = t => calendarDay(t.local.deviceTime.timestamp,t.local.deviceTime.timeZoneIdentifier);
const findPeriod = (t,id) => t.local.cards.filter(card=>!card.deleted).flatMap(card=>card.periods.map(period=>({...period,budgetID:card.id,name:card.name,currencyCode:card.currencyCode,cycleType:card.cycleType}))).find(p=>p.id===id);
const editablePeriod = (p,card) => card.cycleType==='repeating'&&(card.periods.find(x=>x.status==='active')??card.periods.find(x=>x.status==='pendingSettlement'))?.id===p.id;
const budgetMoney = amount => positiveMoney(amount)&&(String(amount).split('.')[1]?.length??0)<=2;
const periodRows = p => [['预算卡',p.name],['所属周期',`${p.startDay} — ${p.endDay}`]];
const periodOptions = (t, predicate = ()=>true) => t.local.cards.filter(card=>!card.deleted).flatMap(card=>card.periods.filter(p=>predicate(p,card)).map(p=>choice(`period:${p.id}`,card.name,`${p.startDay} — ${p.endDay}${p.status==='settled'?' · 已结算':p.status==='pendingSettlement'?' · 待结算':''}`,{periodID:p.id})));
const walletAfter = (wallet, delta) => {
  let balance=wallet.balance,gap=wallet.recoveryGap;
  if(decimalCompare(delta,'0')>=0){const repair=decimalCompare(delta,gap)<0?delta:gap;gap=decimalSubtract(gap,repair);balance=decimalAdd(balance,decimalSubtract(delta,repair));}
  else {const spend=decimalSubtract('0',delta),paid=decimalCompare(spend,balance)<0?spend:balance;balance=decimalSubtract(balance,paid);gap=decimalAdd(gap,decimalSubtract(spend,paid));}
  return {...wallet,balance,recoveryGap:gap};
};
const walletRows = (before,after) => [['心愿余额',`${moneyLabel(before.balance,before.currencyCode)} → ${moneyLabel(after.balance,after.currencyCode)}`],...(after.recoveryGap!=='0'||before.recoveryGap!=='0'?[['待恢复差额',`${before.recoveryGap} → ${after.recoveryGap}`]]:[])];
const rates = {'USD:CNY':'7.16','EUR:CNY':'7.80','HKD:CNY':'0.92','JPY:CNY':'0.048','GBP:CNY':'9.20','CAD:CNY':'5.20','AUD:CNY':'4.75','CNY:USD':'0.14'};
let taskGeneration=0;

export function createReviewTask(item) {
  const candidate=copy(item.candidate??{});
  return {id:item.local.taskID,instanceID:++taskGeneration,itemID:item.id,input:item.input,operation:item.kind??candidate.requestedIntent??candidate.intentType,
    candidate,draft:copy(candidate),local:copy(item.local),answers:{},touched:[],history:[],version:0,phase:'active',
    requiresDate:candidate.clarificationField==='occurredAt',error:item.status!==200?item.error:null,
    recoveryCandidate:copy(item.recoveryCandidate),fault:item.fault,delay:item.delay??180,commands:{},faultUsed:false};
}
export function taskToken(t) { return JSON.stringify({id:t.id,instanceID:t.instanceID,version:t.version,operation:t.operation,draft:t.draft,local:t.local,answers:t.answers}); }
export function suspendReviewTask(original) {
  const t=copy(original);
  if(!['complete','closed'].includes(t.phase)){
    if(t.phase==='working'){t.pausedPhase='active';t.phase='paused';}
    t.requestToken=null;t.answers.realPurchase=false;t.answers.acknowledged=false;t.answers.acceptedConversions={};t.version++;
  }
  return t;
}

function conversion(t, amount, from, to, context) {
  if(from===to||decimalCompare(amount,'0')===0) return {amount};
  const q=t.answers.conversions?.[context];
  const valid=q&&q.sourceAmount===amount&&q.from===from&&q.to===to&&q.context===context
    && Date.parse(q.expiresAt)>Date.parse(t.local.deviceTime.timestamp)&&positiveMoney(q.amount);
  if(!valid) return {plan:{stage:'needsRate',prompt:`原币 ${moneyLabel(amount,from)} 已保留，需要换算为 ${to}。`,
    note:'缺少可用报价，尚未计入；可以重试，或保留输入稍后处理。',actions:[action('retryConversion','获取演示报价',true)],conversionRequest:{amount,from,to,context}}};
  const token=JSON.stringify(q);
  if(t.answers.acceptedConversions?.[context]!==token) return {plan:{stage:'confirmRate',prompt:`本次按 ${moneyLabel(q.amount,to)} 核对，可以吗？`,
    conversionContext:context,note:'固定虚构汇率，用于展示确认顺序；原币金额继续保留。',rows:[['原币',moneyLabel(amount,from)],['换算后',moneyLabel(q.amount,to)],['汇率',`1 ${from} = ${q.rate} ${to}`],['报价来源',q.source],['参考时间',q.asOf]],actions:[action('acceptConversion','确认此换算（演示）',true)]}};
  return {amount:q.amount};
}
function manualFields(t) {
  const d=t.draft;
  if(t.operation==='adjustPeriodAmount')return [field('newAmount','新的预算额度','text',d.newAmount??d.amount),currencyField(d.currencyCode??findPeriod(t,t.answers.periodID)?.currencyCode)];
  if(['createBudget'].includes(t.operation)) return [field('name','预算名称','text',d.name),field('amount','额度','text',d.amount),currencyField(d.currencyCode),
    field('cycleType','周期','select',d.cycleType,[{value:'repeating',label:'每月循环'},{value:'oneShot',label:'一次性'}])];
  if(t.operation==='redeemWish')return [field('actualAmount','实际购买金额','text',d.actualAmount??d.amount),currencyField(d.currencyCode)];
  if(t.operation==='createWish') return [field('name','心愿名称','text',d.name??d.merchant),field('amount','预计花费','text',d.amount),currencyField(d.currencyCode)];
  if(['refund','deleteExpense','editExpense'].includes(t.operation))return [field('amount',t.operation==='refund'?'退款金额':t.operation==='editExpense'?'更正金额':'原消费金额','text',d.amount),currencyField(d.currencyCode),field('merchant','原消费描述','text',d.merchant),field('searchDate','原消费日期（可选）','date',d.searchDate??t.local.expenses.find(e=>e.id===t.answers.expenseID)?.day??calendarDay(d.occurredAt,t.local.deviceTime.timeZoneIdentifier))];
  return [field('amount',t.operation==='refund'?'退款金额':'原币金额','text',d.amount),currencyField(d.currencyCode),field('merchant','消费描述','text',d.merchant),field('occurredAt','消费日期','date',calendarDay(d.occurredAt,t.local.deviceTime.timeZoneIdentifier)??dayNow(t))];
}

export function planReviewTask(t) {
  const base={stage:'input',prompt:'',note:'',fields:[],choices:[],actions:[],rows:[],ready:false,token:taskToken(t)};
  const make=(stage,prompt,extra={})=>({...base,stage,prompt,...extra});
  const ask=(key,label,type='text',options)=>make('input',label,{fields:[field(key,({amount:'金额',name:'名称',newAmount:'新额度',actualAmount:'实际购买金额',currencyCode:'币种',occurredAt:'消费日期',searchDate:'原消费日期',cycleType:'预算周期'})[key]??label,type,t.draft[key],options)],actions:[action('reply','继续',true)]});
  const confirm=(prompt,rows,effect,extra={})=>make('confirm',prompt,{rows,effect,ready:true,actions:[action('confirm',`确认${effect.label}（演示）`,true)],...extra});
  if(t.phase==='paused') return make('paused','输入已保留，可以继续当前任务。',{actions:[action('resume','继续处理',true),action('close','结束本次任务')]});
  if(t.phase==='working') return make('working','正在重新理解这句话…',{note:'可以取消，已输入的内容会保留。',actions:[action('cancelRequest','取消这次请求')]});
  if(t.phase==='complete'||t.phase==='closed') return make(t.phase,t.result?.title??'本次请求已结束。',{rows:t.result?.rows??[],actions:[...(t.phase==='complete'&&t.result?.undoable?[action('undo','撤销这次模拟')]:[]),...(t.attachmentsPending?[action('retryAttachments','补齐失败附件（演示）')]:[]),...(t.parentSplit?[action('continueSplit','继续处理下一笔',true)]:[]),action('restart','重新查看本例')]});
  if(t.phase==='attachmentFailure') return make('attachmentFailure','消费已模拟保存，还有1张附件未完成。',{rows:t.result.rows,note:'重试只处理附件，不会新增消费。',actions:[action('retryAttachments','重试失败附件（演示）',true),action('finishWithoutAttachment','先查看已保存记录')]});
  if(t.phase==='saveFailure') return make('saveFailure',t.commands[t.commandID]?'保存结果返回中断，正在保留这次提交。':'这次保存没有完成，输入和选择还在。',
    {recordSaved:!!t.commands[t.commandID],note:'重试使用同一个提交标识；如果已保存，只恢复结果。',actions:[action('retrySave','重试保存（演示）',true),...(!t.commands[t.commandID]?[action('manual','继续修改')]:[])]});
  if(t.error){
    const prompts={unauthorized:'连接认证已失效，输入已保留。',rate_limited:'请求次数较多，输入已保留。',model_timeout:'这次理解超时了，输入已保留。',invalid_model_output:'返回的内容无法使用，输入已保留。',model_unavailable:'暂时无法连接理解服务，输入已保留。'};
    return make('error',prompts[t.error]??'这次请求没有完成，输入已保留。',{note:t.recoveryFailure??'',actions:[action('retry',t.error==='unauthorized'?'恢复连接并重试（演示）':t.error==='rate_limited'?'模拟等待额度恢复后重试':'重新理解（演示）',true),action('manual','改为手动填写')]});
  }
  if(t.editing) return make('manual','继续修改这份输入。',{fields:manualFields(t),actions:[action('reply','保存修改并核对',true)]});
  if(['outOfScope','recommendPurchase'].includes(t.operation)) return make('finishedRefusal',t.operation==='recommendPurchase'?'我可以帮你整理心愿和预算，购买选择由你决定。':'这项请求超出了预算和心愿的范围，本次已结束。',
    {actions:[action('toCapture','开始记一笔'),action('toQuery','查看预算')]});
  const d=t.draft, today=dayNow(t);
  if(t.operation==='amendment') return make('chooseOperation',`你想把哪一项改成${d.amount?moneyLabel(d.amount,d.currencyCode):'这个金额'}？`,{choices:[...(t.local.activeDraft?[choice('editDraft','继续当前草稿','保留商家、日期及附件')]:[]),choice('editExpense','修改已保存的消费','先选择记录，再核对影响'),choice('adjustPeriodAmount','调整预算额度','先选择预算与周期')]});
  if(t.operation==='plannedWish') return make('chooseOperation','要把它加入心愿吗？',{choices:[choice('createWish','加入心愿','先核对名称、金额和币种'),choice('toCapture','更正：已经购买，记为普通消费'),choice('close','暂时不处理')]});
  if(t.operation==='split'){
    const items=t.splitItems??[{id:'lunch',merchant:'午餐',amount:'35',currencyCode:'CNY'},{id:'dinner',merchant:'晚餐',amount:'50',currencyCode:'CNY'}];
    const completed=t.splitCompleted??[];
    if(completed.length===items.length) return make('splitComplete',`已逐笔模拟完成${completed.length}笔消费。`,{actions:[action('close','结束本次任务',true)]});
    return make('split',completed.length?`已完成${completed.length}笔，继续核对哪一笔？`:'这里有两笔消费，先核对哪一笔？',{note:'各笔独立确认；不会采用模型合并出来的85元。',choices:items.filter(x=>!completed.includes(x.id)).map(x=>choice(`split:${x.id}`,`${x.merchant} ${moneyLabel(x.amount,x.currencyCode)}`,'逐笔核对',{item:x}))});
  }
  if(t.operation==='capture'){
    if(!positiveMoney(d.amount)) return ask('amount','这笔花了多少？');
    if(t.requiresDate) return ask('occurredAt','这笔是哪一天的消费？','date');
    if(!d.currencyCode) return ask('currencyCode','这笔用的是什么币种？','select',currencies.map(code=>({value:code,label:code})));
    const p=planCapture(d,t.local,t.answers);
    if(p.stage==='input') return ask(p.field,p.prompt,p.field==='occurredAt'?'date':'text');
    const rows=[['消费日期',p.day??'待核对'],['预算卡',p.card?.name??(p.attribution==='unbudgeted'?'未纳入预算':'待选择')],...(p.period?[['所属周期',`${p.period.startDay} — ${p.period.endDay}`]]:[])];
    if(p.attribution==='queued') rows.push(['处理方式','下周期队列，不计入旧期']);
    if(p.stage==='retrospective') return make('retrospective','这笔属于已结算周期，需要先核对原周期影响。',{rows,actions:[action('openRetrospective','核对原周期影响（演示）',true)]});
    if(p.stage==='needsRate') return make('needsRate',p.prompt,{rows,note:p.note,actions:[action('retryCaptureRate','重试换算（演示）',true),action('changeAttribution','重新选择归属')]});
    if(p.stage==='confirmRate') return make('confirmRate',p.prompt,{rows:[['原币',moneyLabel(d.amount,d.currencyCode)],['本次计入',moneyLabel(p.quote.convertedAmount,p.card.currencyCode)],['汇率',`1 ${d.currencyCode} = ${p.quote.rate} ${p.card.currencyCode}`],['报价来源','固定虚构报价'],['参考时间',p.quote.asOf],...rows],note:p.note,actions:[action('acceptCaptureRate','确认此换算并模拟保存',true)]});
    if(p.ready) return confirm(p.prompt,[['金额',moneyLabel(d.amount,d.currencyCode)],...rows],{kind:'capture',label:'记录',amount:d.amount,plan:p}, {stage:'ready',actions:[action('confirm','模拟保存',true),action('changeAttribution','重新选择归属')]});
    return make(p.stage,p.prompt,{rows,note:p.note,choices:p.options.map((o,i)=>choice(`attribution:${o.kind}:${o.id??i}`,o.kind==='budget'?`记到${o.label}`:o.label,o.detail,{attribution:o})),actions:[]});
  }
  if(t.operation==='createBudget'){
    if(!d.name?.trim()) return ask('name','预算卡叫什么？');
    if(!budgetMoney(d.amount)) return ask('amount','额度是多少？请填写大于0、最多两位小数的金额。');
    if(!d.currencyCode) return ask('currencyCode','预算使用什么币种？','select',currencies.map(code=>({value:code,label:code})));
    if(!d.cycleType) return ask('cycleType','这张卡是每月循环，还是一次性？','select',[{value:'repeating',label:'每月循环'},{value:'oneShot',label:'一次性'}]);
    let range;
    if(d.cycleType==='repeating'){
      const schedule=d.monthlySchedule??{kind:'cycle',startDay:1,endDay:31};
      range=demoMonthlyWindow(schedule,today);
      if(t.editingDates||!range) return make('input','选择每月适用的日期规则。',{note:'完整周期衔接到下次开始日前一天；指定区间允许间隔。',fields:[field('scheduleKind','月度规则','select',schedule.kind,[{value:'cycle',label:'完整周期'},{value:'window',label:'指定区间'}]),field('startDay','每月开始日','number',schedule.startDay),field('endDay','结束日（指定区间生效）','number',schedule.endDay)],actions:[action('reply','核对日期',true)]});
    }else{
      if(t.editingDates||!d.startDate||!d.endDate) return make('input','选择这次预算的开始和结束日期。',{fields:[field('startDate','开始日期','date',d.startDate??today),field('endDate','结束日期','date',d.endDate)],actions:[action('reply','核对日期',true)]});
      if(!calendarDay(d.startDate)||!calendarDay(d.endDate)||d.endDate<d.startDate) return make('input','结束日期需要在开始日期之后。',{fields:[field('startDate','开始日期','date',d.startDate),field('endDate','结束日期','date',d.endDate)],actions:[action('reply','重新核对',true)]});
      range={startDay:d.startDate,endDay:d.endDate};
    }
    return confirm('这些信息确认后创建预算卡。',[['名称',d.name],['额度',moneyLabel(d.amount,d.currencyCode)],['周期',d.cycleType==='repeating'?'每月循环':'一次性'],['实际覆盖',`${range.startDay} — ${range.endDay}`],...(range.startDay>today?[['状态','尚未开始']]:[])],{kind:'createBudget',label:'创建',range},{actions:[action('confirm','确认创建（演示）',true),action('editSchedule','调整日期规则')]});
  }
  if(['queryBudgetStatus','adjustPeriodAmount','settlePeriod','lateExpense'].includes(t.operation)){
    let p=findPeriod(t,t.answers.periodID);
    if(!p){
      const candidates=periodOptions(t,(p,card)=>t.operation==='adjustPeriodAmount'?editablePeriod(p,card):t.operation==='lateExpense'?p.status==='settled':true);
      if(!candidates.length)return make('blocked',t.local.cards.some(c=>!c.deleted)?'没有符合这次操作的预算周期。':'还没有预算卡，先创建一张再继续。',{actions:[...(t.operation==='lateExpense'?[]:[action('toCreateBudget','创建预算卡（演示）',true)]),action('close','结束本次任务')]});
      return make('selectPeriod',t.operation==='queryBudgetStatus'?'查看哪张预算卡的哪一期？':'请选择这次要处理的预算周期。',{choices:candidates});
    }
    const rows=periodRows(p);
    if(t.operation==='queryBudgetStatus') return make('queryResult','这期预算的情况在这里。',{rows:[...rows,['额度',moneyLabel(p.budgetAmount,p.currencyCode)],['本期已用',moneyLabel(p.spent,p.currencyCode)],['还能花',moneyLabel(decimalSubtract(p.budgetAmount,p.spent),p.currencyCode)],['待确认',`${p.pendingCount}笔`]],actions:[action('finishReadOnly','已查看',true)]});
    if(t.operation==='adjustPeriodAmount'){
      if(!editablePeriod(p,t.local.cards.find(c=>c.id===p.budgetID))) return make('blocked','这期已不可调整，请重新选择当前可编辑周期。',{actions:[action('changePeriod','重新选择周期',true)]});
      if(!budgetMoney(d.newAmount??d.amount)) return ask('newAmount','新的预算额度是多少？最多两位小数。');
      if(d.currencyCode&&d.currencyCode!==p.currencyCode)return make('input',`这张预算卡使用 ${p.currencyCode}，请核对额度币种。`,{fields:[field('currencyCode','额度币种','select',d.currencyCode,[{value:p.currencyCode,label:p.currencyCode}])],actions:[action('reply','继续核对',true)]});
      const next=d.newAmount??d.amount;
      if(decimalCompare(next,p.budgetAmount)===0&&decimalCompare(next,t.local.cards.find(c=>c.id===p.budgetID).defaultAmount??p.budgetAmount)===0)return make('blocked','额度没有变化，可以继续修改或结束。',{actions:[action('manual','继续修改',true),action('close','结束本次任务')]});
      return confirm('确认调整这期及以后新周期的默认额度？',[...rows,['原额度',moneyLabel(p.budgetAmount,p.currencyCode)],['新额度',moneyLabel(next,p.currencyCode)],['以后默认额度',moneyLabel(next,p.currencyCode)],['调整后还能花',moneyLabel(decimalSubtract(next,p.spent),p.currencyCode)]],{kind:'adjust',label:'调整',period:p,newAmount:next});
    }
    if(t.operation==='settlePeriod'){
      if(t.pendingReview){const pending=t.local.expenses.find(e=>e.periodID===p.id&&e.pending);return make('pendingDetail','核对这笔待确认消费是否属于本期。',{rows:[...rows,['消费',pending?`${pending.merchant} ${moneyLabel(pending.amount,pending.currencyCode)}`:'待确认记录'],['消费日期',pending?.day??'待补充'],['状态','待确认归属']],actions:[action('confirmPending','确认属于本期（演示）',true),action('backPending','返回结算')]});}
      if(p.status==='settled') return make('queryResult','这期已经结算，可以查看结果。',{rows:[...rows,['本期结余',moneyLabel(decimalSubtract(p.budgetAmount,p.spent),p.currencyCode)]],actions:[action('finishReadOnly','已查看',true),action('changePeriod','选择其他周期')]});
      const surplus=decimalSubtract(p.budgetAmount,p.spent);
      const cv=conversion(t,decimalCompare(surplus,'0')<0?decimalSubtract('0',surplus):surplus,p.currencyCode,t.local.wallet.currencyCode,`settle:${p.id}`);
      if(cv.plan) return make(cv.plan.stage,cv.plan.prompt,{...cv.plan,rows:[...rows,...(cv.plan.rows??[])]});
      const delta=decimalCompare(surplus,'0')<0?decimalSubtract('0',cv.amount):cv.amount,after=walletAfter(t.local.wallet,delta);
      if(p.endDay>=today) return make('estimate','这期还没到期，先看看按当前记录计算的预估。',{rows:[...rows,['当前预估结余',moneyLabel(surplus,p.currencyCode)],...walletRows(t.local.wallet,after)],note:'仅预估，不结算、不改心愿余额。',actions:[action('finishReadOnly','结束预估',true),action('changePeriod','选择其他周期')]});
      if(p.pendingCount>0&&!t.answers.reviewedPending) return make('pendingReview',`这期还有${p.pendingCount}笔待确认，先处理或接受当前记录。`,{rows,choices:[choice('reviewPending','核对这笔待确认','查看金额、归属及确认状态'),choice('acceptPending','按当前已有记录继续','下一步仍需明确确认结算影响')]});
      return confirm('确认结算这个周期？',[...rows,['本期结余',moneyLabel(surplus,p.currencyCode)],['待确认',`${p.pendingCount}笔，按当前已有记录核对`],...walletRows(t.local.wallet,after)],{kind:'settle',label:'结算',period:p,walletAfter:after},{fields:[field('acknowledged','已检查待确认与数据覆盖','checkbox',t.answers.acknowledged)],ready:!!t.answers.acknowledged,actions:[action('confirm','确认结算（演示）',true)]});
    }
    const candidates=[...t.local.expenses,...(t.stagedExpense?[t.stagedExpense]:[])];
    let expense=candidates.find(x=>x.id===t.answers.expenseID);
    if(!expense) return make('selectExpense','选择需要补入这个周期的消费。',{rows,choices:candidates.filter(x=>!x.periodID&&!x.deleted).map(x=>choice(`expense:${x.id}`,`${x.merchant} ${moneyLabel(x.amount,x.currencyCode)}`,x.day,{expenseID:x.id}))});
    if(expense.day<p.startDay||expense.day>p.endDay) return make('blocked','这笔消费日期不属于所选周期，请重新选择。',{actions:[action('changePeriod','重新选择周期',true)]});
    const budget=conversion(t,expense.amount,expense.currencyCode,p.currencyCode,`lateBudget:${expense.id}:${p.id}`);
    if(budget.plan)return make(budget.plan.stage,budget.plan.prompt,budget.plan);
    const wallet=conversion(t,budget.amount,p.currencyCode,t.local.wallet.currencyCode,`lateWallet:${expense.id}:${p.id}`);
    if(wallet.plan)return make(wallet.plan.stage,wallet.plan.prompt,wallet.plan);
    const after=walletAfter(t.local.wallet,decimalSubtract('0',wallet.amount));
    return confirm('补入原周期前，请核对影响。',[...rows,['消费',`${expense.merchant} ${moneyLabel(expense.amount,expense.currencyCode)}`],['本次计入',moneyLabel(budget.amount,p.currencyCode)],['修正后已用',moneyLabel(decimalAdd(p.spent,budget.amount),p.currencyCode)],...walletRows(t.local.wallet,after)] ,{kind:'late',label:'补入',period:p,expense,budgetAmount:budget.amount,walletAfter:after});
  }
  if(['createWish','redeemWish'].includes(t.operation)){
    if(t.operation==='createWish'){
      if(!d.name?.trim()&&!d.merchant?.trim()) return ask('name','心愿叫什么？');
      if(!positiveMoney(d.amount)) return ask('amount','预计花费是多少？');
      if(!d.currencyCode) return ask('currencyCode','预计使用什么币种？','select',currencies.map(code=>({value:code,label:code})));
      return confirm('把它加入心愿？',[['名称',d.name??d.merchant],['预计花费',moneyLabel(d.amount,d.currencyCode)],['心愿余额','创建心愿不会扣减余额']],{kind:'createWish',label:'添加心愿'});
    }
    const wishes=t.local.wishes.filter(x=>!x.completed),wish=wishes.find(x=>x.id===t.answers.wishID);
    if(!wishes.length)return make('blocked','还没有待兑现的心愿。',{actions:[action('newWish','添加心愿（演示）',true),action('close','结束本次任务')]});
    if(!wish) return make('selectWish','兑现哪个心愿？',{choices:wishes.map(x=>choice(`wish:${x.id}`,x.name,moneyLabel(x.amount,x.currencyCode),{wishID:x.id}))});
    if(!positiveMoney(d.actualAmount??d.amount)) return ask('actualAmount','实际购买金额是多少？');
    if(!d.currencyCode) return ask('currencyCode','实际购买用了什么币种？','select',currencies.map(code=>({value:code,label:code})));
    const amount=d.actualAmount??d.amount,cv=conversion(t,amount,d.currencyCode,t.local.wallet.currencyCode,`wish:${wish.id}`);
    if(cv.plan) return make(cv.plan.stage,cv.plan.prompt,cv.plan);
    if(decimalCompare(cv.amount,t.local.wallet.balance)>0||decimalCompare(t.local.wallet.recoveryGap,'0')>0) return make('insufficient','心愿余额暂不足以完成这次兑现。',{rows:[['实际购买',moneyLabel(amount,d.currencyCode)],['心愿余额',moneyLabel(t.local.wallet.balance,t.local.wallet.currencyCode)]],choices:[choice('toCapture','改为普通消费','重新核对预算归属'),choice('pause','保留输入，稍后兑现')]});
    const after={...t.local.wallet,balance:decimalSubtract(t.local.wallet.balance,cv.amount)};
    return confirm('确认这次真实购买并兑现心愿？',[['心愿',wish.name],['实际购买',moneyLabel(amount,d.currencyCode)],...walletRows(t.local.wallet,after)],{kind:'redeem',label:'兑现',wish,walletAfter:after},{fields:[field('realPurchase','我已真实购买','checkbox',t.answers.realPurchase)],ready:!!t.answers.realPurchase,actions:[action('confirm','确认兑现（演示）',true)]});
  }
  if(['refund','deleteExpense','editExpense'].includes(t.operation)){
    const all=t.local.expenses.filter(x=>!x.deleted&&x.kind==='purchase');
    const reference=resolveConsumptionDay(t.input,t.local.deviceTime);
    if(reference.kind==='clarify'&&!d.searchDate&&!t.answers.showAllExpenses)return ask('searchDate','要处理哪一天的原消费？','date');
    const searchDate=d.searchDate??(reference.kind==='resolved'?calendarDay(reference.occurredAt,t.local.deviceTime.timeZoneIdentifier):calendarDay(d.occurredAt,t.local.deviceTime.timeZoneIdentifier));
    const matches=all.filter(x=>t.answers.showAllExpenses||((!d.merchant||x.merchant.includes(d.merchant))&&(!searchDate||x.day===searchDate)&&(!d.currencyCode||x.currencyCode===d.currencyCode)&&(t.operation!=='deleteExpense'||!positiveMoney(d.amount)||decimalCompare(x.amount,d.amount)===0)));
    let expense=all.find(x=>x.id===t.answers.expenseID);
    if(!expense&&matches.length===1) expense=matches[0];
    if(!expense) return make(matches.length?'selectExpense':'noMatch',matches.length?'有多笔符合，请选择原消费。':'没找到对应消费，可以补充日期或手动选择。',
      {fields:matches.length?[]:[field('searchDate','原消费日期（可选）','date',d.searchDate)],choices:matches.map(x=>choice(`expense:${x.id}`,`${x.merchant} ${moneyLabel(x.amount,x.currencyCode)}`,`${x.day} · ${findPeriod(t,x.periodID)?.name??'未纳入预算'}`,{expenseID:x.id})),actions:matches.length?[]:[action('reply','继续查找',true),action('showAllExpenses','手动选择原消费'),action('close','结束本次查找')]});
    const p=findPeriod(t,expense.periodID),rows=[['原消费',`${expense.merchant} ${moneyLabel(expense.amount,expense.currencyCode)}`],['消费日期',expense.day],...(p?periodRows(p):[['归属','未纳入预算']])];
    if(p&&expense.currencyCode!==p.currencyCode&&!positiveMoney(expense.budgetAmount))return make('blocked','原记录缺少预算币计入依据，不能准确计算这次影响。',{rows,note:'原记录和本次输入保留；需要补齐实际入账或已确认的原换算依据。',actions:[action('close','保留记录并结束本次处理',true)]});
    const originalBudgetAmount=p?(expense.currencyCode===p.currencyCode?expense.amount:expense.budgetAmount):null;
    if(t.operation!=='refund'&&positiveMoney(expense.refunded??'0'))return make('blocked','这笔已有退款，普通删除或修改会重复返还已退部分。',{rows,actions:[action('close','保留记录并结束本次处理',true)]});
    if(t.operation==='deleteExpense'){
      if(p?.status==='settled') return make('blocked','这笔已参与结算，需要核对原周期影响，不能普通删除。',{rows,actions:[action('close','保留原记录并结束',true)]});
      return confirm('确认删除这条录错的消费？',[...rows,...(p?[['删除后已用',moneyLabel(decimalSubtract(p.spent,originalBudgetAmount),p.currencyCode)]]:[])],{kind:'delete',label:'删除',expense,period:p,budgetDelta:originalBudgetAmount?decimalSubtract('0',originalBudgetAmount):'0'});
    }
    if(t.operation==='editExpense'){
      const next=d.newAmount??d.amount;
      if(!positiveMoney(next)) return ask('newAmount','更正后的金额是多少？');
      if(p?.status==='settled') return make('blocked','这笔已参与结算，本次先保留原记录，修改需要另行核对追溯影响。',{rows,actions:[action('close','保留输入并结束',true)]});
      if(d.currencyCode&&d.currencyCode!==expense.currencyCode)return make('input',`请按原记录的 ${expense.currencyCode} 核对更正金额。`,{fields:[field('currencyCode','更正币种','select',d.currencyCode,[{value:expense.currencyCode,label:expense.currencyCode}])],actions:[action('reply','继续核对',true)]});
      const nextBudget=p?conversion(t,next,expense.currencyCode,p.currencyCode,`edit:${expense.id}`):{amount:next};
      if(nextBudget.plan)return make(nextBudget.plan.stage,nextBudget.plan.prompt,nextBudget.plan);
      const delta=p?decimalSubtract(nextBudget.amount,originalBudgetAmount):'0';
      return confirm('核对这条消费的金额修改。',[...rows,['更正金额',moneyLabel(next,expense.currencyCode)],...(p?[['更正后已用',moneyLabel(decimalAdd(p.spent,delta),p.currencyCode)]]:[])],{kind:'editExpense',label:'修改',expense,period:p,newAmount:next,budgetAmount:nextBudget.amount,budgetDelta:delta});
    }
    if(!d.currencyCode)return ask('currencyCode','本次退款使用什么币种？','select',currencies.map(code=>({value:code,label:code})));
    if(!positiveMoney(d.amount))return ask('amount','本次退回多少？');
    const originalRefund=conversion(t,d.amount,d.currencyCode,expense.currencyCode,`refundOriginal:${expense.id}`);
    if(originalRefund.plan)return make(originalRefund.plan.stage,originalRefund.plan.prompt,originalRefund.plan);
    const amount=originalRefund.amount,remaining=decimalSubtract(expense.amount,expense.refunded??'0');
    if(!positiveMoney(amount)||decimalCompare(amount,remaining)>0) return make('input',`这笔最多可退${moneyLabel(remaining,expense.currencyCode)}，本次退回多少？`,{rows,fields:[field('amount','退款金额','text',amount)],actions:[action('reply','重新核对退款',true)]});
    if(p&&expense.currencyCode!==p.currencyCode)return make('blocked','这笔跨币种退款需要核对原预算币的退款入账金额。',{rows,note:'本例没有该依据；不会用当前汇率改写原消费。',actions:[action('close','保留记录并结束本次处理',true)]});
    const wallet=p?.status==='settled'?conversion(t,amount,p.currencyCode,t.local.wallet.currencyCode,`refundWallet:${expense.id}`):{amount};
    if(wallet.plan)return make(wallet.plan.stage,wallet.plan.prompt,wallet.plan);
    const after=p?.status==='settled'?walletAfter(t.local.wallet,wallet.amount):null;
    return confirm(`确认这笔${expense.merchant}退回${moneyLabel(amount,expense.currencyCode)}？`,[...rows,['本次退款',moneyLabel(d.amount,d.currencyCode)],['退款后未退金额',moneyLabel(decimalSubtract(remaining,amount),expense.currencyCode)],...(p?[['修正后本期已用',moneyLabel(decimalSubtract(p.spent,amount),p.currencyCode)]]:[]),...(after?walletRows(t.local.wallet,after):[])],{kind:'refund',label:'退款',expense,period:p,amount,budgetDelta:decimalSubtract('0',amount),walletAfter:after});
  }
  return make('finishedRefusal','当前任务暂不能直接处理，输入已保留。',{actions:[action('manual','改为手动填写'),action('close','结束本次任务')]});
}

function quoteFor(t, amount, from, to, context) {
  const rate=rates[`${from}:${to}`]; if(!rate) return null;
  return {sourceAmount:amount,from,to,amount:demoConvert(amount,rate),context,rate,asOf:t.local.deviceTime.timestamp,expiresAt:new Date(Date.parse(t.local.deviceTime.timestamp)+900_000).toISOString(),source:'固定虚构报价'};
}
function applyReply(t,values){
  const allowed=['amount','actualAmount','newAmount','currencyCode','merchant','name','occurredAt','startDate','endDate','cycleType','searchDate','scheduleKind','startDay','endDay'];
  if(['refund','deleteExpense','editExpense'].includes(t.operation)&&['merchant','searchDate',...(t.operation==='deleteExpense'?['amount']:[])].some(key=>Object.hasOwn(values??{},key)&&String(values[key]).trim()!==String(t.draft[key]??''))){delete t.answers.expenseID;delete t.answers.showAllExpenses;}
  for(const [key,raw] of Object.entries(values??{})){
    if(!allowed.includes(key)) continue;
    let value=String(raw).trim();
    if(['amount','newAmount','actualAmount'].includes(key)){
      const match=value.match(/^([0-9]+(?:\.[0-9]+)?)\s*(元|人民币|美元|USD|CNY)?$/i);
      if(match){value=match[1];if(match[2]){t.draft.currencyCode=/美元|USD/i.test(match[2])?'USD':'CNY';t.touched.push('currencyCode');}}
    }
    t.draft[key]=key==='currencyCode'?value.toUpperCase():value;
    if(key==='occurredAt'&&calendarDay(value)) t.requiresDate=false;
    t.touched.push(key);
  }
  if(['scheduleKind','startDay','endDay'].some(key=>Object.hasOwn(values??{},key))) t.draft.monthlySchedule={kind:t.draft.scheduleKind??t.draft.monthlySchedule?.kind??'cycle',startDay:Number(t.draft.startDay??t.draft.monthlySchedule?.startDay??1),endDay:Number(t.draft.endDay??t.draft.monthlySchedule?.endDay??31)};
  if(!t.commands[t.commandID])t.commandID=null;
  t.version++;t.answers.acceptedConversions={};t.answers.realPurchase=false;t.answers.acknowledged=false;t.editing=false;t.editingDates=false;t.lastError=null;
}
function effectResult(t,p){
  const e=copy(p.effect),before=copy(t.local),id=`${t.id}:entity`,rows=p.rows;
  if(e.kind==='capture'){
    const target=e.plan,period=findPeriod(t,target.period?.id),amount=target.quote?.convertedAmount??e.amount;
    if(period&&target.attribution!=='queued')t.local.cards.find(c=>c.id===period.budgetID).periods.find(x=>x.id===period.id).spent=decimalAdd(period.spent,amount);
    t.local.expenses.push({id,merchant:t.draft.merchant??'消费',amount:e.amount,currencyCode:t.draft.currencyCode,day:target.day,budgetID:target.card?.id,periodID:target.period?.id,budgetAmount:amount,kind:'purchase',refunded:'0'});
  }
  if(e.kind==='adjust'){const card=t.local.cards.find(c=>c.id===e.period.budgetID);card.defaultAmount=e.newAmount;card.periods.find(x=>x.id===e.period.id).budgetAmount=e.newAmount;}
  if(e.kind==='settle')t.local.cards.find(c=>c.id===e.period.budgetID).periods.find(x=>x.id===e.period.id).status='settled';
  if(e.kind==='delete')t.local.expenses.find(x=>x.id===e.expense.id).deleted=true;
  if(e.kind==='editExpense'){const expense=t.local.expenses.find(x=>x.id===e.expense.id);expense.amount=e.newAmount;expense.budgetAmount=e.budgetAmount;}
  if(e.kind==='refund')t.local.expenses.find(x=>x.id===e.expense.id).refunded=decimalAdd(e.expense.refunded??'0',e.amount);
  if(['refund','delete','editExpense','late'].includes(e.kind)&&e.period){
    const amount=e.kind==='late'?e.budgetAmount:e.budgetDelta;
    t.local.cards.find(c=>c.id===e.period.budgetID).periods.find(x=>x.id===e.period.id).spent=decimalAdd(e.period.spent,amount);
  }
  if(e.kind==='late'){let expense=t.local.expenses.find(x=>x.id===e.expense.id);if(!expense){expense=copy(e.expense);t.local.expenses.push(expense);}expense.periodID=e.period.id;expense.budgetID=e.period.budgetID;expense.budgetAmount=e.budgetAmount;}
  if(e.walletAfter)t.local.wallet=e.walletAfter;
  if(e.kind==='redeem')t.local.wishes.find(x=>x.id===e.wish.id).completed=true;
  if(e.kind==='createWish')t.local.wishes.push({id,name:t.draft.name??t.draft.merchant,amount:t.draft.amount,currencyCode:t.draft.currencyCode});
  if(e.kind==='createBudget')t.local.cards.push({id,name:t.draft.name,defaultAmount:t.draft.amount,currencyCode:t.draft.currencyCode,cycleType:t.draft.cycleType,periods:[{id:`${id}:period`,...e.range,status:'active',budgetAmount:t.draft.amount,spent:'0',pendingCount:0}]});
  return {title:`已模拟${e.label}。`,rows,entityID:id,undoable:['capture','createWish','createBudget','delete','editExpense','adjust'].includes(e.kind),before};
}
function commitTask(t,providedToken){
  if(t.phase==='complete')return;
  if(t.commandID&&t.commands[t.commandID]){t.result=t.commands[t.commandID];t.phase=t.fault==='attachments'?'attachmentFailure':'complete';return;}
  const p=planReviewTask(t);
  if(!p.ready||providedToken!==p.token){t.lastError='信息已变化，请重新核对。';return;}
  t.commandID??=`${t.id}:command:${t.version}`;
  if(t.fault==='saveBefore'&&!t.faultUsed){t.faultUsed=true;t.phase='saveFailure';return;}
  t.result=effectResult(t,p);t.commands[t.commandID]=t.result;
  if(t.fault==='saveAfter'&&!t.faultUsed){t.faultUsed=true;t.phase='saveFailure';return;}
  t.attachmentsPending=t.fault==='attachments';t.phase=t.attachmentsPending?'attachmentFailure':'complete';
}

export function advanceReviewTask(original,event){
  const t=copy(original);
  if(event.taskID&&event.taskID!==t.id)return t;
  if(event.instanceID&&event.instanceID!==t.instanceID)return t;
  const currentPlan=planReviewTask(t);
  if(event.token&&event.token!==currentPlan.token){t.lastError='信息已变化，请重新核对。';return t;}
  if(event.type==='reply'){if(currentPlan.fields.length)applyReply(t,Object.fromEntries(Object.entries(event.values??{}).filter(([key])=>currentPlan.fields.some(f=>f.key===key&&f.type!=='checkbox'))));return t;}
  if(event.type==='check'){
    if(!currentPlan.fields.some(f=>f.key===event.key&&f.type==='checkbox'))return t;
    t.answers[event.key]=!!event.value;t.version++;return t;
  }
  if(event.type==='choose'){
    const p=planReviewTask(t),selected=p.choices.find(c=>c.id===event.id);if(!selected)return t;
    const data=selected.data;
    if(data.attribution)t.answers.attribution={...data.attribution,basis:attributionBasis(t.draft,t.local)};
    else if(data.periodID)t.answers.periodID=data.periodID;
    else if(data.expenseID)t.answers.expenseID=data.expenseID;
    else if(data.wishID)t.answers.wishID=data.wishID;
    else if(data.item){t.parentSplit={items:t.splitItems??[{id:'lunch',merchant:'午餐',amount:'35',currencyCode:'CNY'},{id:'dinner',merchant:'晚餐',amount:'50',currencyCode:'CNY'}],completed:t.splitCompleted??[],currentID:data.item.id};t.operation='capture';t.draft={intentType:'capture',...data.item};t.answers={};t.version++;t.id=`${t.local.taskID}:${data.item.id}`;}
    else return advanceReviewTask(t,{type:'action',id:selected.id});
    return t;
  }
  if(event.type==='resolveRetry'){
    if(t.phase!=='working'||t.requestToken!==event.requestToken)return t;
    t.phase='active';t.error=null;t.requestToken=null;
    const candidate=t.recoveryCandidate;
    if(!candidate){t.error='model_unavailable';t.recoveryFailure='重试仍未完成，可以改为手动填写。';return t;}
    for(const [key,value]of Object.entries(candidate))if(value!=null&&!t.touched.includes(key))t.draft[key]=value;
    t.operation=candidate.requestedIntent??candidate.intentType;t.draft.intentType=t.operation;t.version++;return t;
  }
  if(event.type!=='action')return t;
  const id=event.id;
  const isGlobal=id==='pause'&&!['complete','closed','working'].includes(t.phase)||id==='manual'&&editableOperations.includes(t.operation)&&!['complete','closed','saveFailure','attachmentFailure','working'].includes(t.phase);
  if(!isGlobal&&!currentPlan.actions.some(a=>a.id===id)&&!currentPlan.choices.some(c=>c.id===id))return t;
  if(id==='pause'||id==='cancelRequest'){t.pausedPhase=t.phase==='working'?'active':t.phase;t.phase='paused';t.requestToken=null;t.version++;return t;}
  if(id==='resume'){t.phase=t.pausedPhase??'active';t.answers.realPurchase=false;t.answers.acknowledged=false;return t;}
  if(id==='close'){t.phase='closed';t.result={title:t.splitCompleted?.length?`本次已逐笔模拟完成${t.splitCompleted.length}笔，任务已结束。`:Object.keys(t.commands).length?'本次等待已结束，已模拟保存的记录保留。':'本次任务已结束，没有继续写入。',rows:[]};t.requestToken=null;return t;}
  if(id==='manual'){t.error=null;t.phase='active';t.editing=true;return t;}
  if(id==='retry'){t.phase='working';t.version++;t.requestToken=`${t.id}:${t.instanceID}:request:${t.version}`;return t;}
  if(id==='confirm'){commitTask(t,event.token);return t;}
  if(id==='retrySave'){
    if(t.commands[t.commandID]){commitTask(t);return t;}
    t.phase='active';const p=planReviewTask(t);commitTask(t,p.token);return t;
  }
  if(id==='retryAttachments'||id==='finishWithoutAttachment'){t.attachmentsPending=id!=='retryAttachments';t.phase='complete';t.result={...t.result,title:id==='retryAttachments'?'附件已模拟补齐，消费没有重复新增。':'消费已保存，附件可稍后补齐。'};return t;}
  if(id==='undo'&&t.result?.undoable){t.local=t.result.before;t.phase='active';t.result=null;t.commands={};t.commandID=null;t.attachmentsPending=false;t.version++;t.lastError='已撤销本次模拟，输入保留。';return t;}
  if(id==='finishReadOnly'){t.phase='complete';t.result={title:t.operation==='settlePeriod'?'预估已查看，未执行结算。':'已查看预算。',rows:planReviewTask(original).rows};return t;}
  if(id==='editSchedule'){t.editingDates=true;return t;}
  if(id==='changePeriod'){delete t.answers.periodID;t.answers.acknowledged=false;return t;}
  if(id==='reviewPending'){t.pendingReview=true;return t;}
  if(id==='backPending'){t.pendingReview=false;return t;}
  if(id==='acceptPending'){t.answers.reviewedPending=true;return t;}
  if(id==='confirmPending'){const p=findPeriod(t,t.answers.periodID);if(p){t.local.cards.find(c=>c.id===p.budgetID).periods.find(x=>x.id===p.id).pendingCount=0;for(const e of t.local.expenses.filter(e=>e.periodID===p.id))e.pending=false;}t.pendingReview=false;t.answers.reviewedPending=true;return t;}
  if(id==='showAllExpenses'){t.answers.showAllExpenses=true;return t;}
  if(id==='changeAttribution'){t.draft.budgetName=null;t.local.userMessage='';delete t.local.entry;delete t.answers.attribution;t.local.quote=null;return t;}
  if(id==='openRetrospective'){
    const p=planCapture(t.draft,t.local,t.answers);t.operation='lateExpense';t.answers={periodID:p.period.id};t.stagedExpense={id:`${t.id}:late`,merchant:t.draft.merchant??'消费',amount:t.draft.amount,currencyCode:t.draft.currencyCode,day:p.day,kind:'purchase',refunded:'0'};return t;
  }
  if(id==='retryCaptureRate'){
    const p=planCapture(t.draft,t.local,t.answers),q=quoteFor(t,t.draft.amount,t.draft.currencyCode,p.card?.currencyCode,`capture:${p.period?.id}`);
    if(q)t.local.quote={sourceAmount:q.sourceAmount,sourceCurrency:q.from,targetCurrency:q.to,convertedAmount:q.amount,rate:q.rate,budgetID:p.card.id,periodID:p.period.id,asOf:t.local.deviceTime.timestamp,expiresAt:q.expiresAt};
    else t.lastError='此币种组合暂时没有演示报价，原币已保留。';return t;
  }
  if(id==='acceptCaptureRate'){
    const p=planCapture(t.draft,t.local,t.answers);if(p.stage!=='confirmRate')return t;
    t.answers.quoteToken=p.quoteToken;commitTask(t,planReviewTask(t).token);return t;
  }
  if(id==='retryConversion'){
    const p=planReviewTask(t),q=p.conversionRequest;
    if(q)t.answers.conversions={...t.answers.conversions,[q.context]:quoteFor(t,q.amount,q.from,q.to,q.context)};
    return t;
  }
  if(id==='acceptConversion'){const p=planReviewTask(t),key=p.conversionContext,q=t.answers.conversions?.[key];if(q)t.answers.acceptedConversions={...t.answers.acceptedConversions,[key]:JSON.stringify(q)};return t;}
  if(id==='continueSplit'&&t.parentSplit){
    t.splitCompleted=[...t.parentSplit.completed,t.parentSplit.currentID];t.splitItems=t.parentSplit.items;t.parentSplit=null;t.id=t.local.taskID;t.operation='split';t.phase='active';t.answers={};t.result=null;t.commands={};t.commandID=null;t.version++;return t;
  }
  if(id==='editDraft'){t.draft={...t.local.activeDraft,amount:t.draft.amount,currencyCode:t.draft.currencyCode??t.local.activeDraft.currencyCode};t.operation='capture';t.answers={};t.version++;return t;}
  if(['editExpense','adjustPeriodAmount'].includes(id)){t.operation=id;t.draft.newAmount=t.draft.amount;t.answers={};t.version++;return t;}
  if(id==='createWish'){t.operation='createWish';t.draft.name=t.draft.name??t.draft.merchant;t.answers={};return t;}
  if(id==='newWish'||id==='toCreateBudget'){t.operation=id==='newWish'?'createWish':'createBudget';t.draft={};t.answers={};t.version++;return t;}
  if(id==='toCapture'){t.operation='capture';t.draft.intentType='capture';t.error=null;t.answers={};t.phase='active';t.editing=!positiveMoney(t.draft.amount??t.draft.actualAmount);if(t.draft.actualAmount)t.draft.amount=t.draft.actualAmount;return t;}
  if(id==='toQuery'){t.operation='queryBudgetStatus';t.phase='active';t.answers={};return t;}
  return t;
}
