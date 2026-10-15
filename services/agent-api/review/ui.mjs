import { createReviewTask, planReviewTask, advanceReviewTask, suspendReviewTask } from './task-flow.mjs';

const cases=JSON.parse(document.getElementById('review-data').textContent);
const $=id=>document.getElementById(id);
const tasks=new Map();
let activeCase;
const node=(tag,text,className)=>{const el=document.createElement(tag);if(text!==undefined)el.textContent=text;if(className)el.className=className;return el;};
function current(){return tasks.get(activeCase);}
function choose(item){
  if(activeCase)tasks.set(activeCase,suspendReviewTask(current()));
  activeCase=item.id;
  if(!tasks.has(activeCase))tasks.set(activeCase,createReviewTask(item));
  $('mobile-cases').value=item.id;
  document.querySelectorAll('.case-button').forEach(el=>el.setAttribute('aria-pressed',String(el.dataset.case===item.id)));
  history.replaceState(null,'','#'+item.id);render();
}
function dispatch(event){
  const previous=current(),before=planReviewTask(previous);
  if(event.taskID&&event.taskID!==previous.id||event.instanceID&&event.instanceID!==previous.instanceID)return;
  if(event.id==='restart')tasks.set(activeCase,createReviewTask(cases.find(c=>c.id===activeCase)));
  else{
    const next=advanceReviewTask(previous,{...event,taskID:event.taskID??previous.id,instanceID:event.instanceID??previous.instanceID});
    if(event.type==='reply'){
      next.formValues={};
      const fields=before.fields.filter(f=>f.type!=='checkbox');
      const visible=fields.map(f=>`${fields.length>1?f.label+'：':''}${f.options?.find(o=>o.value===event.values?.[f.key])?.label??event.values?.[f.key]??''}`).join('，');
      next.history=[...previous.history,{role:'assistant',text:before.prompt},{role:'user',text:visible}].slice(-6);
    }
    if(event.type==='choose'){
      const selected=before.choices.find(c=>c.id===event.id);
      if(selected)next.history=[...previous.history,{role:'user',text:selected.label}].slice(-6);
    }
    tasks.set(activeCase,next);
  }
  render();
  if(event.type==='reply'){const first=planReviewTask(current()).fields[0];if(first)$('reply-'+first.key)?.focus();}
  const task=current();
  if(task.phase==='working'&&task.requestToken!==previous.requestToken){
    const caseID=activeCase,requestToken=task.requestToken,instanceID=task.instanceID;
    setTimeout(()=>{
      if(activeCase!==caseID||current().instanceID!==instanceID)return;
      tasks.set(caseID,advanceReviewTask(current(),{type:'resolveRetry',requestToken}));render();
    },task.delay);
  }
}
function addButton(descriptor,plan){
  const b=node('button',descriptor.label,'action-button'+(descriptor.primary?' primary':''));b.type='button';
  if(descriptor.id==='confirm')b.disabled=!plan.ready;
  const owner=current();
  b.addEventListener('click',()=>dispatch({type:'action',id:descriptor.id,token:plan.token,taskID:owner.id,instanceID:owner.instanceID}));$('actions').append(b);
}
function renderFields(plan){
  const owner=current();
  $('reply-fields').replaceChildren();$('reply-form').hidden=plan.fields.length===0;
  for(const f of plan.fields){
    const label=node('label',f.label,f.type==='checkbox'?'check-field':'');label.htmlFor='reply-'+f.key;
    let input;
    if(f.type==='select'){
      input=node('select');input.append(new Option('请选择',''));
      for(const option of f.options??[])input.append(new Option(option.label,option.value));input.value=String(owner.formValues?.[f.key]??f.value??'');
    }else{
      input=node('input');input.type=f.type==='checkbox'?'checkbox':f.type==='date'?'date':f.type==='number'?'number':'text';
      if(f.type==='checkbox'){
        input.checked=!!f.value;
        input.addEventListener('change',()=>{dispatch({type:'check',key:f.key,value:input.checked,taskID:owner.id,instanceID:owner.instanceID,token:plan.token});$('reply-'+f.key)?.focus();});
      }else input.value=String(owner.formValues?.[f.key]??f.value??'');
      if(['amount','newAmount','actualAmount'].includes(f.key)){input.inputMode='decimal';input.placeholder='例如：35元';}
      if(f.type==='number'){input.min='1';input.max='31';}
    }
    input.id='reply-'+f.key;input.name=f.key;input.required=f.key!=='searchDate'&&f.type!=='checkbox';
    if(f.type!=='checkbox')input.addEventListener('input',()=>{if(current().id===owner.id&&current().instanceID===owner.instanceID)current().formValues={...current().formValues,[f.key]:input.value};});
    if(f.type==='checkbox')label.prepend(input);else label.append(input);$('reply-fields').append(label);
  }
  const reply=plan.actions.find(a=>a.id==='reply');$('reply-submit').hidden=!reply;$('reply-submit').textContent=reply?.label??'继续';
}
function statusFor(plan){
  if(plan.stage==='saveFailure'&&plan.recordSaved)return '记录已模拟保存 · 等待恢复结果';
  const map={input:'等待你补充',chooseOperation:'等待选择',selectPeriod:'等待选择周期',selectExpense:'等待选择消费',selectWish:'等待选择心愿',chooseBudget:'等待确认归属',conflict:'等待确认归属',confirm:'请核对后确认',ready:'可继续模拟保存',confirmRate:'等待确认换算',needsRate:'未计入 · 可以重试',working:'正在处理（演示）',error:'请求未完成 · 输入保留',saveFailure:'保存未完成 · 输入保留',attachmentFailure:'记录已模拟保存 · 待补附件',complete:'模拟完成 · 未写入真实账本',closed:'本次请求已结束',finishedRefusal:'本次请求已结束',paused:'已暂停 · 输入保留',estimate:'只读预估 · 未结算',queryResult:'只读结果',retrospective:'等待核对原周期影响',blocked:'尚未执行 · 可退出或重新选择',noMatch:'尚未执行 · 可继续查找或结束',pendingReview:'等待处理待确认记录',pendingDetail:'核对当前记录',split:'逐笔核对中',splitComplete:'各笔已处理完毕'};
  return map[plan.stage]??({manual:'修改当前输入',insufficient:'余额不足 · 未扣减',periodConflict:'周期重叠 · 尚未计入',outsidePeriod:'日期不符 · 待选择归属',unavailable:'周期不可用 · 待重新选择'})[plan.stage]??'等待下一步核对';
}
function render(){
  const t=current(),item=cases.find(c=>c.id===activeCase),p=planReviewTask(t);
  $('scenario').textContent=item.label;$('entry').textContent=item.local.entry?'卡内入口':'小朵任务面板';$('input').textContent=item.input;
  $('prompt').textContent=p.prompt;$('support').textContent=t.lastError??p.note??'';$('support').hidden=!(t.lastError||p.note);
  $('reply-history').replaceChildren();
  for(const h of t.history.slice(-3))$('reply-history').append(node('p',(h.role==='user'?'你：':'小朵：')+h.text,h.role==='user'?'user':''));
  $('choices').replaceChildren();
  for(const c of p.choices){
    const b=node('button',undefined,'choice');b.type='button';b.append(node('strong',c.label));if(c.detail)b.append(node('small',c.detail));
    b.addEventListener('click',()=>dispatch({type:'choose',id:c.id,taskID:t.id,instanceID:t.instanceID,token:p.token}));$('choices').append(b);
  }
  $('receipt').replaceChildren();$('receipt').hidden=!p.rows.length;
  if(p.rows.length){const dl=node('dl');for(const [key,value]of p.rows)dl.append(node('dt',key),node('dd',value));$('receipt').append(dl);}
  renderFields(p);$('status').textContent=statusFor(p);$('actions').replaceChildren();
  for(const a of p.actions.filter(a=>a.id!=='reply'))addButton(a,p);
  if(!['complete','closed','finishedRefusal','working','paused','splitComplete'].includes(p.stage))addButton({id:'pause',label:'稍后处理，保留输入'},p);
  $('edit').hidden=['complete','closed','working','finishedRefusal','paused','saveFailure','attachmentFailure','blocked'].includes(p.stage)||!['capture','createBudget','createWish','adjustPeriodAmount','deleteExpense','editExpense','redeemWish','refund'].includes(t.operation);
  $('checks').replaceChildren();
  const checks=[['当前任务',({capture:'记一笔',createBudget:'创建预算',settlePeriod:'结算',queryBudgetStatus:'查询预算',adjustPeriodAmount:'调整额度',refund:'退款',deleteExpense:'删除消费',editExpense:'修改消费',createWish:'添加心愿',redeemWish:'兑现心愿',lateExpense:'原周期修正',split:'逐笔处理',amendment:'确认修改对象',plannedWish:'确认心愿意图'})[t.operation]??'核对意图'],['当前步骤',statusFor(p)],['输入与选择',t.phase==='complete'?'模拟完成，结果可查看':'保留在当前任务'],['实际账本','未连接，不写入']];
  for(const [label,value]of checks){const row=node('div',undefined,'check');row.append(node('span',p.stage==='complete'?'✓':'○','mark'));const content=node('div');content.append(node('strong',label),node('p',value));row.append(content);$('checks').append(row);}
  document.querySelectorAll('.flow li').forEach(el=>el.removeAttribute('aria-current'));
  const progress=['complete','closed','finishedRefusal','queryResult','estimate','splitComplete'].includes(p.stage)?'flow-result':['confirm','ready','confirmRate','pendingReview','pendingDetail','retrospective'].includes(p.stage)?'flow-confirm':['input','chooseBudget','conflict','selectPeriod','selectWish','selectExpense','chooseOperation','split','noMatch'].includes(p.stage)?'flow-input':'flow-understand';
  $(progress).setAttribute('aria-current','step');
  $('explanation').textContent=item.designOnly?'此任务是隔离设计演示。真实业务尚未接通，需另行实现与验收。':item.injected?'本例使用明确的故障注入，演示恢复与原输入保留。':'固定虚构输入经服务端 Workflow 得到候选；本页演示本机如何继续处理。';
  $('json').textContent=JSON.stringify({服务端候选:t.candidate,任务动作:t.operation,当前字段:t.draft,当前步骤:p.stage,已保存模拟结果数:Object.keys(t.commands).length,请求状态:t.phase,故障注入:item.injected?item.fault??item.error:undefined},null,2);
}
for(const group of [...new Set(cases.map(c=>c.group))]){
  const details=node('details'),summary=node('summary',group),list=node('div',undefined,'case-list');details.open=group==='记录与归属';
  const optgroup=node('optgroup');optgroup.label=group;
  for(const item of cases.filter(c=>c.group===group)){
    const b=node('button',item.label,'case-button');b.type='button';b.dataset.case=item.id;b.addEventListener('click',()=>choose(item));list.append(b);
    const option=node('option',item.label);option.value=item.id;optgroup.append(option);
  }
  details.append(summary,list);$('case-groups').append(details);$('mobile-cases').append(optgroup);
}
$('reply-form').addEventListener('submit',event=>{event.preventDefault();const values=Object.fromEntries(new FormData($('reply-form')).entries());dispatch({type:'reply',values});});
$('mobile-cases').addEventListener('change',event=>choose(cases.find(c=>c.id===event.target.value)));
$('reset').addEventListener('click',()=>dispatch({type:'action',id:'restart'}));
$('manual-toggle').addEventListener('click',()=>dispatch({type:'action',id:'manual'}));
if(location.protocol==='file:'){$('download').textContent='独立 HTML · 可离线查看';$('download').removeAttribute('href');$('download').removeAttribute('download');}
choose(cases.find(c=>c.id===location.hash.slice(1))??cases.find(c=>c.id==='missing-amount')??cases[0]);
