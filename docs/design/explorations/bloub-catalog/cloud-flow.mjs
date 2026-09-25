// Independent 2D cloud study. Uses the pinned bloub Cloud silhouette only;
// no orbit poses, body rotation, or external particle library. See NOTICE.md.
import { SHAPE_BY_ID } from './vendor/skins.mjs';
import { closedPath } from './vendor/shape.mjs';
const BASE=SHAPE_BY_ID.get('nuage').radii;
export const DURATION=6.4;
const TAU=Math.PI*2;
const clamp=x=>Math.max(0,Math.min(1,x));
const smooth=x=>{x=clamp(x);return x*x*(3-2*x);};
const windowAt=(t,a,b,c,d)=>smooth((t-a)/(b-a))*(1-smooth((t-c)/(d-c)));
const angleDistance=(a,b)=>Math.atan2(Math.sin(a-b),Math.cos(a-b));
const local=(a,b,w)=>Math.exp(-Math.pow(angleDistance(a,b)/w,2));
const radius=a=>{const k=((a/TAU%1+1)%1)*BASE.length;const i=Math.floor(k);return 80*(BASE[i]*(1-k+i)+BASE[(i+1)%BASE.length]*(k-i));};
export function sampleFlow(seconds,mode='thinking'){
 const t=((seconds%DURATION)+DURATION)%DURATION;
 const amount=mode==='idle'?.34:1;
 const intake=windowAt(t,.35,1.6,2.6,4.0),release=windowAt(t,2.9,3.8,4.8,6.15);
 const points=BASE.map((r,i)=>{
  const a=i/BASE.length*TAU;
  // Local volume changes only. Every central point and the face remain fixed.
  const growth=6*intake*local(a,2.65,.46);
  const crest=2.5*windowAt(t,1.5,2.4,3.0,4.2)*local(a,-2.1,.5);
  const erosion=8.5*release*local(a,-.64,.38);
  const rr=r*80+amount*(growth+crest-erosion);
  return {x:Math.cos(a)*rr,y:Math.sin(a)*rr};
 });
 const puffs=Array.from({length:3},(_,i)=>{
  const p=clamp((t-.18-i*.25)/2.35),s=smooth(p);
  return {x:-116+56*s+i*2,y:53-28*s+(i-1)*7,r:(5.5+i*2.6)*amount*(.65+.35*s),alpha:amount*windowAt(t,.18+i*.25,.7+i*.25,2.0+i*.18,2.65+i*.18)};
 });
 const grains=Array.from({length:28},(_,i)=>{
  // Fixed lanes, no frame-random noise. Each grain starts at the eroding rim.
  const birth=3.12+(i%7)*.18+Math.floor(i/7)*.08;
  const p=clamp((t-birth)/1.48),a=-.94+(i%7)*.085;
  const r=radius(a)-3;
  const drift=13+((i*7)%13);
  return {x:Math.cos(a)*r+drift*p,y:Math.sin(a)*r-(12+(i%5)*3)*p,
   r:(.8+(i%4)*.37)*amount*(1-.55*p),alpha:amount*Math.pow(Math.sin(Math.PI*p),2)*(.45+(i%3)*.15)};
 });
 // Soft clusters make direction legible at avatar size; fine grains stay local.
 for(let i=0;i<3;i++){
  const p=clamp((t-3.1-i*.25)/1.9),a=-.8+i*.16,r=radius(a)-4;
  grains.push({x:Math.cos(a)*r+21*p,y:Math.sin(a)*r-18*p,r:(3.5-i*.55)*amount*(1-.7*p),alpha:amount*Math.pow(Math.sin(Math.PI*p),2)*.6});
 }
 const glance=windowAt(t,.3,.9,1.4,2.2);
 const blink=windowAt(t,5.5,5.59,5.64,5.76);
 return {path:closedPath(points),points,puffs,grains,eyeX:-1.5*glance*amount,eyeY:glance*.8*amount,eyeH:12*(1-.88*blink),t};
}
// At 44 px, fine grain is subpixel. Use a separate silhouette-and-cloudlet
// score, twice per large-preview cycle, with a stable face and center.
export function sampleCompactFlow(seconds,mode='thinking'){
 const duration=DURATION/2,t=((seconds%duration)+duration)%duration;
 const active=mode==='thinking'?1:0;
 const incoming=windowAt(t,0,.7,1.15,1.8);
 const departing=windowAt(t,.95,1.6,2.25,3.2);
 const points=BASE.map((r,i)=>{
  const a=i/BASE.length*TAU;
  const delta=16*incoming*local(a,2.65,.55)
   +11*windowAt(t,.6,1.3,1.65,2.35)*local(a,-1.95,.5)
   -15*departing*local(a,-.58,.45);
  const rr=r*80+active*delta;
  return {x:Math.cos(a)*rr,y:Math.sin(a)*rr};
 });
 const puffs=Array.from({length:3},(_,i)=>{
  const p=smooth((t-i*.18)/1.35);
  return {x:-96+40*p+i*3,y:42-14*p+(i-1)*6,r:(9+i*1.8),alpha:active*windowAt(t,i*.18,.25+i*.18,1.15+i*.1,1.65+i*.1)};
 });
 const grains=Array.from({length:31},(_,i)=>{
  if(i>=2)return {x:0,y:0,r:0,alpha:0};
  const p=clamp((t-1.25-i*.27)/1.55),a=-.7+i*.18,r=radius(a)-10;
  return {x:Math.cos(a)*r+30*p,y:Math.sin(a)*r-23*p,r:(10-i*2.2)*(1-.72*p),alpha:active*windowAt(p,0,.2,.68,1)};
 });
 const blink=windowAt(t,2.68,2.77,2.81,2.93);
 return {path:closedPath(points),points,puffs,grains,eyeX:0,eyeY:0,eyeH:12*(1-.88*blink),t};
}
let serial=0;
export function createFlowRenderer(svg,{compact=false}={}){
 const id=`cloud-flow-${++serial}`;
 svg.setAttribute('viewBox',compact?'-108 -102 216 204':'-145 -118 290 236');svg.setAttribute('aria-hidden','true');
 svg.innerHTML=`<defs><filter id="${id}" x="-35%" y="-35%" width="170%" height="170%" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="1.3"/><feColorMatrix type="matrix" values="1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 18 -7"/></filter></defs><g fill="currentColor" filter="url(#${id})"><path class="body"/>${'<circle class="puff"/>'.repeat(3)}</g><g fill="currentColor">${'<circle class="grain"/>'.repeat(31)}</g><g fill="var(--eye, #f8f4ed)" class="face"><ellipse cx="-12" cy="-5" rx="6.1" ry="12"/><ellipse cx="14" cy="-5" rx="6.1" ry="12"/></g>`;
 const body=svg.querySelector('.body'),puffs=[...svg.querySelectorAll('.puff')],grains=[...svg.querySelectorAll('.grain')],face=svg.querySelector('.face'),eyes=[...face.children];
 const circles=(nodes,data)=>nodes.forEach((n,i)=>{const d=data[i];n.setAttribute('cx',d.x);n.setAttribute('cy',d.y);n.setAttribute('r',d.r);n.setAttribute('opacity',d.alpha);});
 return frame=>{body.setAttribute('d',frame.path);circles(puffs,frame.puffs);circles(grains,frame.grains);face.setAttribute('transform',`translate(${frame.eyeX} ${frame.eyeY})`);eyes.forEach(e=>e.setAttribute('ry',frame.eyeH));};
}
