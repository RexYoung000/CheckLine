// CheckLine frosted material. Whole-shell clipping keeps the inner light contained.
let serial=0;
export function floatPose(t,reduced=false){
 if(reduced)return {x:0,y:0};
 return {x:1.6*Math.sin(t*.53)+.65*Math.sin(t*.91),y:3.1*Math.sin(t*.82)+.85*Math.sin(t*.37)};
}
export function materialRenderer(svg,{flat=false}={}){
 const id=`cloud-glass-${++serial}`,small=svg.hasAttribute('data-small');
 svg.setAttribute('viewBox','-112 -104 224 208');svg.setAttribute('aria-hidden','true');
 svg.innerHTML=`<defs>
 <linearGradient id="${id}-shell" x1=".05" y1="0" x2=".68" y2="1"><stop stop-color="#8976bd"/><stop offset=".18" stop-color="#4c317b"/><stop offset=".48" stop-color="#563496"/><stop offset=".79" stop-color="#7860c9"/><stop offset="1" stop-color="#a698ed"/></linearGradient>
 <linearGradient id="${id}-rim" x1="0" y1="0" x2=".68" y2="1"><stop stop-color="#f3e8ff" stop-opacity=".95"/><stop offset=".29" stop-color="#c6b3f9" stop-opacity=".12"/><stop offset=".65" stop-color="#7561b5" stop-opacity=".1"/><stop offset="1" stop-color="#e8ddff" stop-opacity=".8"/></linearGradient>
 <filter id="${id}-blur" x="-50%" y="-50%" width="200%" height="200%" color-interpolation-filters="sRGB"><feGaussianBlur stdDeviation="${small?5:7}"/></filter>
 <filter id="${id}-edge" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="2.8"/></filter>
 <filter id="${id}-eye" x="-100%" y="-50%" width="300%" height="200%"><feGaussianBlur stdDeviation="2"/></filter>
 <clipPath id="${id}-clip"><path/></clipPath>
 </defs><g class="float"><g class="piece" data-piece="body"><path class="surface" fill="${flat?'#887298':`url(#${id}-shell)`}"/>
 ${flat?'':`<g clip-path="url(#${id}-clip)"><g class="light" filter="url(#${id}-blur)"><ellipse cx="9" cy="55" rx="47" ry="22" fill="#a99dff" opacity=".76"/><path class="rose-light" fill="#e989bc"/><path class="gold-light" fill="#ffe1ac"/></g><path class="edge-dark" fill="none" stroke="#2c164d" stroke-width="9" opacity=".48" filter="url(#${id}-edge)"/><path class="edge-light" fill="none" stroke="url(#${id}-rim)" stroke-width="6" filter="url(#${id}-edge)"/></g><path class="rim" fill="none" stroke="url(#${id}-rim)" stroke-width=".85"/>`}</g>
 <g class="face-glow" fill="#fff5e9" opacity="${flat?0:.42}" filter="url(#${id}-eye)"><ellipse/><ellipse/></g><g class="face" fill="#fffdf4"><ellipse/><ellipse/></g>
 <g class="badge"><circle cx="66" cy="-49" r="12" fill="#f8efdf"/><circle cx="66" cy="-49" r="8" fill="#a57b43"/><path d="M66-53v4m0 3v.3" stroke="#fffaf0" stroke-width="2.5" stroke-linecap="round"/></g></g>`;
 const floating=svg.querySelector('.float'),body=svg.querySelector('.piece'),clip=svg.querySelector('clipPath path');
 const paths=[...body.querySelectorAll('.surface,.edge-dark,.edge-light,.rim')],lights=[...svg.querySelectorAll('.rose-light,.gold-light')];
 const face=svg.querySelector('.face'),glow=svg.querySelector('.face-glow'),badge=svg.querySelector('.badge');
 return (frame,t,reduced=false)=>{
  const pose=floatPose(t,reduced);floating.setAttribute('transform',`translate(${pose.x} ${pose.y})`);
  for(const node of [...paths,clip])node.setAttribute('d',frame.bodyPath);
  frame.lights.forEach((light,i)=>{if(flat)return;lights[i].setAttribute('d',light.path);lights[i].setAttribute('opacity',light.opacity);lights[i].setAttribute('transform',`translate(${light.x} ${light.y}) rotate(${light.angle}) scale(${light.sx} ${light.sy})`);});
  frame.eyes.forEach((eye,i)=>{for(const group of [face,glow])for(const [key,attr] of [['x','cx'],['y','cy'],['rx','rx'],['ry','ry']])group.children[i].setAttribute(attr,eye[key]);});
  badge.setAttribute('opacity',frame.badge);badge.lastElementChild.setAttribute('opacity',frame.error);
 };
}
