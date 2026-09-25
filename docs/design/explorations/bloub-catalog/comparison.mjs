import {engine,hold,IDS} from './cloud-variants.mjs';
import {renderer} from './render.mjs';
const $=id=>document.getElementById(id);
const info={orbit:['轨道','原版：三角形旋转 → 圆球 → 云朵','云朵版：本体旋转一周，眼睛随身体转动，三条轨道独立绕行','观察云朵整体旋转是否舒服：眼睛随身体转动，起止逐渐加减速；中途切换或取消会就近回正。'],burst:['聚合','原版：圆球收缩 → 颗粒汇入 → 圆球 → 云朵','云朵版：收成小核 → 颗粒汇入 → 云瓣直接长开','重点看重新长大的一刻：云瓣应在主体长大前出现，眼睛随着身体恢复。'],comet:['彗星','原版：圆球收缩 → 拖尾环绕 → 圆球 → 云朵','云朵版：收拢 → 拖尾环绕 → 直接展开为云朵','重点看拖尾退场与云瓣展开是否连贯；原版彩色拖尾保留，配色还可继续讨论。']};
const draws=[renderer($('original')),renderer($('cloud')),renderer($('original-small')),renderer($('cloud-small'))];
let chosen='orbit',events=[],time=0,end=0,playing=false,last=null,raf=null;
function setup(id){events=[{id:'idle',at:0},{id,at:.6},{id:'idle',at:.6+hold(id)}];time=0;end=hold(id)+1.8;}
function sample(adapted){const e=engine(adapted);for(const v of events){if(v.at>time)break;e.setState(v.id,v.at);}return e.sample(time);}
function render(){const ink=$('palette').value==='purple'?'#78648c':'#0a0a0c';const a=sample(false),b=sample(true);draws[0](a,ink);draws[1](b,ink);draws[2](a,ink);draws[3](b,ink);$('seek').max=String(end);$('seek').value=String(time);$('timer').textContent=`${time.toFixed(1)} / ${end.toFixed(1)} 秒`;$('play').textContent=playing?'暂停':'播放';$('play').setAttribute('aria-pressed',String(playing));const state=events.filter(e=>e.at<=time).at(-1)?.id||'idle';$('phase').textContent=$('reduce').checked?'静态观察':state==='idle'?'云朵 / 归位':info[state][0];}
function labels(){const [name,left,right,note]=info[chosen];$('current').textContent=name;$('left-note').textContent=left;$('right-note').textContent=right;$('observe').textContent=note;document.querySelectorAll('[data-action]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.action===chosen)));}
function stop(){playing=false;last=null;if(raf!==null)cancelAnimationFrame(raf);raf=null;}
function start(){if($('reduce').checked)return;if(time>=end){setup(chosen);}playing=true;last=null;render();if(raf===null&&!document.hidden)raf=requestAnimationFrame(tick);}
function tick(now){raf=null;if(!playing||document.hidden)return;if(last!==null)time+=Math.min((now-last)/1000,.064)*Number($('speed').value);last=now;if(time>=end){if($('loop').checked){const remainder=time-end;setup(chosen);time=remainder;}else{time=end;stop();}}render();if(playing)raf=requestAnimationFrame(tick);}
function interrupt(id){events=events.filter(e=>e.at<time);events.push({id,at:time});if(id!=='idle'){events.push({id:'idle',at:time+hold(id)});end=time+hold(id)+1.2;}else end=time+1.2;}
document.querySelectorAll('[data-action]').forEach(b=>b.onclick=()=>{chosen=b.dataset.action;if(playing)interrupt(chosen);else setup(chosen);labels();if(!playing)start();render();});
$('play').onclick=()=>{if(playing)stop();else start();render();};
$('replay').onclick=()=>{stop();setup(chosen);start();render();};
$('cancel').onclick=()=>{$('loop').checked=false;interrupt('idle');if($('reduce').checked)time=end;else start();render();};
$('seek').oninput=()=>{stop();time=Number($('seek').value);render();};
$('palette').onchange=render;
function reduce(v){$('reduce').checked=v;if(v)stop();$('play').disabled=v;$('replay').disabled=v;render();}
$('reduce').onchange=()=>reduce($('reduce').checked);
const mq=matchMedia('(prefers-reduced-motion: reduce)');mq.addEventListener('change',e=>reduce(e.matches));
document.addEventListener('visibilitychange',()=>{last=null;if(document.hidden){if(raf!==null)cancelAnimationFrame(raf);raf=null;}else if(playing&&raf===null)raf=requestAnimationFrame(tick);});
setup(chosen);labels();reduce(mq.matches);$('loading').hidden=true;
