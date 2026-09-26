import {CloudStatePlayer,stateRenderer} from './cloud-states.mjs';
import {materialRenderer} from './cloud-material.mjs';
const $=s=>document.querySelector(s),all=s=>[...document.querySelectorAll(s)];
const player=new CloudStatePlayer(),canvases=all('[data-cloud]');
let renders=canvases.map(materialRenderer),flat=false,time=0,last=0,playing=true,oneShot=false;
const oldRender=stateRenderer($('#old-avatar'));
const copy={idle:['今天，从容一点。','我在这里，陪你理清每一笔。','我在这里','身体缓慢悬浮，内层颜色稍慢一步。'],receive:['我收到啦。','抬起眼睛，回应你的输入。','收到输入','一次抬眼回应，然后恢复平静。'],thinking:['正在理一理。','把线索聚起来，再慢慢理清。','正在处理','整片云团带着柔光散开，再自然聚拢。'],waiting:['这笔，需要你看看。','等你确认后，再继续下一步。','等待确认','提示保持可见，安静等待，不自动完成。'],success:['已经处理好了。','一次小小回应，然后继续陪着你。','处理完成 · 演示','短暂眨眼回应，材质和轮廓保持稳定。'],error:['这次没有完成。','内容还在，可以重新试一次。','需要重试 · 演示','用提示和文字说明，避免反复闪动。']};
// Material review continues; the old dissolve is retained only as a comparison.
copy.thinking=['旧聚散动作对照','新的思考态将讨论内层流动与轮廓波动。','旧动作 · 待替换','仅供对照，不再作为透光形象的推荐思考态。'];
let selected='idle';
function draw(){const frame=player.sample();renders.forEach(render=>render(frame,time,player.reduced));oldRender(frame);}
function updateCopy(){const c=copy[selected];all('[data-heading]').forEach(n=>n.textContent=c[0]);all('[data-subtitle]').forEach(n=>n.textContent=c[1]);all('[data-state-label]').forEach(n=>n.textContent=c[2]);$('#motion-status').textContent=`${player.reduced?'静态审阅':!playing?'已暂停':flat?'原纯色对照':c[2]} · ${c[3]}`;}
function select(state){selected=state;player.select(state);oneShot=state==='receive'||state==='success';all('[data-state]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.state===state)));updateCopy();draw();}
all('[data-state]').forEach(button=>button.addEventListener('click',()=>select(button.dataset.state)));
$('#cancel').addEventListener('click',()=>select('idle'));
$('#play').addEventListener('click',()=>{playing=!playing;$('#play').textContent=playing?'暂停':'继续';$('#play').setAttribute('aria-pressed',String(playing));updateCopy();});
$('#material').addEventListener('click',()=>{flat=!flat;renders=canvases.map(flat?stateRenderer:materialRenderer);$('#material').textContent=flat?'返回透光材质':'对照原纯色';$('#material').setAttribute('aria-pressed',String(flat));document.body.classList.toggle('flat',flat);updateCopy();draw();});
const preference=matchMedia('(prefers-reduced-motion: reduce)');
function reduce(on){player.reduce(on);$('#reduce').checked=on;$('#play').disabled=on;playing=!on;$('#play').textContent=playing?'暂停':'继续';$('#play').setAttribute('aria-pressed',String(playing));updateCopy();draw();}
$('#reduce').addEventListener('change',e=>reduce(e.target.checked));preference.addEventListener('change',e=>reduce(e.matches));
document.addEventListener('visibilitychange',()=>{last=0;});
function tick(now){const dt=last?Math.min((now-last)/1000,.08):0;last=now;
 if(playing&&!player.reduced&&!document.hidden){time+=dt;player.step(dt);if(oneShot&&player.time>=1.15){oneShot=false;player.select('idle');}draw();}requestAnimationFrame(tick);}
reduce(preference.matches);$('#loading').hidden=true;requestAnimationFrame(tick);
