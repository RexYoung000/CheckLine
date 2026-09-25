import { BotEngine } from './vendor/engine.mjs';
import { SHAPE_BY_ID } from './vendor/skins.mjs';
import { STATE_BY_ID, POSES } from './vendor/states.mjs';
import { renderer } from './render.mjs';
export const items=[
 ['idle','静止 / 待机','优先讨论','保持云朵，带原版细微呼吸、视线漂移和自然眨眼。','Agent 空闲、任务结束后的常态。','观察它安静时是否仍有生命感；不要求用户持续关注。','保留云朵'],
 ['wide','睁大眼睛','优先讨论','眼睛拉长睁大，目光和头部朝向改变；身体仍是云朵。','接收到一句输入、打开助手时的短回应。','单次发生即可；避免每次输入字符都重复，也不要让它像受到惊吓。','保留云朵'],
 ['thinking','思考','优先讨论','云朵收成中间圆点，两侧小点分离出来，三个点依次脉动。','理解输入、识别图片、核对消费归属。','可在真实处理中循环。重点看云朵变成点是否自然、等待是否容易理解。','暂时变成三点'],
 ['notify','通知','优先讨论','眼神改变，身体边缘弹出一颗提示点；提示点有短促的超调回弹。','发现待确认归属，或有一项结果需要你查看。','出现一次后保持，提示点可以随待办状态消失；不用反复弹跳催促。','保留云朵'],
 ['wink','眨眼','优先讨论','一只眼睛闭成较宽的横线，另一只睁开，伴随视线偏转。','单笔处理完成、撤销完成等简短回应。','必须跟随真实操作成功；轻快程度需要你判断。原版是单眼眨眼。','保留云朵'],
 ['burst','爆散 / 聚合','挑场景','身体缩成小核，周围颗粒向中心旋入，随后身体重新长大。','多笔整理完成，或一段较长任务结束。','动作比单笔反馈更隆重。原版会回到圆形；开启进出衔接，可看它再变回云朵。','缩小、聚合、重组'],
 ['comet','彗星','挑场景','主体缩成小点，彩色拖尾围绕中心划过，再重新长大。','助手出场，或重要任务的阶段交接。','原版的小点基本留在中心，并不会横穿屏幕。先判断彩色线条是否符合产品气质。','小点与环绕拖尾'],
 ['orbit','轨道','挑场景','三角形旋转，彩色轨道先后出现；主体逐渐舒展回圆形。','助手展开后的较大展示区、低频强调时刻。','视觉最强的一组，原版含前后遮挡和空间感；小头像中可能过于繁杂。','三角形、轨道、圆形'],
 ['play','播放','挑场景','主体成为圆角三角形，一束彩色弧线从旁边掠过。','启动一项较完整的任务，或助手进入工作状态。','名称是上游动画名，并不代表要增加视频播放功能；先判断三角形变化是否适合。','三角形与掠过弧线'],
 ['alert','警示','挑场景','身体变成倾斜的感叹号，横向移动后回位，带很轻的振动。','确实需要注意、暂时无法继续的异常。','普通待确认不必用它；金额不确定时不能借表情暗示已经发生确定风险。','移动的倾斜感叹号'],
 ['exclaim','感叹号','挑场景','身体收成直立的感叹号，符号状态保持。','必须阅读的重要说明，或缺少关键信息时的强调。','比 Alert 安定，但仍有警告意味；不要用来催促用户或评价消费。','直立感叹号'],
 ['sleep','休眠','挑场景','整个身体缩成小点，按原版节奏上下弹动。','收起助手时的过渡候选。','原版并非完全静止的睡眠；要看持续弹动是否反而吸引注意。','小点上下弹动'],
 ['egg','蛋形','挑场景','云朵变成蛋形，眼睛靠拢，朝向随之变化。','启动、醒来、首次出现时的性格动作候选。','目前没有确定业务用途；可以喜欢它的形变，也可以暂时不选。','蛋形'],
 ['hexagon','六边形','挑场景','主体变成圆角六边形，眼神和大小跟随变化。','整理、分类、结构化结果出现时的候选。','用途只是联想，未确定。重点看几何感是否会让柔和的云朵显得生硬。','圆角六边形']
].map(([id,name,group,look,scene,trade,shape])=>({id,name,group,look,scene,trade,shape}));
const $=id=>document.getElementById(id),cloud=SHAPE_BY_ID.get('nuage').radii;
let index=0,time=0,playing=false,last=null,raf=null,ink='#0a0a0c';
const paper='#f9f9f9',large=renderer($('hero')),small=renderer($('small'));
const thumbRender=[];
let saved={},storageOK=true;
try{const raw=JSON.parse(localStorage.getItem('checkline-bloub-review-v1')||'{}');if(raw&&typeof raw==='object')saved=raw;}catch{storageOK=false;}
const status=()=>{$('save-status').textContent=storageOK?'选择和备注仅保存在本机浏览器，不代表最终采用。':'本机保存不可用；请保留页面或自行复制备注。';};
function save(){try{localStorage.setItem('checkline-bloub-review-v1',JSON.stringify(saved));storageOK=true;}catch{storageOK=false;}status();}
function decision(){const d=saved[items[index].id]||{};document.querySelectorAll('[data-decision]').forEach(b=>b.setAttribute('aria-pressed',String((d.choice||'未决定')===b.dataset.decision)));$('note').value=typeof d.note==='string'?d.note:'';}
function paintBadges(){document.querySelectorAll('[data-item]').forEach(b=>{b.querySelector('.choice').textContent=saved[b.dataset.item]?.choice||'';});$('count').textContent=`${items.filter(x=>saved[x.id]?.choice&&saved[x.id].choice!=='未决定').length} / 14 已标记`;}
for(const group of ['优先讨论','挑场景']){
 const section=document.createElement('section'),h=document.createElement('h2');h.textContent=group;section.append(h);
 items.forEach((item,i)=>{if(item.group!==group)return;const b=document.createElement('button');b.className='item';b.dataset.item=item.id;b.setAttribute('aria-pressed','false');b.innerHTML=`<svg></svg><span class="item-label"><span>${item.name}</span><small>${item.id}</small></span><small class="choice"></small>`;b.onclick=()=>select(i);section.append(b);thumbRender.push([renderer(b.querySelector('svg')),item.id]);});$('library').append(section);
}
function thumbnails(){thumbRender.forEach(([draw,id])=>draw(new BotEngine(100,id,cloud).sample(POSES[id]),ink,paper));}
function duration(){const d=STATE_BY_ID.get(items[index].id);return Math.max(d.duration,d.minDuration||0)+($('transition').checked?1.8:0);}
// Reconstruct dated state changes for deterministic seeking, including backward scrubs.
function frameAt(t){const id=items[index].id,d=STATE_BY_ID.get(id);if(!$('transition').checked)return new BotEngine(100,id,cloud).sample(t);const engine=new BotEngine(100,'idle',cloud);if(t>=.6)engine.setState(id,.6);if(t>=.6+Math.max(d.duration,d.minDuration||0))engine.setState('idle',.6+Math.max(d.duration,d.minDuration||0));return engine.sample(t);}
function render(){const frame=frameAt(time);large(frame,ink,paper);small(frame,ink,paper);$('seek').max=String(duration());$('seek').value=String(time);$('timer').textContent=`${time.toFixed(1)} / ${duration().toFixed(1)} 秒`;$('play').textContent=playing?'暂停':'播放';$('play').setAttribute('aria-pressed',String(playing));const id=items[index].id,d=STATE_BY_ID.get(id);$('phase').textContent=$('reduced').checked?'静态审阅':$('transition').checked?(time<.6?'云朵起点':time<.6+Math.max(d.duration,d.minDuration||0)?`动作 · ${id}`:'回到云朵'):`单项 · ${id}`;}
function stop(){playing=false;last=null;if(raf!==null)cancelAnimationFrame(raf);raf=null;}
function tick(now){raf=null;if(!playing||document.hidden)return;if(last!==null)time+=Math.min((now-last)/1000,.064)*Number($('speed').value);last=now;if(time>=duration()){if($('loop').checked)time%=duration();else{time=duration();stop();}}render();if(playing)raf=requestAnimationFrame(tick);}
function start(){if($('reduced').checked)return;if(time>=duration())time=0;playing=true;last=null;render();if(raf===null&&!document.hidden)raf=requestAnimationFrame(tick);}
function select(i){stop();index=Math.max(0,Math.min(items.length-1,i));const item=items[index];time=$('transition').checked?.6+POSES[item.id]:POSES[item.id];$('title').textContent=item.name;$('kicker').textContent=`${String(index+1).padStart(2,'0')} / 14 · ${item.group}`;$('look').textContent=item.look;$('scene').textContent=item.scene;$('trade').textContent=item.trade;$('shape').textContent=item.shape;$('upstream').href=`https://bloub.vercel.app/#etat=${item.id}&stop`;$('prev').disabled=index===0;$('next').disabled=index===items.length-1;document.querySelectorAll('[data-item]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.item===item.id)));decision();render();history.replaceState(null,'',`#${item.id}`);}
$('prev').onclick=()=>select(index-1);$('next').onclick=()=>select(index+1);
$('play').onclick=()=>{if(playing){stop();render();}else start();};
$('replay').onclick=()=>{stop();time=0;start();render();};
$('seek').oninput=()=>{stop();time=Number($('seek').value);render();};
$('transition').onchange=()=>{stop();time=0;render();};
$('palette').onchange=()=>{ink=$('palette').value==='original'?'#0a0a0c':'#78648c';thumbnails();render();};
function reduce(on){$('reduced').checked=on;if(on)stop();$('play').disabled=on;$('replay').disabled=on;render();}
$('reduced').onchange=()=>reduce($('reduced').checked);
const motion=matchMedia('(prefers-reduced-motion: reduce)');motion.addEventListener('change',e=>reduce(e.matches));
document.querySelectorAll('[data-decision]').forEach(b=>b.onclick=()=>{const id=items[index].id;saved[id]={...saved[id],choice:b.dataset.decision};save();decision();paintBadges();});
$('note').oninput=()=>{const id=items[index].id;saved[id]={...saved[id],note:$('note').value};save();};
document.addEventListener('visibilitychange',()=>{last=null;if(document.hidden){if(raf!==null)cancelAnimationFrame(raf);raf=null;}else if(playing&&raf===null)raf=requestAnimationFrame(tick);});
window.addEventListener('hashchange',()=>{const i=items.findIndex(x=>x.id===location.hash.slice(1));if(i>=0)select(i);});
thumbnails();paintBadges();status();select(Math.max(0,items.findIndex(x=>x.id===location.hash.slice(1))));reduce(motion.matches);$('loading').hidden=true;
