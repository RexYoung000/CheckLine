import {icon} from './brand-icons.mjs?v=1';
import {createCardLight} from './brand-card-light.mjs?v=2';
import {createMascot} from './glass-mascot.mjs?v=20260927-appearance';
import {createAmbientSymbols} from './glass-ambient.mjs?v=20260927-appearance';
import {projection,recordsFor,weekSeries,periodStatus,dateLabel,monthLabel,budgetDate} from './glass-data.mjs';

// Isolated presentation fixtures from the existing review. No native data writes.
const budgets = [
  {id:'daily',name:'日常生活',cents:300000,cycle:'monthly'},
  {id:'coffee',name:'咖啡与甜点',cents:50000,cycle:'monthly'},
  {id:'travel',name:'周末旅行',cents:240000,cycle:'once'},
  {id:'family',name:'这个月和爸妈一起吃饭的家庭聚餐预算',cents:160000,cycle:'monthly'},
  {id:'possible',name:'日常生活',cents:132000,cycle:'monthly'}
].map(b=>({...b,start:'2026-09-01',end:b.id==='travel'?'2026-10-03':'2026-09-30'}));
const rows = [
  ['r1','街角咖啡',3500,24,'daily',true],['r2','晚餐',12800,24,'daily'],
  ['r3','日用品补充',8650,23,'daily'],['r4','周末买菜',15600,22,'daily'],
  ['r5','便利店',2850,21,'daily'],['r6','朋友聚餐',26800,20,'daily'],
  ['r7','地铁与出行',4600,19,'daily'],['r8','本月其他日常消费',58700,18,'daily'],
  ['r9','咖啡豆',12800,23,'coffee'],['coffee-latte','拿铁',2800,22,'coffee'],
  ['coffee-cake','芝士蛋糕',2600,21,'coffee'],['coffee-americano','美式咖啡',1600,20,'coffee'],
  ['r10','山间小屋订金',42000,22,'travel'],['travel-train','往返车票',12000,21,'travel'],
  ['travel-ticket','公园门票',4000,20,'travel'],['travel-snack','路上补给',2000,19,'travel'],
  ['r11','家庭聚餐',68000,21,'family'],['family-groceries','周末食材',18000,20,'family'],
  ['family-fruit','水果',7200,19,'family'],['family-breakfast','早餐',4800,18,'family']
].map(([id,name,cents,day,budgetID,pending=false])=>({id,name,cents,date:`2026-09-${day}`,budgetID,pending}));
rows.push(...rows.filter(r=>r.budgetID==='daily').map(r=>({...r,id:`possible-${r.id}`,budgetID:'possible'})));

const $=id=>document.getElementById(id);
const media=matchMedia('(prefers-reduced-motion: reduce)');
const money=cents=>new Intl.NumberFormat('zh-CN',{style:'currency',currency:'CNY',minimumFractionDigits:cents%100?2:0,maximumFractionDigits:2}).format(cents/100);
const esc=text=>String(text).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let selected='daily';
const reduced=()=>media.matches||$('still').checked;
const instances=[...document.querySelectorAll('.screen')].map(screen=>({screen,mascot:createMascot(screen),ambient:null,cardLight:null,replyTimer:0,pressAnimation:null,mascotState:'idle'}));

function water(p,id){
  if(p.level<=0)return '';
  const bubbles=Array.from({length:30},(_,i)=>{
    const seed=n=>((Math.sin((i+1)*n)*43758.5453)%1+1)%1;
    const size=i%9===0?4.2+seed(12.9):1.5+seed(8.7)*1.4;
    return `<i style="--x:${5+seed(17.3)*90}%;--size:${size}px;--duration:${3.7+seed(11.6)*3.5}s;--phase:${-seed(5.1)*11}s;--drift:${-11+seed(9.6)*22}px;--peak:${.48+seed(7.9)*.32};--rest:${12+seed(21.4)*69}%"></i>`;
  }).join('');
  return `<div class="liquid" style="--level:${p.level}%" aria-hidden="true"><svg viewBox="0 0 600 260" preserveAspectRatio="none"><defs><linearGradient id="water-${id}" x1="0" y1="0" x2="0" y2="1"><stop class="water-start"/><stop class="water-end" offset="1"/></linearGradient></defs><path d="M0 14 Q75 0 150 14 T300 14 Q375 0 450 14 T600 14 V260 H0 Z" fill="url(#water-${id})"/></svg><div class="bubble-field">${bubbles}</div></div>`;
}
function card(b,p,id){
  if(!b)return `<div class="home-card-holder"><div class="back-card" aria-hidden="true"></div><div class="empty-card create-card"><span class="empty-add" aria-hidden="true">${icon('plus')}</span><h3>创建第一张预算卡</h3></div></div>`;
  const caption=p.risk==='possible'?'可能超出':p.risk==='confirmed'?'已超出':'还能花';
  return `<div class="home-card-holder"><div class="back-card" aria-hidden="true"></div><section class="budget-card" tabindex="0" aria-label="${esc(b.name)} · 卡片材质预览" aria-describedby="material-help"><div class="card-heading"><h3>${esc(b.name)}</h3><span class="card-menu" aria-hidden="true">···</span></div><p class="card-cycle">${b.cycle==='once'?'一次性预算':'每月循环'} · CNY</p>${water(p,id)}<div class="card-reflection" aria-hidden="true"></div><div class="card-edge-light" aria-hidden="true"></div><div class="card-bottom"><span class="record-plus" aria-hidden="true">${icon('plus')}</span><div class="card-value"><p class="value-label">${caption}</p><p class="value-amount">${money(Math.abs(p.remaining))}</p><p class="value-caption">${p.risk==='none'?`${p.level.toFixed(0)}% 剩余`:'含待确认金额'}</p></div></div></section></div>`;
}
function summary(b,p){
  const series=weekSeries(rows,b),maximum=Math.max(1,...series.map(v=>v.cents));
  const bars=series.map(v=>`<i class="${v.cents?'hot':''}" style="--height:${v.cents/maximum*100}%"></i>`).join('');
  const month=budgetDate(b).slice(0,7),dates=new Set(recordsFor(rows,b).map(r=>r.date));
  const start=new Date(`${month}-01T12:00:00Z`).getUTCDay(),count=new Date(Date.UTC(Number(month.slice(0,4)),Number(month.slice(5,7)),0)).getUTCDate();
  const calendar=Array.from({length:start+count},(_,i)=>`<i ${i<start?'style="visibility:hidden"':''} class="${dates.has(`${month}-${String(i-start+1).padStart(2,'0')}`)?'marked':''}"></i>`).join('');
  return `<div class="summaries"><section class="summary"><p class="summary-title">${p.pending?'暂计已用':'已用'}${icon('arrow')}</p><p class="summary-value">${money(p.total)}</p><div class="mini-trend" aria-label="最近七天消费趋势">${bars}</div></section><section class="summary"><p class="summary-title">${monthLabel(budgetDate(b))}${icon('arrow')}</p><p class="summary-value days">${periodStatus(b)}</p><div class="mini-calendar" aria-label="当月消费日期">${calendar}</div></section></div>${p.pending?`<p class="summary-note">${icon('info')}<span class="notice-copy">待确认归属</span><span class="notice-count">${money(p.pending)}</span>${icon('right')}</p>`:''}`;
}
function receipts(b){
  const recent=recordsFor(rows,b).slice(0,3);
  return `<div class="records-heading"><h3>最近记录</h3><span>全部记录 ↗</span></div><div class="receipt-stack">${recent.slice().reverse().map((r,i)=>`<article class="receipt ${i===0?'receipt-back':i===1?'receipt-mid':'receipt-front'}"><div><strong>${esc(r.name)}</strong>${i===2?`<p>${dateLabel(r.date)}${r.pending?' · 待确认':''}</p>`:''}</div><span class="receipt-amount">−${money(r.cents)}</span></article>`).join('')}</div><p class="coverage">仅包含已记录消费</p>`;
}
function navigation(){return `<div class="navigation" aria-label="底部导航外观示意"><div class="tabs" aria-hidden="true">${['home','budget','heart','chart'].map((n,i)=>`<span class="tab-glyph ${i===0?'active':''}">${icon(n)}</span>`).join('')}</div><button type="button" class="assistant-entry" aria-label="预览小朵点击反馈"><span class="agent-float"><span class="agent-press"><svg class="xiaoduo" data-xiaoduo data-small viewBox="-112 -104 224 208" aria-hidden="true"></svg></span></span></button></div>`;}
function render(){
  const b=budgets.find(b=>b.id===selected),p=b?projection(rows,b):null;
  for(const instance of instances){
    const {screen}=instance;
    clearTimeout(instance.replyTimer);
    instance.pressAnimation?.cancel();
    instance.mascotState='idle';
    instance.ambient?.destroy();
    instance.cardLight?.destroy();
    screen.innerHTML=`<div class="scene-wash" aria-hidden="true"></div><div class="home-symbols" aria-hidden="true"></div><div class="topbar" aria-label="顶部导航外观示意"><span class="nav-glyph" aria-hidden="true">${icon('user')}</span><span class="nav-spacer"></span><span class="nav-glyph" aria-hidden="true">${icon('bell')}</span><span class="nav-glyph" aria-hidden="true">${icon('menu')}</span></div><div class="hero">${card(b,p,screen.id)}</div><div class="pocket ${b?'':'empty-pocket'}"><svg class="pocket-rim" viewBox="0 0 390 26" preserveAspectRatio="none" aria-hidden="true"><path d="M0 0C20 0 23 25 48 25H342C367 25 370 0 390 0V26H0Z" fill="currentColor"/></svg>${b?summary(b,p)+receipts(b):'<div class="empty-copy"><p>预算与消费会显示在这里。</p></div>'}${navigation()}</div>`;
    instance.ambient=createAmbientSymbols({host:screen.querySelector('.home-symbols'),app:screen,page:screen,icon,reduced,active:()=>!document.hidden&&screen.getBoundingClientRect().width>0,limit:3,staticLimit:2});
    const materialCard=screen.querySelector('.budget-card');
    instance.cardLight=materialCard?createCardLight({card:materialCard,reduced}):null;
    instance.mascot.sync('idle',reduced());
    instance.ambient.sync();
  }
  $('light-preview').disabled=reduced()||!b;
  $('review-status').textContent=`两套首页已同步为${b?.name||'空状态'}。`;
}
function syncMotion(){
  document.body.classList.toggle('still',reduced());
  $('light-preview').disabled=reduced()||!budgets.some(b=>b.id===selected);
  for(const instance of instances){
    if(reduced()){instance.pressAnimation?.cancel();clearTimeout(instance.replyTimer);instance.mascotState='idle';}
    instance.mascot.sync(instance.mascotState,reduced());instance.ambient?.sync();instance.cardLight?.sync();
  }
}
for(const instance of instances)instance.screen.addEventListener('click',event=>{
  const entry=event.target.closest('.assistant-entry');
  if(!entry)return;
  clearTimeout(instance.replyTimer);
  instance.pressAnimation?.cancel();
  if(!reduced()){
    instance.pressAnimation=entry.querySelector('.agent-press').animate(
      [{transform:'scale(.96)'},{transform:'scale(1.055)',offset:.5},{transform:'scale(1)'}],
      {duration:380,easing:'cubic-bezier(.2,.7,.2,1)'}
    );
    instance.mascotState='receive';instance.mascot.sync('receive',false);
    instance.replyTimer=setTimeout(()=>{instance.mascotState='idle';instance.mascot.sync('idle',reduced());},1000);
  }
  $('review-status').textContent='小朵入口反馈预览；完整助手会话请打开原交互稿。';
});
$('light-preview').addEventListener('click',()=>{
  instances.forEach(instance=>instance.cardLight?.preview());
  $('review-status').textContent='反光演示已启动；也可直接在卡面移动鼠标。';
});
$('budget-choice').addEventListener('change',e=>{selected=e.target.value;render();});
$('card-edge').addEventListener('change',e=>{document.body.dataset.cardEdge=e.target.value;});
$('preview-width').addEventListener('change',e=>document.documentElement.style.setProperty('--study-width',`${e.target.value}px`));
$('large-text').addEventListener('change',e=>instances.forEach(({screen})=>screen.classList.toggle('large',e.target.checked)));
$('still').addEventListener('change',syncMotion);
media.addEventListener('change',syncMotion);
document.addEventListener('visibilitychange',syncMotion);
document.querySelectorAll('[data-view]').forEach(button=>{if(button.tagName!=='BUTTON')return;button.addEventListener('click',()=>{
  $('studies').dataset.view=button.dataset.view;
  document.querySelectorAll('button[data-view]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));
  syncMotion();
});});
render();syncMotion();
