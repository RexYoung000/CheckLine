// Material-only adaptation; the accepted dissolve geometry stays in cloud-dissolve.mjs.
let serial=0;
export function floatPose(t,reduced=false){
 if(reduced)return {x:0,y:0,lightX:0,lightY:0};
 // Incommensurate slow waves avoid a short, clockwork bobbing loop.
 return {x:1.6*Math.sin(t*.53)+.65*Math.sin(t*.91),y:3.1*Math.sin(t*.82)+.85*Math.sin(t*.37),
  lightX:5*Math.sin(t*.53-.6),lightY:3.5*Math.sin(t*.82-.7)};
}
export function materialRenderer(svg){
 const id=`cloud-glass-${++serial}`,small=svg.hasAttribute('data-small');
 svg.setAttribute('viewBox','-112 -104 224 208');svg.setAttribute('aria-hidden','true');
 const light=`<g class="light" filter="url(#${id}-blur)"><ellipse cx="-19" cy="-21" rx="29" ry="33" fill="#ec8cce" opacity=".88"/><path d="M-31 21 Q-8 3 10 8 T39 27 Q10 21-13 46Z" fill="#ffe3a8"/><ellipse cx="9" cy="55" rx="47" ry="22" fill="#a99dff" opacity=".76"/></g>`;
 const material=(key)=>`<g class="piece" data-piece="${key}"><path class="surface" fill="url(#${id}-shell)"/><g clip-path="url(#${id}-clip-${key})">${light}<path class="edge-dark" fill="none" stroke="#2c164d" stroke-width="9" opacity=".48" filter="url(#${id}-edge)"/><path class="edge-light" fill="none" stroke="url(#${id}-rim)" stroke-width="6" filter="url(#${id}-edge)"/></g><path class="rim" fill="none" stroke="url(#${id}-rim)" stroke-width=".85"/></g>`;
 svg.innerHTML=`<defs>
 <linearGradient id="${id}-shell" x1=".05" y1="0" x2=".68" y2="1" gradientUnits="objectBoundingBox"><stop stop-color="#8976bd"/><stop offset=".18" stop-color="#4c317b"/><stop offset=".48" stop-color="#563496"/><stop offset=".79" stop-color="#7860c9"/><stop offset="1" stop-color="#a698ed"/></linearGradient>
 <linearGradient id="${id}-rim" x1="0" y1="0" x2=".68" y2="1" gradientUnits="objectBoundingBox"><stop stop-color="#f3e8ff" stop-opacity=".95"/><stop offset=".29" stop-color="#c6b3f9" stop-opacity=".12"/><stop offset=".65" stop-color="#7561b5" stop-opacity=".1"/><stop offset="1" stop-color="#e8ddff" stop-opacity=".8"/></linearGradient>
 <filter id="${id}-blur" x="-70%" y="-70%" width="240%" height="240%" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="${small?7:9}"/></filter>
 <filter id="${id}-edge" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="2.8"/></filter>
 <filter id="${id}-eye" x="-100%" y="-50%" width="300%" height="200%"><feGaussianBlur stdDeviation="2"/></filter>
 <filter id="${id}-union-edge" x="-20%" y="-20%" width="140%" height="140%" color-interpolation-filters="sRGB"><feGaussianBlur in="SourceAlpha" stdDeviation="1.8" result="soft"/><feOffset in="soft" dx="1" dy="2" result="offset"/><feComposite in="SourceAlpha" in2="offset" operator="out" result="edge"/><feFlood flood-color="#e0cfff" flood-opacity=".65"/><feComposite in2="edge" operator="in"/><feComposite in2="SourceGraphic" operator="over"/></filter>
 <clipPath id="${id}-clip-body"><path/></clipPath>
 <mask id="${id}-union" maskUnits="userSpaceOnUse" x="-112" y="-104" width="224" height="208" style="mask-type:alpha">${'<path fill="white"/>'.repeat(5)}</mask>
 </defs><g class="float"><g class="cloudlets" filter="url(#${id}-union-edge)"><g mask="url(#${id}-union)"><rect x="-112" y="-104" width="224" height="208" fill="url(#${id}-shell)"/><g class="cloudlet-lights">${light.repeat(5)}</g></g></g>${material('body')}
 <g class="face-glow" fill="#fff5e9" opacity=".5" filter="url(#${id}-eye)"><ellipse/><ellipse/></g><g class="face" fill="#fffdf4"><ellipse/><ellipse/></g>
 <g class="badge"><circle cx="66" cy="-49" r="12" fill="#f8efdf"/><circle cx="66" cy="-49" r="8" fill="#a57b43"/><path d="M66-53v4m0 3v.3" stroke="#fffaf0" stroke-width="2.5" stroke-linecap="round"/></g></g>`;
 const floating=svg.querySelector('.float'),pieces=[...svg.querySelectorAll('.piece')].map(group=>({group,
  paths:[...group.querySelectorAll('path')].filter(p=>p.classList.length),
  clip:svg.querySelector(`#${id}-clip-${group.dataset.piece} path`),light:group.querySelector('.light')}));
 const face=svg.querySelector('.face'),glow=svg.querySelector('.face-glow'),badge=svg.querySelector('.badge'),cloudlets=svg.querySelector('.cloudlets'),masks=[...svg.querySelectorAll(`#${id}-union path`)],lights=[...svg.querySelector('.cloudlet-lights').children];
 const update=(piece,path,alpha,x=0,y=0,scale=1,pose={lightX:0,lightY:0})=>{
  piece.group.setAttribute('transform',`translate(${x} ${y})`);piece.group.setAttribute('opacity',alpha);
  for(const node of [...piece.paths,piece.clip])node.setAttribute('d',path);
  piece.light.setAttribute('transform',`scale(${scale}) translate(${pose.lightX} ${pose.lightY})`);
 };
 return (frame,t,reduced=false)=>{
  const pose=floatPose(t,reduced);floating.setAttribute('transform',`translate(${pose.x} ${pose.y})`);
  // A shared silhouette removes intersecting rims while cloudlets still touch.
  cloudlets.setAttribute('opacity',1-frame.bodyAlpha);
  frame.fragments.forEach((fragment,i)=>{masks[i].setAttribute('d',fragment.path);masks[i].setAttribute('transform',`translate(${fragment.x} ${fragment.y})`);masks[i].setAttribute('opacity',fragment.alpha);lights[i].setAttribute('transform',`translate(${fragment.x} ${fragment.y}) scale(${fragment.scale*.55}) translate(${pose.lightX} ${pose.lightY})`);lights[i].setAttribute('opacity',fragment.alpha*.8);});
  update(pieces[0],frame.bodyPath,frame.bodyAlpha,0,0,1,pose);
  face.setAttribute('opacity',frame.faceAlpha);glow.setAttribute('opacity',frame.faceAlpha*.42);
  frame.eyes.forEach((eye,i)=>{for(const group of [face,glow])for(const [key,attr] of [['x','cx'],['y','cy'],['rx','rx'],['ry','ry']])group.children[i].setAttribute(attr,eye[key]);});
  badge.setAttribute('opacity',frame.badge);badge.lastElementChild.setAttribute('opacity',frame.error);
 };
}
