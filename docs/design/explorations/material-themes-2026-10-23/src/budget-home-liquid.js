// Home-only free surface. No tiled translation, phase reset or ledger writes.
// The optical palette and mean fill placement remain those of the home study.
function hmLiquidShape(ratio,time,tilt=0,impact=0){
  const edge=Math.max(0,Math.min(1,ratio/.12,(1-ratio)/.12));
  const amplitude=5.8*edge*(.92+.08*Math.sin(time*.37));
  // Keep combined drag/contact displacement below four SVG units. This
  // preserves a thin free surface even when a fast switch lands mid-sway.
  const motionScale=4/Math.hypot(4,Math.abs(tilt)+Math.abs(impact));
  const front=[],back=[],tau=Math.PI*2;
  for(let i=0;i<=40;i++){
    const u=i/40,x=u*400;
    const ripple=amplitude*(.78*Math.sin(tau*u-time*.86)+.22*Math.sin(tau*2*u+time*.51+.8));
    const y=14+ripple+edge*motionScale*(tilt*Math.cos(Math.PI*u)+impact*Math.cos(tau*u));
    front.push([x,y]);
    back.push([x,y-edge*(3.2+.65*Math.sin(tau*u+time*.31))]);
  }
  const n=v=>v.toFixed(2);
  // A cubic interpolation keeps the fine reflected edge smooth at small sizes.
  const curve=points=>points.reduce((d,p,i)=>{
    if(!i)return 'M'+n(p[0])+' '+n(p[1]);
    const a=points[i-1],before=points[Math.max(0,i-2)],after=points[Math.min(points.length-1,i+1)];
    const slopeA=(p[1]-before[1])/(p[0]-before[0]);
    const slopeB=(after[1]-a[1])/(after[0]-a[0]),dx=(p[0]-a[0])/3;
    return d+'C'+n(a[0]+dx)+' '+n(a[1]+dx*slopeA)+' '+n(p[0]-dx)+' '+n(p[1]-dx*slopeB)+' '+n(p[0])+' '+n(p[1]);
  },'');
  const line=curve(front),rear=curve(back),height=Math.max(24,258*ratio+24);
  return {line,rear,volume:line+'V'+height.toFixed(2)+'H0Z',surface:rear+front.slice().reverse().map(p=>'L'+n(p[0])+' '+n(p[1])).join('')+'Z'};
}
function hmLiquidWaterMarkup(c,id){
  const ratio=Math.max(0,Math.min(1,totals(c).remaining/c.limit));
  const shape=hmLiquidShape(ratio,0),height=Math.max(24,258*ratio+24);
  return `<div class="water continuous-water hm-water" data-empty="${ratio===0}" data-liquid-ratio="${ratio}" style="--water-height:${ratio*100}%"><svg class="hm-fluid-svg" viewBox="0 0 400 ${height}" preserveAspectRatio="none" aria-hidden="true"><defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="var(--water-top)"/><stop offset=".33" stop-color="var(--water-middle)"/><stop offset="1" stop-color="var(--water-bottom)"/></linearGradient><linearGradient id="${id}-glint" x1="0" y1="0" x2="1" y2="0"><stop stop-color="#fff" stop-opacity="0"/><stop offset=".3" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff" stop-opacity=".7"/><stop offset=".7" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient></defs><path class="liquid-volume" d="${shape.volume}" fill="url(#${id})"/><path class="hm-water-surface" d="${shape.surface}"/><path class="hm-water-back" d="${shape.rear}"/><path class="r3-waterline" d="${shape.line}"/><path class="hm-water-glint" d="${shape.line}" stroke="url(#${id}-glint)"/></svg></div>`;
}
function hmStartLiquid(){
  let svg=null,paths=null,ratio=0,frame=0,last=0,time=0,phase=reader.phase;
  let tilt=0,tiltVelocity=0,impact=0,impactVelocity=0,switchDirection=0;
  const clamp=(x,min,max)=>Math.max(min,Math.min(max,x));
  const media=matchMedia('(prefers-reduced-motion:reduce)');
  function paint(staticView=false){
    if(!paths)return;
    const shape=hmLiquidShape(ratio,staticView?0:time,staticView?0:tilt,staticView?0:impact);
    for(const key of ['volume','surface','rear','line'])paths[key].setAttribute('d',shape[key]);
    paths.glint.setAttribute('d',shape.line);
    const light=.44+.15*Math.sin(time*.31);
    paths.gradient.setAttribute('x1',String(light-.5));paths.gradient.setAttribute('x2',String(light+.5));
  }
  function pausedReason(){
    if(!svg||!svg.isConnected||!readerRootVisible())return 'away';
    if(reducedMotion())return 'reduced';
    if(document.hidden)return 'hidden';
    if(ui.sheet||app.classList.contains('reader-drawer-open'))return 'covered';
    if(reader.library)return 'library';
    if(readerFold.progress>.001)return 'records';
    if(ratio===0)return 'empty';
    if(ratio===1)return 'full';
    return '';
  }
  function stop(reason){
    cancelAnimationFrame(frame);frame=0;last=0;
    tilt=tiltVelocity=impact=impactVelocity=0;switchDirection=0;
    if(svg)svg.dataset.liquidState=reason;
    if(reason==='reduced')paint(true);
  }
  function tick(now){
    frame=0;const reason=pausedReason();if(reason){stop(reason);return;}
    // Cap time after a blocked main thread; returning from a pause never seeks.
    const dt=last?Math.min(.032,(now-last)/1000):1/60;last=now;
    time+=dt*(reader.phase==='unplugged'?.68:1);
    const d=reader.drag,target=d?.type==='card'&&d.locked?clamp(-d.dx/22,-5.8,5.8):0;
    tiltVelocity+=(38*(target-tilt)-7.8*tiltVelocity)*dt;tilt+=tiltVelocity*dt;
    impactVelocity+=(-48*impact-5.6*impactVelocity)*dt;impact+=impactVelocity*dt;
    paint();frame=requestAnimationFrame(tick);
  }
  function sync(){
    const next=page.querySelector('.cartridge-card .hm-fluid-svg');
    if(next!==svg){
      svg=next;
      paths=svg?{volume:svg.querySelector('.liquid-volume'),surface:svg.querySelector('.hm-water-surface'),rear:svg.querySelector('.hm-water-back'),line:svg.querySelector('.r3-waterline'),glint:svg.querySelector('.hm-water-glint'),gradient:svg.querySelector('linearGradient[id$="-glint"]')}:null;
      ratio=svg?Number(svg.parentElement.dataset.liquidRatio):0;paint(reducedMotion());
    }
    if(phase!==reader.phase){
      // Transfer horizontal momentum to the promoted card, then give the
      // seated liquid a smaller directional after-sway at actual contact.
      if(reader.phase==='changing'){
        switchDirection=Math.sign(reader.stackDirection)||1;
        if(!pausedReason())tiltVelocity=-switchDirection*30;
      }
      if(reader.phase==='charging'){
        if(!pausedReason()){
          impactVelocity=54;
          if(switchDirection)tiltVelocity=-switchDirection*26;
        }
        switchDirection=0;
      }
      phase=reader.phase;
    }
    const reason=pausedReason();if(reason){stop(reason);return;}
    svg.dataset.liquidState='flowing';if(!frame){last=0;frame=requestAnimationFrame(tick);}
  }
  // Observe lifecycle boundaries only. Per-frame path and transform writes do
  // not trigger this observer, and no frame loop survives an obscured home.
  const observer=new MutationObserver(sync);
  observer.observe(app,{subtree:true,childList:true,attributes:true,attributeFilter:['class','data-phase','data-fold-view']});
  document.addEventListener('visibilitychange',sync);
  media.addEventListener('change',sync);
  // Keep observers attached in the back/forward cache so returning to this
  // study can resume. They are local to this document and retire with it.
  window.addEventListener('pagehide',()=>stop('hidden'));
  window.addEventListener('pageshow',sync);
  sync();
}
