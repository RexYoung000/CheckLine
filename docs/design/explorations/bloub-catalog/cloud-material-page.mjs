import {MaterialStatePlayer} from './cloud-inner-flow.mjs';
import {materialRenderer} from './cloud-material.mjs';
const $=s=>document.querySelector(s),all=s=>[...document.querySelectorAll(s)];
const player=new MaterialStatePlayer(),canvases=all('[data-cloud]');
let renders=canvases.map(svg=>materialRenderer(svg)),flat=false,time=0,last=0,playing=true,oneShot=false;
const oldRender=materialRenderer($('#old-avatar'),{flat:true});
const copy={idle:['今天，从容一点。','我在这里，陪你理清每一笔。','我在这里','粉色与香槟色错拍漂移、舒展，身体轻轻悬浮。'],receive:['我收到啦。','抬起眼睛，回应你的输入。','收到输入','抬眼回应一次，内色色团继续飘动。'],thinking:['正在理一理。','一点点线索，慢慢变清楚。','正在思考 · 演示','双色流转，柔波沿边缘传递，眼睛短暂追视。'],waiting:['这笔，需要你看看。','等你确认后，再继续下一步。','等待确认','内色持续飘动，提示保留，等待你确认。'],success:['已经处理好了。','一次小小回应，然后继续陪着你。','处理完成 · 演示','眨眼回应一次，随后色团继续漂移。'],error:['这次没有完成。','内容还在，可以重新试一次。','需要重试 · 演示','内色继续漂移，提示保持清楚。']};
let selected='idle';
function draw(){const frame=player.sample();renders.forEach(render=>render(frame,time,player.reduced));oldRender(frame,time,player.reduced);}
function updateCopy(){const c=copy[selected];all('[data-heading]').forEach(n=>n.textContent=c[0]);all('[data-subtitle]').forEach(n=>n.textContent=c[1]);all('[data-state-label]').forEach(n=>n.textContent=c[2]);$('#motion-status').textContent=`${player.reduced?'静态审阅':!playing?'已暂停':flat?'原纯色对照':c[2]} · ${c[3]}`;}
function select(state){selected=state;player.select(state);if(!playing)player.from=null;oneShot=state==='receive'||state==='success';all('[data-state]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.state===state)));updateCopy();draw();}
all('[data-state]').forEach(button=>button.addEventListener('click',()=>select(button.dataset.state)));
$('#cancel').addEventListener('click',()=>select('idle'));
$('#play').addEventListener('click',()=>{playing=!playing;$('#play').textContent=playing?'暂停':'继续';$('#play').setAttribute('aria-pressed',String(playing));updateCopy();});
$('#material').addEventListener('click',()=>{flat=!flat;renders=canvases.map(svg=>materialRenderer(svg,{flat}));$('#material').textContent=flat?'返回透光材质':'对照原纯色';$('#material').setAttribute('aria-pressed',String(flat));document.body.classList.toggle('flat',flat);updateCopy();draw();});
const preference=matchMedia('(prefers-reduced-motion: reduce)');
function reduce(on){player.reduce(on);$('#reduce').checked=on;$('#play').disabled=on;playing=!on;$('#play').textContent=playing?'暂停':'继续';$('#play').setAttribute('aria-pressed',String(playing));updateCopy();draw();}
$('#reduce').addEventListener('change',e=>reduce(e.target.checked));preference.addEventListener('change',e=>reduce(e.matches));
document.addEventListener('visibilitychange',()=>{last=0;});
function tick(now){const dt=last?Math.min((now-last)/1000,.08):0;last=now;
 if(playing&&!player.reduced&&!document.hidden){time+=dt;player.step(dt);if(oneShot&&player.time>=1.15){oneShot=false;player.select('idle');}draw();}requestAnimationFrame(tick);}
reduce(preference.matches);select(location.hash==='#thinking'?'thinking':'idle');$('#loading').hidden=true;requestAnimationFrame(tick);
