// CheckLine motion proposals on the pinned bloub engine. See NOTICE.md.
// Vendor files remain unchanged; these overrides target its documented pose data.
import { BotEngine } from './vendor/engine.mjs';
import { STATE_BY_ID } from './vendor/states.mjs';
import { SHAPE_BY_ID } from './vendor/skins.mjs';
import { RINGS, COMET_RIBBONS, particles } from './vendor/decor.mjs';
import { clamp } from './vendor/math.mjs';
export const CLOUD = SHAPE_BY_ID.get('nuage').radii;
export const IDS=['orbit','burst','comet'];
const smooth=x=>{const k=clamp(x);return k*k*k*(k*(k*6-15)+10);};
const rise=(t,a,b)=>smooth((t-a)/(b-a));
const envelope=(t,a,b,c,d)=>rise(t,a,b)*(1-rise(t,c,d));
export function cloudPose(id,t){
 const p=STATE_BY_ID.get('idle').pose(0);
 p.sil={...p.sil,radii:[...CLOUD]};
 if(id==='orbit'){
  const amount=envelope(t,0,.65,2.5,3.4),wave=Math.sin(t*Math.PI*1.1)*amount;
  p.sil.rot=0; // Whole-body rotation is applied to body and eye mask together.
  p.sil.sx=1+.035*wave;p.sil.sy=1-.035*wave;
  p.sil.radii=CLOUD.map((r,i)=>r*(1+.025*amount*Math.sin(i/CLOUD.length*Math.PI*4-t*2)));
  p.gaze={...p.gaze,yaw:p.gaze.yaw-14*Math.sin(t*1.6)*amount,pitch:p.gaze.pitch+5*wave};
  p.arcs=RINGS.slice(0,3).map((seed,i)=>({id:`cloud-ring-${i}`,seed:{...seed,speed:seed.speed*.42,width:seed.width*.8,a:seed.a*1.02},t,opacity:.78*envelope(t,i*.12,.55+i*.12,2.55,3.4)}));
 }else if(id==='burst'||id==='comet'){
  const comet=id==='comet',small=comet?.129:.166;
  const shrink=rise(t,0,comet?.55:.7),grow=rise(t,comet?1.65:1.6,comet?2.4:2.5);
  const size=1-(1-small)*shrink+(1-small)*grow;
  // Cloud lobes are fully present by radius .42, before the body grows large.
  const lobes=smooth((size-small)/(.42-small));
  p.sil.radii=CLOUD.map(r=>size*(1+(r-1)*lobes));
  p.eyeAlpha=(1-rise(t,.08,.38))* (1-grow)+rise(grow,.45,.95);
  p.eyes=p.eyes.map(e=>({...e,w:e.w*size,h:e.h*size}));
  if(comet){
   p.arcs=COMET_RIBBONS.map((seed,i)=>({id:`cloud-comet-${i}`,seed,t,opacity:envelope(t,.15,.4,1.65,2.05)}));
  }else{p.dots=particles(t,1);p.dotsBehind=true;}
 }
 return p;
}
const defs=new Map(IDS.map(id=>[id,{...STATE_BY_ID.get(id),baseBody:false,baseFace:false,pose:t=>cloudPose(id,t)}]));
export class CloudEngine extends BotEngine{
 constructor(initial='idle'){
  super(100,initial,CLOUD);
  this.spin={from:0,to:initial==='orbit'?-360:0,at:0,duration:3.4};
 }
 rotation(now){const s=this.spin;return s.from+(s.to-s.from)*smooth((now-s.at)/s.duration);}
 setState(id,now){
  if(id===this.state)return;
  const angle=this.rotation(now);
  this.spin={from:angle,to:id==='orbit'?angle-360:Math.round(angle/360)*360,at:now,duration:id==='orbit'?3.4:.7};
  super.setState(id,now);
 }
 reset(id,now){super.reset(id,now);this.spin={from:0,to:id==='orbit'?-360:0,at:now,duration:3.4};}
 sample(now){return {...super.sample(now),bodyRotation:this.rotation(now)};}

 posed(def,t,shape,expression){return super.posed(defs.get(def.id)??def,t,shape,expression);}
 // The cloud keeps its resting face attachment even during its temporary states.
 decalageAtTime(now,state){return super.decalageAtTime(now,IDS.includes(state)?'idle':state);}
}
export function engine(adapted=false){return adapted?new CloudEngine():new BotEngine(100,'idle',CLOUD);}
export const hold=id=>Math.max(STATE_BY_ID.get(id).duration,STATE_BY_ID.get(id).minDuration||0);
export function sampleClip(id,t,adapted){const e=engine(adapted);if(t>=.6)e.setState(id,.6);if(t>=.6+hold(id))e.setState('idle',.6+hold(id));return e.sample(t);}
