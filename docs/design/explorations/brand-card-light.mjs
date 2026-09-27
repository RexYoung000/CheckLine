// Optical feedback for the HTML material study. No card navigation or data writes.
export function createCardLight({card,reduced}) {
  const surface=card.querySelector('.card-reflection'),edge=card.querySelector('.card-edge-light');
  let rect=card.getBoundingClientRect(),x=.32,y=.24,tx=x,ty=y,strength=0;
  let pointer=false,keyboard=false,demoStart=null,frameID=0,last=0,destroyed=false;
  const listeners=[];
  const clamp=value=>Math.max(0,Math.min(1,value));
  const on=(name,fn)=>{card.addEventListener(name,fn);listeners.push([name,fn]);};
  const active=()=>pointer||keyboard||demoStart!==null;
  function paint(){
    surface.style.opacity=String(strength);
    edge.style.opacity=String(strength*.9);
    card.style.setProperty('--glint-x',`${x*100}%`);
    card.style.setProperty('--glint-y',`${y*100}%`);
    card.dataset.lit=String(strength>.015);
  }
  function step(now){
    frameID=0;
    if(destroyed||document.hidden)return;
    const dt=last?Math.min(48,now-last):16;last=now;
    if(demoStart!==null){
      const t=Math.min(1,(now-demoStart)/1500);
      tx=.16+.7*t;ty=.22+.46*Math.sin(t*Math.PI);
      if(t===1)demoStart=null;
    }
    const target=active() ? .92 : 0,blend=1-Math.exp(-dt/68),fade=1-Math.exp(-dt/(target?95:160));
    x+=(tx-x)*blend;y+=(ty-y)*blend;strength+=(target-strength)*fade;
    if(Math.abs(target-strength)<.002)strength=target;
    paint();
    if(demoStart!==null||Math.abs(tx-x)+Math.abs(ty-y)>.001||strength!==target)frameID=requestAnimationFrame(step);
  }
  function sync(){
    cancelAnimationFrame(frameID);frameID=0;last=0;
    if(document.hidden){pointer=false;demoStart=null;strength=0;paint();return;}
    if(reduced()){
      demoStart=null;x=tx=.42;y=ty=.3;strength=active() ? .7 : 0;paint();return;
    }
    frameID=requestAnimationFrame(step);
  }
  function locate(event){
    if(reduced())return;
    rect=card.getBoundingClientRect();
    tx=clamp((event.clientX-rect.left)/rect.width);ty=clamp((event.clientY-rect.top)/rect.height);
  }
  function enter(event){
    if(event.pointerType==='touch')return;
    demoStart=null;pointer=true;locate(event);sync();
  }
  function leave(){pointer=false;sync();}
  on('pointerenter',enter);
  on('pointermove',event=>{
    if(!pointer)return;
    demoStart=null;locate(event);
    if(reduced())return;
    if(!frameID){last=0;frameID=requestAnimationFrame(step);}
  });
  on('pointerdown',event=>{demoStart=null;pointer=true;keyboard=false;locate(event);sync();});
  on('pointerup',event=>{if(event.pointerType!=='mouse')leave();});
  on('pointerleave',leave);
  on('pointercancel',leave);
  on('focus',()=>{keyboard=card.matches(':focus-visible');if(keyboard){tx=.42;ty=.3;}sync();});
  on('blur',()=>{keyboard=false;sync();});
  const resize=new ResizeObserver(()=>{
    rect=card.getBoundingClientRect();
    const liquid=card.querySelector('.liquid');
    if(liquid)liquid.style.setProperty('--bubble-rise',`${Math.max(12,liquid.getBoundingClientRect().height-8)}px`);
    paint();
  });
  resize.observe(card);paint();
  return {
    sync,
    preview(){if(reduced()||document.hidden)return;pointer=false;demoStart=performance.now();sync();},
    destroy(){destroyed=true;cancelAnimationFrame(frameID);resize.disconnect();for(const [name,fn] of listeners)card.removeEventListener(name,fn);}
  };
}
