import {MaterialStatePlayer} from './bloub-catalog/cloud-inner-flow.mjs';
import {materialRenderer} from './bloub-catalog/cloud-material.mjs';
export function createMascot(root){
 const player=new MaterialStatePlayer(),renders=new Map();let last=0,frameID=0,state='idle',requested='idle',lightMix=0;
 const visible=svg=>{const r=svg.getBoundingClientRect();return r.width>0&&r.height>0&&r.bottom>0&&r.top<innerHeight&&r.right>0&&r.left<innerWidth&&!svg.closest('[inert]')};
 function draw(){const sampled=player.sample(),frame={...sampled,lights:sampled.lights.map(light=>({...light,opacity:light.opacity*lightMix}))};for(const [svg,render] of renders)if(svg.isConnected&&visible(svg)){svg.dataset.mascotState=state;render(frame,player.elapsed,player.reduced);}}
 function frame(now){frameID=0;const active=[...renders.keys()].some(visible);if(!document.hidden&&active){const dt=last?Math.min(.06,(now-last)/1000):0;player.step(dt);const target=state==='thinking'?1:0;lightMix+=(target-lightMix)*(1-Math.exp(-dt/0.13));if(Math.abs(target-lightMix)<.002)lightMix=target;if(state==='success'&&player.time>1.15){state='idle';player.select('idle')}draw()}last=now;if(!document.hidden&&!player.reduced)frameID=requestAnimationFrame(frame);}
 function sync(next,reduced){for(const svg of renders.keys())if(!svg.isConnected)renders.delete(svg);for(const svg of root.querySelectorAll('[data-xiaoduo]'))if(!renders.has(svg))renders.set(svg,materialRenderer(svg));if(next!==requested){requested=next;state=next;player.select(next)}if(player.reduced!==reduced)player.reduce(reduced);if(reduced)lightMix=state==='thinking'?1:0;draw();cancelAnimationFrame(frameID);last=0;if(!document.hidden&&!reduced)frameID=requestAnimationFrame(frame);}
 document.addEventListener('visibilitychange',()=>{cancelAnimationFrame(frameID);last=0;if(!document.hidden&&!player.reduced)frameID=requestAnimationFrame(frame)});
 return {sync};
}
