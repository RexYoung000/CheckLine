import {DURATION,sampleFlow,sampleCompactFlow,createFlowRenderer} from './cloud-flow.mjs';
const $=id=>document.getElementById(id);
const renderers=[...document.querySelectorAll('[data-cloud]')].map(svg=>({draw:createFlowRenderer(svg,{compact:svg.dataset.cloud==='compact'}),compact:svg.dataset.cloud==='compact'}));
let time=0,playing=false,last=null,raf=null,mode='thinking';
const setText=(id,text)=>{if($(id).textContent!==text)$(id).textContent=text;};
const stages=['云絮靠近','融入轮廓','边缘消散','回到完整云朵'];
function draw(){const frame=sampleFlow(time,mode);const small=sampleCompactFlow(time,mode);renderers.forEach(r=>r.draw(r.compact?small:frame));$('seek').value=time;$('timer').textContent=`${time.toFixed(1)} / ${DURATION.toFixed(1)} 秒`;$('stage').textContent=$('reduce').checked?'静态云朵':stages[time<1.1?0:time<3.1?1:time<5.3?2:3];$('play').textContent=playing?'暂停':'播放';$('play').setAttribute('aria-pressed',String(playing));document.querySelectorAll('[data-mode]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.mode===mode)));setText('context',mode==='idle'?'待机 · 我在这里':'处理中 · 正在整理你的想法…');setText('small-status',mode==='idle'?'待机':'处理中');}
function stop(){playing=false;last=null;if(raf!==null)cancelAnimationFrame(raf);raf=null;}
function start(){if($('reduce').checked)return;playing=true;last=null;if(raf===null&&!document.hidden)raf=requestAnimationFrame(tick);draw();}
function tick(now){raf=null;if(!playing||document.hidden)return;if(last!==null)time=(time+Math.min((now-last)/1000,.08)*Number($('speed').value))%DURATION;last=now;draw();raf=requestAnimationFrame(tick);}
$('play').onclick=()=>{if(playing)stop();else start();draw();};
$('replay').onclick=()=>{stop();time=0;start();draw();};
$('seek').oninput=()=>{stop();time=Number($('seek').value);draw();};
document.querySelectorAll('[data-mode]').forEach(b=>b.onclick=()=>{mode=b.dataset.mode;draw();});
document.querySelectorAll('[data-time]').forEach(b=>b.onclick=()=>{stop();time=Number(b.dataset.time);draw();});
$('theme').onclick=()=>{const dark=document.body.classList.toggle('dark');$('theme').setAttribute('aria-pressed',String(dark));$('theme').textContent=dark?'浅色背景':'深色背景';};
function reduce(value){$('reduce').checked=value;if(value){stop();time=0;}$('play').disabled=value;$('replay').disabled=value;$('seek').disabled=value;document.querySelectorAll('[data-time]').forEach(b=>b.disabled=value);draw();}
$('reduce').onchange=()=>reduce($('reduce').checked);
const mq=matchMedia('(prefers-reduced-motion: reduce)');mq.addEventListener('change',e=>reduce(e.matches));
document.addEventListener('visibilitychange',()=>{last=null;if(document.hidden){if(raf!==null)cancelAnimationFrame(raf);raf=null;}else if(playing&&raf===null)raf=requestAnimationFrame(tick);});
reduce(mq.matches);$('loading').hidden=true;start();
