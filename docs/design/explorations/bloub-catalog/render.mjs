// SVG layer order adapted from bloub's BloubBot.vue (MIT). See NOTICE.md.
import { mixHex } from './vendor/skins.mjs';
import { NOTIF_BLUE } from './vendor/decor.mjs';
let serial=0;
export function renderer(svg) {
 const uid=`bloub-${++serial}`;
 svg.setAttribute('viewBox','-158 -158 316 316');
 svg.setAttribute('aria-hidden','true');
 return (frame,ink='#0a0a0c',paper='#f9f9f9')=>{
  const dots=frame.dots.map(d=>{
   const fill=d.color??(d.depth===undefined?ink:mixHex(paper,ink,d.depth));
   const shape=d.d?`<path d="${d.d}" transform="translate(${d.x} ${d.y}) rotate(${d.rot??0}) scale(100)"`:`<circle cx="${d.x}" cy="${d.y}" r="${d.r}"`;
   return `${shape} fill="${fill}" opacity="${d.opacity}"/>`;
  }).join('');
  const arcs=side=>`<g fill="none" stroke-linecap="round">${frame.arcs.map(a=>`<path d="${a[side]}" stroke="url(#${uid}-${a.id})" stroke-width="${a.width}" opacity="${a.opacity}"/>`).join('')}</g>`;
  const circle=(p,fill)=>p?`<circle cx="${p.x}" cy="${p.y}" r="${p.r}" fill="${fill}"/>`:'';
  svg.innerHTML=`<defs><mask id="${uid}-mask" maskUnits="userSpaceOnUse" x="-158" y="-158" width="316" height="316"><path d="${frame.bodyPath}" fill="white"/>${frame.eyes.map(e=>`<path d="${e.d}" transform="${e.matrix}" opacity="${e.alpha}" fill="black"/>`).join('')}${circle(frame.notch,'black')}</mask>${frame.arcs.map(a=>`<linearGradient id="${uid}-${a.id}" gradientUnits="userSpaceOnUse" x1="${a.grad.x1}" y1="${a.grad.y1}" x2="${a.grad.x2}" y2="${a.grad.y2}">${a.grad.stops.map((c,i)=>`<stop offset="${i/(a.grad.stops.length-1)}" stop-color="${c}"/>`).join('')}</linearGradient>`).join('')}</defs>${arcs('back')}${frame.dotsBehind?dots:''}<g transform="rotate(${frame.bodyRotation??0})"><g opacity="${frame.bodyAlpha}"><path d="${frame.bodyPath}" fill="${paper}"/><g mask="url(#${uid}-mask)"><rect x="-158" y="-158" width="316" height="316" fill="${ink}"/></g></g></g>${frame.dotsBehind?'':dots}${circle(frame.notif,NOTIF_BLUE)}${arcs('front')}`;
 };
}
