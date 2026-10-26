// Budget overview only. Reuse the accepted optical layers, free surface and
// transparent spheres; navigation and monetary calculations stay in the base.
function dmDetailCard(c){
  const ratio=Math.max(0,Math.min(1,totals(c).remaining/c.limit));
  const face=hmMaterializeFace(libraryCardFace(c),c).replace('<div class="card-top">',hmBubbleField(false)+'<div class="card-top">');
  return `<div class="liquid-card restored-detail-card dm-detail-card" style="--fill-ratio:${ratio}">${face}</div>`;
}
function dmStartDetail(){
  let card=null,svg=null,paths=null,ratio=0,frame=0,last=0,time=0,bubbles=[],cardHeight=0;
  let appHeight=app.clientHeight;
  const media=matchMedia('(prefers-reduced-motion:reduce)');
  function cancelBubbles(){for(const a of bubbles)a.cancel();bubbles=[];}
  function startBubbles(){
    if(!card||ratio===0||reducedMotion()||bubbles.length)return;
    const scale=app.getBoundingClientRect().width/app.clientWidth;
    const rise=Math.max(20,card.querySelector('.water').getBoundingClientRect().height/scale);
    for(const el of card.querySelectorAll('[data-ambient]')){
      const i=Number(el.dataset.ambient),drift=(readerNoise(i,9)-.5)*28,duration=6800+readerNoise(i,10)*4500;
      bubbles.push(el.animate([{opacity:0,transform:'translate(0,0) scale(.55)'},{opacity:.67,transform:`translate(${drift*.2}px,-${rise*.15}px) scale(.75)`,offset:.16},{opacity:.55,transform:`translate(${drift*.6}px,-${rise*.65}px) scale(.95)`,offset:.68},{opacity:0,transform:`translate(${drift}px,-${rise+14}px) scale(1.06)`}],{duration,iterations:Infinity,delay:-readerNoise(i,11)*duration,easing:'linear'}));
    }
  }
  function paint(still=false){
    if(!paths)return;
    const shape=hmLiquidShape(ratio,still?0:time);
    for(const key of ['volume','surface','rear','line'])paths[key].setAttribute('d',shape[key]);
    paths.glint.setAttribute('d',shape.line);
    const light=.44+.15*Math.sin(time*.31);
    paths.gradient.setAttribute('x1',String(light-.5));paths.gradient.setAttribute('x2',String(light+.5));
  }
  function pauseReason(){
    if(!card||!card.isConnected)return 'away';
    if(reducedMotion())return 'reduced';
    if(document.hidden)return 'hidden';
    if(ui.sheet)return 'covered';
    return '';
  }
  function stop(reason){
    cancelAnimationFrame(frame);frame=0;last=0;
    if(svg)svg.dataset.liquidState=reason;
    for(const a of bubbles)a.pause();
    if(reason==='reduced'){cancelBubbles();paint(true);}
  }
  function tick(now){
    frame=0;const reason=pauseReason();if(reason){stop(reason);return;}
    const dt=last?Math.min(.032,(now-last)/1000):1/60;last=now;time+=dt;
    paint();frame=requestAnimationFrame(tick);
  }
  function sync(){
    const next=app.querySelector('.reader-drawer .dm-detail-card');
    if(next!==card){
      cancelBubbles();card=next;svg=card?.querySelector('.hm-fluid-svg');
      paths=svg?{volume:svg.querySelector('.liquid-volume'),surface:svg.querySelector('.hm-water-surface'),rear:svg.querySelector('.hm-water-back'),line:svg.querySelector('.r3-waterline'),glint:svg.querySelector('.hm-water-glint'),gradient:svg.querySelector('linearGradient[id$="-glint"]')}:null;
      ratio=svg?Number(svg.parentElement.dataset.liquidRatio):0;cardHeight=card?.clientHeight||0;paint(reducedMotion());
    }
    if(card&&card.clientHeight!==cardHeight){cardHeight=card.clientHeight;cancelBubbles();}
    const reason=pauseReason();if(reason){stop(reason);return;}
    startBubbles();for(const a of bubbles)if(a.playState==='paused')a.play();
    if(ratio===0){stop('empty');return;}
    svg.dataset.liquidState='flowing';if(!frame){last=0;frame=requestAnimationFrame(tick);}
  }
  const observer=new MutationObserver(sync);
  observer.observe(app,{subtree:true,childList:true,attributes:true,attributeFilter:['class','data-detent']});
  const resize=new ResizeObserver(()=>{
    const height=app.clientHeight,changed=height!==appHeight;appHeight=height;
    // Fit the accepted overview and its newly aligned descendants to the
    // viewport without changing the existing partial/full detent behavior.
    if(changed&&app.querySelector('.reader-drawer :is(.dm-detail-card,.dm-subpage,.wish-wallet-page,.wish-entry-page)')&&readerDrawer.active&&!readerDrawer.drag){
      readerDrawerStop();readerDrawer.target=readerDrawer.target<12?0:drawerPartial();readerDrawerPaint(readerDrawer.target);
    }
    sync();
  });
  resize.observe(app);
  document.addEventListener('visibilitychange',sync);media.addEventListener('change',sync);
  window.addEventListener('pagehide',()=>stop('hidden'));window.addEventListener('pageshow',sync);
  sync();
}
