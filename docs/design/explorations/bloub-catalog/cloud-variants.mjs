// CheckLine motion proposals on the pinned bloub engine. See NOTICE.md.
// Vendor files remain unchanged; these overrides target its documented pose data.
import { BotEngine } from './vendor/engine.mjs';
import { STATE_BY_ID } from './vendor/states.mjs';
import { SHAPE_BY_ID } from './vendor/skins.mjs';
import { RINGS, COMET_RIBBONS, particles } from './vendor/decor.mjs';
import { clamp } from './vendor/math.mjs';
import { profileFromPolygon } from './vendor/shape.mjs';
export const CLOUD = SHAPE_BY_ID.get('nuage').radii;
export const IDS=['orbit','burst','comet'];
const smooth=x=>{const k=clamp(x);return k*k*k*(k*(k*6-15)+10);};
const rise=(t,a,b)=>smooth((t-a)/(b-a));
const envelope=(t,a,b,c,d)=>rise(t,a,b)*(1-rise(t,c,d));
// Independent body and gaze keys. The eyes lead the first compression and
// regain their resting direction before the final body settle.
const resting={sx:1,sy:1,shear:0,roll:0,flow:0,phase:0,x:0,y:0,yaw:28.49,pitch:28.62,eyeRoll:-13,eyeH:1};
const keys=[
 {t:0,...resting},
 {t:.23,...resting,sx:.98,sy:1.02,roll:-2,x:-.015,yaw:48,pitch:22},
 {t:.58,...resting,sx:.88,sy:1.06,shear:-.10,roll:-11,flow:.08,phase:.3,x:-.07,y:.015,yaw:64,pitch:8,eyeRoll:0},
 {t:1.05,...resting,sx:.70,sy:1.18,shear:-.06,roll:-23,flow:.13,phase:1.2,x:.10,y:-.08,yaw:88,pitch:-2,eyeRoll:14,eyeH:.9},
 {t:1.50,...resting,sx:.92,sy:1.08,shear:.10,roll:24,flow:.10,phase:2.1,x:.17,y:-.03,yaw:-42,pitch:0,eyeRoll:-20,eyeH:1.05},
 {t:1.98,...resting,sx:1.16,sy:.86,shear:.04,roll:14,flow:.10,phase:3.0,x:.04,y:.05,yaw:-55,pitch:16,eyeRoll:-27},
 {t:2.5,...resting,sx:1.05,sy:.97,roll:-5,flow:.035,phase:3.9,x:-.04,y:.02,yaw:14,pitch:28,eyeRoll:-17},
 {t:3.0,...resting,sx:.985,sy:1.012,roll:1.5,x:.01,yaw:28.49,pitch:28.62},
 {t:3.4,...resting}
];
// Encode asymmetric squash and roll in the contour itself. This also lets
// the original engine fit eye positions to the currently deformed boundary.
for(const k of keys){
 const a=k.roll*Math.PI/180,c=Math.cos(a),sn=Math.sin(a);
 const pts=CLOUD.map((r,i)=>{const q=i/CLOUD.length*Math.PI*2;
  const rr=r*(1+k.flow*Math.sin(q*3-k.phase));
  const x=Math.cos(q)*rr*k.sx+Math.sin(q)*rr*k.shear,y=Math.sin(q)*rr*k.sy;
  return {x:x*c-y*sn,y:x*sn+y*c};
 });
 k.radii=k.flow===0&&k.roll===0&&k.sx===1&&k.sy===1?[...CLOUD]:profileFromPolygon(pts,0,0);
}
// Non-uniform Hermite interpolation keeps velocity continuous across keys.
function valueAt(t,get){
 if(t<=0)return get(keys[0]);if(t>=3.4)return get(keys.at(-1));
 let j=0;while(keys[j+1].t<t)j++;
 const a=keys[j],b=keys[j+1],prev=keys[Math.max(0,j-1)],next=keys[Math.min(keys.length-1,j+2)];
 const dt=b.t-a.t,u=(t-a.t)/dt,u2=u*u,u3=u2*u;
 const m0=j===0?0:(get(b)-get(prev))/(b.t-prev.t);
 const m1=j+1===keys.length-1?0:(get(next)-get(a))/(next.t-a.t);
 return (2*u3-3*u2+1)*get(a)+(u3-2*u2+u)*dt*m0+(-2*u3+3*u2)*get(b)+(u3-u2)*dt*m1;
}
export const ORBIT_BEATS=[
 {at:.35,label:'准备',detail:'眼睛先看，身体收紧'},
 {at:1.05,label:'卷入',detail:'侧身收窄，眼睛到边缘'},
 {at:1.50,label:'翻动',detail:'重心移位，视线跨过身体'},
 {at:2.12,label:'舒展',detail:'云瓣展开，回头找你'},
 {at:3.4,label:'落稳',detail:'视线先稳，身体跟上'}
];
function orbitPose(p,t){
 p.sil.radii=CLOUD.map((_,i)=>Math.max(.35,valueAt(t,k=>k.radii[i])));
 p.offX=valueAt(t,k=>k.x);p.offY=valueAt(t,k=>k.y);
 p.gaze={yaw:valueAt(t,k=>k.yaw),pitch:valueAt(t,k=>k.pitch),roll:valueAt(t,k=>k.eyeRoll)};
 p.eyes=p.eyes.map(e=>({...e,h:e.h*valueAt(t,k=>k.eyeH)}));
 // Slightly delayed arc centers trail the body's curved travel; the rings
// keep their own depth sorting and leave while the cloud is settling.
 const trail=Math.max(0,t-.14),cx=valueAt(trail,k=>k.x)*.65,cy=valueAt(trail,k=>k.y)*.65;
 p.arcs=RINGS.slice(0,3).map((seed,i)=>({id:`cloud-ring-${i}`,seed:{...seed,speed:seed.speed*.42,width:seed.width*.8,a:seed.a*1.02,cx:seed.cx+cx,cy:seed.cy+cy},t,opacity:.82*envelope(t,.2+i*.12,.72+i*.12,2.4,3.25)}));
 return p;
}
export function cloudPose(id,t){
 const p=STATE_BY_ID.get('idle').pose(0);
 p.sil={...p.sil,radii:[...CLOUD]};
 if(id==='orbit'){
  return orbitPose(p,t);
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
 constructor(initial='idle'){super(100,initial,CLOUD);}
 posed(def,t,shape,expression){return super.posed(defs.get(def.id)??def,t,shape,expression);}
 // The cloud keeps its resting face attachment even during its temporary states.
 decalageAtTime(now,state){return super.decalageAtTime(now,IDS.includes(state)?'idle':state);}
}
export function engine(adapted=false){return adapted?new CloudEngine():new BotEngine(100,'idle',CLOUD);}
export const hold=id=>Math.max(STATE_BY_ID.get(id).duration,STATE_BY_ID.get(id).minDuration||0);
export function sampleClip(id,t,adapted){const e=engine(adapted);if(t>=.6)e.setState(id,.6);if(t>=.6+hold(id))e.setState('idle',.6+hold(id));return e.sample(t);}
