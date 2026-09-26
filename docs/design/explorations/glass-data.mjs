// Isolated review data only. Amounts are integer cents; the native ledger is untouched.
export const REVIEW_DATE='2026-09-26';
export function validDate(value){
 if(!/^\d{4}-\d{2}-\d{2}$/.test(value||''))return false;
 const d=new Date(value+'T12:00:00Z');return Number.isFinite(+d)&&d.toISOString().slice(0,10)===value;
}
export function addDays(date,count){const d=new Date(date+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+count);return d.toISOString().slice(0,10);}
export function monthStart(date){return date.slice(0,7)+'-01';}
export function monthEnd(date){return addDays(new Date(Date.UTC(Number(date.slice(0,4)),Number(date.slice(5,7)),1,12)).toISOString().slice(0,10),-1);}
export function dateLabel(date,year=false){return new Intl.DateTimeFormat('zh-CN',{...(year?{year:'numeric'}:{}),month:'long',day:'numeric',timeZone:'UTC'}).format(new Date(date+'T12:00:00Z'));}
export function monthLabel(date){return new Intl.DateTimeFormat('zh-CN',{month:'long',timeZone:'UTC'}).format(new Date(date+'T12:00:00Z'));}
export function inPeriod(date,budget){return validDate(date)&&(!budget.start||date>=budget.start)&&(!budget.end||date<=budget.end);}
export function sortRecords(records){return [...records].sort((a,b)=>b.date.localeCompare(a.date));}
export function recordsFor(records,budget){return budget?sortRecords(records.filter(r=>!r.unbudgeted&&r.budgetID===budget.id&&inPeriod(r.date,budget))):[];}
export function projection(records,budget){
 const rows=recordsFor(records,budget),confirmed=rows.filter(r=>!r.pending).reduce((n,r)=>n+r.cents,0),pending=rows.filter(r=>r.pending).reduce((n,r)=>n+r.cents,0),total=confirmed+pending,remaining=(budget?.cents||0)-total;
 return {confirmed,pending,total,remaining,level:budget?Math.max(0,Math.min(100,remaining/budget.cents*100)):0,risk:budget&&confirmed>budget.cents?'confirmed':remaining<0?'possible':'none'};
}
export function budgetDate(budget,today=REVIEW_DATE){return budget?.settled?(budget.end||budget.start):budget?.end&&budget.end<today?budget.end:budget?.start&&budget.start>today?budget.start:today;}
export function periodStatus(budget,today=REVIEW_DATE){
 if(budget.settled)return '已结算';if(!budget.end)return '无截止日期';
 const days=Math.round((new Date(budget.end+'T12:00:00Z')-new Date(today+'T12:00:00Z'))/86400000);
 if(budget.start>today)return '尚未开始';return days<0?'待结算':days===0?'今天到期':days+' 天剩余';
}
export function weekSeries(records,budget){const end=budgetDate(budget),rows=recordsFor(records,budget);return Array.from({length:7},(_,i)=>{const date=addDays(end,i-6);return {date,cents:rows.filter(r=>r.date===date).reduce((n,r)=>n+r.cents,0)}});}
export function applyWalletDelta(wallet,recovery,delta){if(delta>=0){const restored=Math.min(recovery,delta);return {wallet:wallet+delta-restored,recovery:recovery-restored}}const paid=Math.min(wallet,-delta);return {wallet:wallet-paid,recovery:recovery-delta-paid};}
export function retrospectiveImpact(before,after,budgets,wallet,recovery){
 const affected=budgets.filter(b=>b.settled).map(b=>{const old=projection(before,b),next=projection(after,b);return {id:b.id,name:b.name,before:b.cents-old.confirmed,after:b.cents-next.confirmed}}).filter(p=>p.before!==p.after);
 const delta=affected.reduce((n,p)=>n+p.after-p.before,0);return {affected,delta,...applyWalletDelta(wallet,recovery,delta)};
}
