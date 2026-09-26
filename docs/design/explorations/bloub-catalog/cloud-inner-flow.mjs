// CheckLine material motion study. Historical dissolve and vendor files stay intact.
import {stateFrame,blendFrames,STATES,smooth} from './cloud-states.mjs';
import {SHAPE_BY_ID} from './vendor/skins.mjs';
import {closedPath} from './vendor/shape.mjs';
import {liveliness,blinkScale} from './vendor/face.mjs';
const TAU=Math.PI*2,THINKING_PERIOD=2.25,BASE=SHAPE_BY_ID.get('nuage').radii;
const mix=(a,b,k)=>a+(b-a)*k;
const seed=(n,k)=>{let x=(Math.imul(n+19,374761393)^Math.imul(k+7,668265263))>>>0;x=Math.imul(x^(x>>>13),1274126177);return ((x^(x>>>16))>>>0)/4294967295;};
// Eased seeded targets keep changes reproducible and continuous, with no frame jitter.
export function wander(t,key,seconds=4.7){const p=t/seconds,n=Math.floor(p);return mix(seed(n,key),seed(n+1,key),smooth(p-n))*2-1;}
function contour(t,key){return closedPath(Array.from({length:10},(_,i)=>{const a=i/10*TAU,r=1+.13*wander(t,key+i,2.8+i*.19);return {x:Math.cos(a)*23*r,y:Math.sin(a)*22*r};}));}
function lightsAt(t,thinking,reduced){
 const drift=reduced?0:t;
 const lights=[{x:-13,y:-15,angle:0,sx:1,sy:1,opacity:.94,path:contour(drift,21)},
  {x:10,y:19,angle:0,sx:1.08,sy:.8,opacity:1,path:contour(drift,45)}];
 if(reduced)return lights;
 // A visible continuous drift prevents eased random targets from looking parked.
 // Different frequencies and smooth random offsets keep it from tracing fixed slots.
 lights.forEach((l,i)=>{const phase=i?1.5:-1.4;
  l.x+=16*Math.sin(t*(i?1.13:.91)+phase)+6*wander(t,1+i,3.1);
  l.y+=13*Math.cos(t*(i?.91:.73)+phase)+5*wander(t,5+i,2.8);
  l.angle=18*Math.sin(t*.63+phase)+13*wander(t,9+i,4.3);
  l.sx*=1+.16*wander(t,13+i,2.7);l.sy*=1+.17*wander(t,17+i,3.2);});
 if(!thinking)return lights;
 const phase=TAU*t/THINKING_PERIOD+.32*Math.sin(t*.76)+.16*Math.sin(t*1.37);
 lights.forEach((l,i)=>{const p=phase+(i?.65:-2.15)+.22*Math.sin(t*(i?.83:1.1));
  l.x=Math.cos(p)*(19+3*wander(t,31+i,4.2))+2*Math.sin(t*.59);
  l.y=3+Math.sin(p)*(16+2.5*wander(t,37+i,5));
  l.angle=38*Math.sin(p+.4);l.sx=(i?1.12:1.02)+.25*Math.sin(p*.94+.7);
  l.sy=.86+.19*Math.cos(p+.6);l.opacity=i?1:.94;l.path=contour(t*1.3,21+i*24);});
 return lights;
}
function gaze(t){
 const points=[[0,-2,-3],[.16,-2,-3],[.34,3,-1],[.48,3,-1],[.66,1,-4],[.82,1,-4],[1,-2,-3]],u=(t/THINKING_PERIOD)%1;
 const next=points.findIndex(p=>p[0]>u),a=points[next-1],b=points[next],k=smooth((u-a[0])/(b[0]-a[0]));
 return {x:mix(a[1],b[1],k),y:mix(a[2],b[2],k)};
}
export function innerFlowFrame(state,time=0,elapsed=0,reduced=false){
 const thinking=state==='thinking';
 const frame=stateFrame(thinking?'idle':state,thinking?0:time,0,reduced);
 frame.lights=lightsAt(elapsed,thinking,reduced);
 if(!thinking)return frame;
 const look=reduced?{x:1,y:-3}:gaze(elapsed),blink=reduced?1:blinkScale(liveliness(elapsed,{float:false}).lid);
 frame.eyes.forEach(e=>{e.x+=look.x;e.y+=look.y;e.ry*=.88*blink;});
 if(reduced)return frame;
 // A travelling local swell follows the current; the base Cloud never rotates.
 const p=TAU*elapsed/THINKING_PERIOD+.32*Math.sin(elapsed*.76)+.16*Math.sin(elapsed*1.37)-2.55;
 frame.bodyPath=closedPath(BASE.map((radius,i)=>{const a=i/BASE.length*TAU;
  const swell=4.1*Math.exp((Math.cos(a-p)-1)*3.8)-1.65*Math.exp((Math.cos(a-p+.8)-1)*5);
  const r=radius*80+swell;return {x:r*Math.cos(a),y:r*Math.sin(a)};}));
 return frame;
}
const number=/-?\d*\.?\d+(?:e[+-]?\d+)?/gi;
function pathMix(a,b,k){if(k<=0)return a;if(k>=1)return b;const aa=a.match(number).map(Number);let i=0;return b.replace(number,n=>mix(aa[i++],Number(n),k).toFixed(3));}
export function blendMaterial(a,b,k){
 const f=blendFrames(a,b,k);
 f.lights=a.lights.map((p,i)=>{const q=b.lights[i];return {path:pathMix(p.path,q.path,k),...Object.fromEntries(['x','y','angle','sx','sy','opacity'].map(key=>[key,mix(p[key],q[key],k)]))};});
 return f;
}
export class MaterialStatePlayer{
 constructor(){this.state='idle';this.time=0;this.elapsed=0;this.enter=0;this.from=null;this.reduced=false;}
 sample(){const target=innerFlowFrame(this.state,this.time,this.elapsed,this.reduced);return this.from&&!this.reduced?blendMaterial(this.from,target,smooth(this.enter/.48)):target;}
 select(state){if(!STATES.includes(state))throw Error('Unknown cloud state');const current=this.sample();this.state=state;this.time=0;this.enter=0;this.from=current;}
 step(dt){if(this.reduced)return;this.time+=dt;this.elapsed+=dt;this.enter+=dt;if(this.enter>=.48)this.from=null;}
 reduce(on){const current=this.sample();this.reduced=on;this.enter=0;this.from=on?null:current;}
}
