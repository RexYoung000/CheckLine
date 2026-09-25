import {CloudStatePlayer,stateRenderer} from './cloud-states.mjs';
import {BotEngine} from './vendor/engine.mjs';
import {SHAPE_BY_ID} from './vendor/skins.mjs';
import {renderer} from './render.mjs';
const $=id=>document.getElementById(id),player=new CloudStatePlayer();
const draws=[...document.querySelectorAll('[data-cloud]')].map(stateRenderer);
const sourceDraw=renderer($('source'));
const info={
 idle:['待机','安静地陪在这里','保留 bloub 的自然眨眼和缓慢视线漂移。云朵身体安定；小头像不持续起伏。','我在这里','idle'],
 receive:['收到输入','先看见你，再开始做','参考 bloub 的 wide：双眼抬起、睁开，短暂回应后归位。单项审阅只播放一次。','收到你的输入','wide'],
 thinking:['思考','每一阵风，都有不同','沿用已确认的整片聚散：每轮轨迹和云团节奏变化，真实任务结束前可持续循环。','正在整理你的想法…','thinking'],
 waiting:['等待确认','停下来，等你决定','参考 notify 的视线与提示点。点只出现一次，之后保持；不会反复跳动催促。','有一项归属需要你确认','notify'],
 success:['完成','轻轻回应一下，就够了','参考 wink 的单眼回应，播放一次后回到自然待机。完成文字保留；正式接入须跟随真实保存成功。','已经处理好了','wink'],
 error:['异常','说明问题，保留下一步','先试云朵旁的感叹提示，保留形象，不抖动、不做责备表情。失败说明和重试按钮同时出现。','暂时没完成，可以重试','exclaim']
};
let selected='idle',workflow='idle',stageTime=0,reviewTime=0,playing=true,last=null,raf=null,reference=new BotEngine(80,'idle',SHAPE_BY_ID.get('nuage').radii);
const texts={
 idle:['尚未开始模拟任务','示例：午餐 ¥36，预算归属需要确认。所有处理结果均由下方按钮模拟。'],
 receive:['已收到示例输入','先短暂回应，再进入持续思考；没有请求模型或读取账本。'],
 thinking:['正在整理示例输入…','可以随时模拟返回待确认、模拟失败，或在云朵散开时取消。'],
 waiting:['午餐 ¥36，归入「日常生活」？','当前为不确定归属示例。云朵停住等你；只有确认后才进入模拟保存。'],
 saving:['正在模拟保存…','确认不等于保存成功。点击“模拟保存成功”或“模拟失败”观察对应结果。'],
 success:['模拟保存成功','示例已完成。这里只演示成功回应，没有写入真实记录。'],
 error:['模拟保存失败，示例内容已保留','可以重试。失败不会触发完成表情；示例输入与归属仍在本页。'],
 cancelled:['已取消模拟任务','从当前云团姿态归拢回待机，不补播完成动画。']
};
let retryTo='thinking';
function text(id,value){if($(id).textContent!==value)$(id).textContent=value;}
function choose(id,{single=true}={}){selected=id;reviewTime=0;player.select(id);reference=new BotEngine(80,info[id][4],SHAPE_BY_ID.get('nuage').radii);
 document.querySelectorAll('[data-state]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.state===id)));
 text('name',info[id][1]);text('explanation',info[id][2]);text('tag',`${String(Object.keys(info).indexOf(id)+1).padStart(2,'0')} / ${info[id][0]}${id==='thinking'?' · 已确认':' · 待审阅'}`);
 text('small-state',info[id][0]);text('title-state',info[id][3]);
 text('source-copy',id==='thinking'?'原版将主体变成三个点。当前改版采用已确认的云朵整片聚散；这里仅保留原版以便比较。':id==='error'?'原版身体变成感叹号；本轮先试保留云朵并添加感叹提示。两者不是同一动画，此表达仍待审阅。':`参考 bloub 的 ${info[id][4]}。采用眼形、眨眼或提示点的语言，调整为当前二维云朵的正面面部与比例。`);
 $('catalog').href=`2026-09-25-bloub-catalog.html#${info[id][4]}`;
 if(single){workflow='idle';stageTime=0;updateScenario();}draw();}
function updateScenario(){const [title,detail]=texts[workflow];text('status',title);text('detail',detail);
 const enabled={start:true,result:workflow==='thinking',confirm:workflow==='waiting',saved:workflow==='saving',fail:['thinking','saving'].includes(workflow),retry:workflow==='error',cancel:!['idle','cancelled','success'].includes(workflow)};
 for(const [id,on] of Object.entries(enabled))$(id).disabled=!on;
 document.querySelectorAll('[data-step]').forEach(n=>{if(n.dataset.step===workflow)n.setAttribute('aria-current','step');else n.removeAttribute('aria-current');});}
function go(state){workflow=state;stageTime=0;choose(state==='saving'?'thinking':state==='cancelled'?'idle':state,{single:false});updateScenario();}
function draw(){const frame=player.sample();draws.forEach(draw=>draw(frame));if($('reference').open){const dark=document.body.classList.contains('dark');sourceDraw(reference.sample(player.reduced?0:reviewTime),dark?'#b4a1c8':'#78648c',dark?'#302a38':'#fbfaf8');}text('play',playing?'暂停':'播放');$('play').setAttribute('aria-pressed',String(playing));}
function tick(now){raf=null;if(!playing||document.hidden||player.reduced)return;
 const dt=last===null?0:Math.min((now-last)/1000,.08)*Number($('speed').value);last=now;stageTime+=dt;reviewTime+=dt;player.step(dt);
 if(workflow==='receive'&&stageTime>=.9)go('thinking');
 else if(['receive','success'].includes(player.state)&&player.time>1.1)player.select('idle');
 draw();raf=requestAnimationFrame(tick);}
function resume(){playing=!player.reduced;last=null;if(!player.reduced&&!document.hidden&&raf===null)raf=requestAnimationFrame(tick);draw();}
function pause(){playing=false;last=null;if(raf!==null)cancelAnimationFrame(raf);raf=null;draw();}
for(const button of document.querySelectorAll('[data-state]'))button.onclick=()=>{choose(button.dataset.state);resume();};
$('start').onclick=()=>{go(player.reduced?'thinking':'receive');resume();};
$('result').onclick=()=>go('waiting');$('confirm').onclick=()=>go('saving');$('saved').onclick=()=>go('success');
$('fail').onclick=()=>{retryTo=workflow;go('error');};$('retry').onclick=()=>{go(retryTo);resume();};$('cancel').onclick=()=>go('cancelled');
$('play').onclick=()=>playing?pause():resume();
$('replay').onclick=()=>{choose(selected);resume();};
$('theme').onclick=()=>{const dark=document.body.classList.toggle('dark');$('theme').setAttribute('aria-pressed',String(dark));text('theme',dark?'浅色背景':'深色背景');draw();};
$('reference').ontoggle=draw;
function reduce(on){player.reduce(on);$('reduce').checked=on;$('play').disabled=on;$('replay').disabled=on;$('speed').disabled=on;
 if(on){pause();if(workflow==='receive')go('thinking');}else resume();draw();}
$('reduce').onchange=()=>reduce($('reduce').checked);
const media=matchMedia('(prefers-reduced-motion: reduce)');media.addEventListener('change',e=>reduce(e.matches));
document.addEventListener('visibilitychange',()=>{last=null;if(document.hidden){if(raf!==null)cancelAnimationFrame(raf);raf=null;}else if(playing&&!player.reduced&&raf===null)raf=requestAnimationFrame(tick);});
choose('idle');reduce(media.matches);$('loading').hidden=true;
