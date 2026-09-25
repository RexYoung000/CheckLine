import {sampleCompactFlow,createFlowRenderer} from './cloud-flow.mjs';
import {cycleScore,sampleDissolve,createDissolveRenderer} from './cloud-dissolve.mjs';
const $=id=>document.getElementById(id);
const renderers=[...document.querySelectorAll('[data-cloud]')].map(svg=>({draw:svg.dataset.cloud==='previous'?createFlowRenderer(svg,{compact:true}):createDissolveRenderer(svg),previous:svg.dataset.cloud==='previous'}));
let time=0,cycle=0,referenceTime=0,playing=false,last=null,raf=null,mode='thinking';
const setText=(id,text)=>{if($(id).textContent!==text)$(id).textContent=text;};
const stages=['完整云朵','错拍化开','顺势归拢','凝聚停留'];
function draw(){
 const duration=cycleScore(cycle).duration,phase=time/duration;
 const frame=sampleDissolve(time,mode,cycle),previous=sampleCompactFlow(referenceTime,mode);
 renderers.forEach(r=>r.draw(r.previous?previous:frame));
 $('seek').max=duration;$('seek').value=time;
 setText('timer',`${time.toFixed(1)} / ${duration.toFixed(1)} 秒`);
 setText('round',`第 ${cycle+1} 阵风`);
 setText('stage',$('reduce').checked?'静态云朵':mode==='idle'?'待机':stages[phase<.05?0:phase<.48?1:phase<.92?2:3]);
 setText('play',playing?'暂停':'播放');$('play').setAttribute('aria-pressed',String(playing));
 document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mode===mode)));
 setText('context',mode==='idle'?'待机 · 我在这里':'处理中 · 正在整理你的想法…');setText('small-status',mode==='idle'?'待机':'处理中');
}
function stop(){playing=false;last=null;if(raf!==null)cancelAnimationFrame(raf);raf=null;}
function start(){if($('reduce').checked)return;playing=true;last=null;if(raf===null&&!document.hidden)raf=requestAnimationFrame(tick);draw();}
function tick(now){
 raf=null;if(!playing||document.hidden)return;
 if(last!==null){
  const delta=Math.min((now-last)/1000,.08)*Number($('speed').value);
  time+=delta;referenceTime=(referenceTime+delta)%3.2;
  while(time>=cycleScore(cycle).duration){time-=cycleScore(cycle).duration;cycle++;}
 }
 last=now;draw();raf=requestAnimationFrame(tick);
}
$('play').onclick=()=>{if(playing)stop();else start();draw();};
$('replay').onclick=()=>{stop();time=0;referenceTime=0;start();draw();};
$('next').onclick=()=>{stop();cycle++;time=0;referenceTime=0;start();draw();};
$('seek').oninput=()=>{stop();time=Number($('seek').value);referenceTime=time;draw();};
document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{mode=b.dataset.mode;draw();});
document.querySelectorAll('[data-phase]').forEach(b=>b.onclick=()=>{stop();time=Number(b.dataset.phase)*cycleScore(cycle).duration;referenceTime=time;draw();});
$('theme').onclick=()=>{const dark=document.body.classList.toggle('dark');$('theme').setAttribute('aria-pressed',String(dark));setText('theme',dark?'浅色背景':'深色背景');};
function reduce(value){
 $('reduce').checked=value;if(value){stop();time=0;referenceTime=0;}
 for(const id of ['play','replay','next','seek'])$(id).disabled=value;
 document.querySelectorAll('[data-phase]').forEach(b=>b.disabled=value);draw();
}
$('reduce').onchange=()=>reduce($('reduce').checked);
const mq=matchMedia('(prefers-reduced-motion: reduce)');mq.addEventListener('change',e=>reduce(e.matches));
document.addEventListener('visibilitychange',()=>{last=null;if(document.hidden){if(raf!==null)cancelAnimationFrame(raf);raf=null;}else if(playing&&raf===null)raf=requestAnimationFrame(tick);});
reduce(mq.matches);$('loading').hidden=true;start();
