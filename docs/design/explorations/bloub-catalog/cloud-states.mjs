// CheckLine proposals using pinned bloub eye poses and liveliness (MIT; NOTICE.md).
// The accepted dissolve sampler remains unchanged.
import {cycleScore,sampleDissolve,createDissolveRenderer} from './cloud-dissolve.mjs';
import {liveliness,blinkScale,EYE_W,EYE_H} from './vendor/face.mjs';
import {STATE_BY_ID} from './vendor/states.mjs';
export const STATES=['idle','receive','thinking','waiting','success','error'];
export const smooth=t=>{t=Math.max(0,Math.min(1,t));return t*t*(3-2*t);};
const mix=(a,b,k)=>a+(b-a)*k;
const eye=(x)=>({x,y:-5,rx:6.1,ry:12});
const rest=()=>({...sampleDissolve(0,'idle'),eyes:[eye(-12),eye(14)],badge:0,error:0});
function eyesFor(id){
 const p=STATE_BY_ID.get(id).pose(0);
 // Adapt source expression proportions to the accepted flat, forward-facing eyes.
 return p.eyes.map((e,i)=>({x:(i?14:-12)+p.gaze.yaw*.15,y:-5+p.gaze.pitch*.13,
  rx:6.1*mix(1,e.w/EYE_W,.55),ry:12*mix(1,e.h/EYE_H,.62)}));
}
export function stateFrame(state,time=0,cycle=0,reduced=false){
 const f=rest();
 if(state==='thinking'&&!reduced)return {...sampleDissolve(time,'thinking',cycle),eyes:f.eyes,badge:0,error:0};
 if(state==='idle'&&!reduced){const life=liveliness(time%890,{float:false});f.eyes.forEach(e=>{e.x+=life.dYaw*.42;e.y-=life.dPitch*.35;e.ry*=blinkScale(life.lid);});}
 if(state==='receive')f.eyes=eyesFor('wide');
 if(state==='waiting'){f.eyes=eyesFor('notify');f.badge=1;}
 if(state==='success'){f.eyes=eyesFor('wink');f.eyes[1].ry=2.6;}
 if(state==='error'){f.badge=1;f.error=1;}
 return f;
}
// All cloudlet contours have the same command topology. Blend numeric coordinates
// instead of scaling/rotating the whole character or crossfading two characters.
const number=/-?\d*\.?\d+(?:e[+-]?\d+)?/gi;
function pathMix(a,b,k){if(k===0)return a;if(k===1)return b;const aa=a.match(number).map(Number);let i=0;return b.replace(number,n=>mix(aa[i++],Number(n),k).toFixed(3));}
export function blendFrames(a,b,k){
 if(k<=0)return structuredClone(a);if(k>=1)return structuredClone(b);
 const f={...b,bodyPath:pathMix(a.bodyPath,b.bodyPath,k)};
 for(const key of ['bodyAlpha','faceAlpha','spread','badge','error'])f[key]=mix(a[key],b[key],k);
 // Keep the face attached to the re-forming body, even when interrupted mid-dissolve.
 f.faceAlpha=Math.min(f.faceAlpha,1-smooth(f.spread/.36));
 f.eyes=a.eyes.map((e,i)=>Object.fromEntries(Object.keys(e).map(key=>[key,mix(e[key],b.eyes[i][key],k)])));
 f.fragments=a.fragments.map((p,i)=>{const q=b.fragments[i];return {path:pathMix(p.path,q.path,k),...Object.fromEntries(['x','y','alpha','scale','spread'].map(key=>[key,mix(p[key],q[key],k)]))};});
 return f;
}
export class CloudStatePlayer{
 constructor(){this.state='idle';this.time=0;this.cycle=0;this.enter=0;this.from=null;this.reduced=false;}
 sample(){const f=stateFrame(this.state,this.time,this.cycle,this.reduced);return this.from&&!this.reduced?blendFrames(this.from,f,smooth(this.enter/.38)):f;}
 select(state){if(!STATES.includes(state))throw Error('Unknown cloud state');const current=this.sample();this.state=state;this.time=0;this.enter=0;this.from=current;}
 step(dt){if(this.reduced)return;this.time+=dt;this.enter+=dt;if(this.enter>=.38)this.from=null;
  if(this.state==='thinking')while(this.time>=cycleScore(this.cycle).duration){this.time-=cycleScore(this.cycle).duration;this.cycle++;}}
 reduce(on){const current=this.sample();this.reduced=on;this.enter=0;this.time=0;this.from=on?null:current;}
}
export function stateRenderer(svg){
 const base=createDissolveRenderer(svg),face=svg.querySelector('.whole-face'),eyes=[...face.children];
 const ns='http://www.w3.org/2000/svg';
 const badge=document.createElementNS(ns,'g');badge.innerHTML='<circle cx="65" cy="-50" r="13" fill="var(--paper)"/><circle cx="65" cy="-50" r="9" fill="var(--accent)"/><path d="M65 -55v5m0 4v.4" stroke="var(--paper)" stroke-width="2.7" stroke-linecap="round"/>';
 svg.append(badge);const mark=badge.lastElementChild;
 return f=>{base(f);f.eyes.forEach((e,i)=>{for(const [key,attr] of [['x','cx'],['y','cy'],['rx','rx'],['ry','ry']])eyes[i].setAttribute(attr,e[key]);});badge.setAttribute('opacity',f.badge);mark.setAttribute('opacity',f.error);};
}
