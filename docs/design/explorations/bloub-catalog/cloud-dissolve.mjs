// Whole-cloud alternative: reconstruct the pinned Cloud's original five lobes.
// Each lobe resolves into a small cloudlet; there is no rigid rotation or twist.
import {SHAPE_BY_ID} from './vendor/skins.mjs';
import {closedPath,unionOfCirclesProfile} from './vendor/shape.mjs';
const BASE=SHAPE_BY_ID.get('nuage').radii;
const LOBES=[{x:-.44,y:.2,r:.54},{x:.46,y:.2,r:.5},{x:.02,y:.3,r:.6},{x:-.24,y:-.3,r:.48},{x:.3,y:-.24,r:.44}];
const UNIT=80*1.02/Math.max(...unionOfCirclesProfile(LOBES));
const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x);};
const basePath=closedPath(BASE.map((r,i)=>({x:r*80*Math.cos(i/BASE.length*Math.PI*2),y:r*80*Math.sin(i/BASE.length*Math.PI*2)})));
// Seed once per cycle. Scrubbing is reproducible; no frame-random jitter.
function randomSource(cycle){let state=(Math.imul(cycle+1,0x9e3779b1)^0x6d2b79f5)>>>0;return ()=>{state=(Math.imul(state,1664525)+1013904223)>>>0;return state/4294967296;};}
const scores=new Map();
export function cycleScore(cycle=0){
 if(scores.has(cycle))return scores.get(cycle);
 const rand=randomSource(cycle),duration=2.2+rand()*.5,wind=(rand()-.5)*1.6-Math.PI/2;
 const targets=[];
 for(let i=0;i<LOBES.length;i++){
  // Select the best-spaced of several irregular candidates, not fixed slots.
  let target,best=-1;
  for(let j=0;j<24;j++){
   const angle=rand()*Math.PI*2,r=24+Math.sqrt(rand())*40;
   const candidate={x:Math.cos(angle)*r+Math.cos(wind)*13,y:Math.sin(angle)*r*.82+Math.sin(wind)*10};
   const distance=targets.length?Math.min(...targets.map(v=>Math.hypot(v.x-candidate.x,v.y-candidate.y))):rand()*100;
   if(distance>best){best=distance;target=candidate;}
  }
  targets.push(target);
 }
 const fragments=LOBES.map((c,i)=>({target:targets[i],outStart:.055+rand()*.075,outTime:.23+rand()*.105,
  inStart:.46+rand()*.105,inTime:.25+rand()*.105,
  bendOut:(rand()-.5)*44,bendIn:(rand()-.5)*44,drift:2+rand()*5,phase:rand()*Math.PI*2,
  minScale:.16+rand()*.13,fade:.58+rand()*.17}));
 const score={duration,fragments};scores.set(cycle,score);
 // A long-running preview should not retain every past cycle.
 if(scores.size>32)scores.delete(scores.keys().next().value);
 return score;
}
export function sampleDissolve(seconds,mode='thinking',cycle=0){
 const score=cycleScore(cycle),t=Math.max(0,Math.min(seconds,score.duration)),phase=t/score.duration;
 const fragments=LOBES.map((c,i)=>{
  const p=score.fragments[i],u=mode==='idle'?0:smooth((phase-p.outStart)/p.outTime),v=mode==='idle'?0:smooth((phase-p.inStart)/p.inTime);
  const q=u*(1-v),scale=1-(1-p.minScale)*q;
  const ox=c.x*UNIT,oy=c.y*UNIT,dx=p.target.x-ox,dy=p.target.y-oy,length=Math.hypot(dx,dy)||1;
  const arc=Math.sin(Math.PI*u)*(1-v)*p.bendOut+Math.sin(Math.PI*v)*u*p.bendIn;
  const drift=q*p.drift*Math.sin(phase*Math.PI*2+p.phase);
  const x=ox+dx*q-dy/length*arc+drift;
  const y=oy+dy*q+dx/length*arc-drift*.5;
  const cloudness=smooth((q-.2)/.6);
  const points=BASE.map((r,j)=>{const a=j/BASE.length*Math.PI*2;
   const rr=c.r*UNIT*scale*(1+cloudness*(r-.88));
   return {x:Math.cos(a)*rr,y:Math.sin(a)*rr};
  });
  return {path:closedPath(points),x,y,alpha:1-.96*smooth((q-p.fade)/(1-p.fade)),scale,spread:q};
 });
 const spread=Math.max(...fragments.map(f=>f.spread));
 return {t,spread,fragments,bodyPath:basePath,bodyAlpha:1-smooth(spread/.16),faceAlpha:1-smooth(spread/.36)};
}
let serial=0;
export function createDissolveRenderer(svg){
 const id=`dissolve-${++serial}`;
 svg.setAttribute('viewBox','-112 -104 224 208');svg.setAttribute('aria-hidden','true');
 svg.innerHTML=`<defs><filter id="${id}" x="-30%" y="-30%" width="160%" height="160%" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="1.1"/><feColorMatrix type="matrix" values="1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 18 -7"/></filter></defs><g class="fragments" fill="currentColor">${`<g><path filter="url(#${id})"/></g>`.repeat(5)}</g><path class="whole-body" fill="currentColor"/><g class="whole-face" fill="var(--eye, #f8f4ed)"><ellipse cx="-12" cy="-5" rx="6.1" ry="12"/><ellipse cx="14" cy="-5" rx="6.1" ry="12"/></g>`;
 const groups=[...svg.querySelector('.fragments').children],nodes=groups.map(g=>g.firstElementChild),body=svg.querySelector('.whole-body'),face=svg.querySelector('.whole-face');
 return frame=>{
  frame.fragments.forEach((f,i)=>{nodes[i].setAttribute('d',f.path);nodes[i].setAttribute('transform',`translate(${f.x} ${f.y})`);groups[i].setAttribute('opacity',f.alpha);});
  // Each cloudlet fades after filtering, avoiding alpha-threshold popping.
  body.setAttribute('d',frame.bodyPath);body.setAttribute('opacity',frame.bodyAlpha);face.setAttribute('opacity',frame.faceAlpha);
 };
}
