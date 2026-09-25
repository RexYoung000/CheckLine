// Whole-cloud alternative: reconstruct the pinned Cloud's original five lobes.
// Each lobe resolves into a small cloudlet; there is no rigid rotation or twist.
import {SHAPE_BY_ID} from './vendor/skins.mjs';
import {closedPath,unionOfCirclesProfile} from './vendor/shape.mjs';
export const DISSOLVE_DURATION=2.4;
const BASE=SHAPE_BY_ID.get('nuage').radii;
const LOBES=[{x:-.44,y:.2,r:.54},{x:.46,y:.2,r:.5},{x:.02,y:.3,r:.6},{x:-.24,y:-.3,r:.48},{x:.3,y:-.24,r:.44}];
const UNIT=80*1.02/Math.max(...unionOfCirclesProfile(LOBES));
const smooth=x=>{x=Math.max(0,Math.min(1,x));return x*x*(3-2*x);};
const basePath=closedPath(BASE.map((r,i)=>({x:r*80*Math.cos(i/BASE.length*Math.PI*2),y:r*80*Math.sin(i/BASE.length*Math.PI*2)})));
export function sampleDissolve(seconds,mode='thinking'){
 const t=((seconds%DISSOLVE_DURATION)+DISSOLVE_DURATION)%DISSOLVE_DURATION;
 const spread=mode==='idle'?0:smooth((t-.18)/.78)*(1-smooth((t-1.08)/1.04));
 const fragments=LOBES.map((c,i)=>{
  const q=spread;
  const scale=1-.79*q;
  const x=c.x*UNIT*(1+.8*q)+(i%2?18:9)*q;
  const y=c.y*UNIT*(1+.65*q)-(10+i*1.5)*q;
  const cloudness=smooth((q-.2)/.6);
  const points=BASE.map((r,j)=>{const a=j/BASE.length*Math.PI*2;
   const rr=c.r*UNIT*scale*(1+cloudness*(r-.88));
   return {x:Math.cos(a)*rr,y:Math.sin(a)*rr};
  });
  return {path:closedPath(points),x,y,alpha:1-.96*smooth((q-.72)/.28),scale};
 });
 return {t,spread,fragments,bodyPath:basePath,bodyAlpha:1-smooth(spread/.16),faceAlpha:1-smooth(spread/.36)};
}
let serial=0;
export function createDissolveRenderer(svg){
 const id=`dissolve-${++serial}`;
 svg.setAttribute('viewBox','-112 -104 224 208');svg.setAttribute('aria-hidden','true');
 svg.innerHTML=`<defs><filter id="${id}" x="-30%" y="-30%" width="160%" height="160%" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="1.1"/><feColorMatrix type="matrix" values="1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 18 -7"/></filter></defs><g class="fragments" fill="currentColor" filter="url(#${id})">${'<path/>'.repeat(5)}</g><path class="whole-body" fill="currentColor"/><g class="whole-face" fill="var(--eye, #f8f4ed)"><ellipse cx="-12" cy="-5" rx="6.1" ry="12"/><ellipse cx="14" cy="-5" rx="6.1" ry="12"/></g>`;
 const nodes=[...svg.querySelector('.fragments').children],body=svg.querySelector('.whole-body'),face=svg.querySelector('.whole-face');
 return frame=>{
  frame.fragments.forEach((f,i)=>{nodes[i].setAttribute('d',f.path);nodes[i].setAttribute('transform',`translate(${f.x} ${f.y})`);});
  // Fade after the union filter so alpha does not pop across its threshold.
  svg.querySelector('.fragments').setAttribute('opacity',frame.fragments[0].alpha);
  body.setAttribute('d',frame.bodyPath);body.setAttribute('opacity',frame.bodyAlpha);face.setAttribute('opacity',frame.faceAlpha);
 };
}
