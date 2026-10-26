// Injected inside the existing interaction closure. Domain and gestures stay
// in the baseline; these helpers paint only the home cartridge face.
function hmOptics(kind,id){
  const templates={body:__HOME_BODY__,edge:__HOME_EDGE__};
  return templates[kind].replaceAll('HMID',id);
}
function hmMaterializeFace(face,c,homeOptics=false){
  const id='hm-face-'+(++readerLiquidSequence);
  // The backdrop is actual DOM rear cards, blurred through the front face.
  // Do not bake the pair's illustrative rear cards into the moving cartridge.
  const fullness=hmLiquidFullness(Math.max(0,Math.min(1,totals(c).remaining/c.limit)));
  const optics=homeOptics?' data-home-optics style="--hm-fullness:'+fullness+'"':'';
  face='<div class="hm-card-body"'+optics+'>'+hmOptics('body',id+'-body')+'</div><div class="hm-card-edge">'+hmOptics('edge',id+'-edge')+'</div>'+face;
  face=face.replace(/<div class="water continuous-water"[\s\S]*?<\/div>/,hmLiquidWaterMarkup(c,id+'-water',homeOptics));
  return face;
}
function hmBubbleSvg(fine=false){
  const id='hm-bubble-'+(++readerLiquidSequence);
  return `<svg class="hm-bubble-svg" viewBox="-5.4 -5.4 10.8 10.8" aria-hidden="true"><defs><radialGradient id="${id}"><stop style="stop-color:var(--hm-bubble-tint);stop-opacity:0"/><stop offset=".64" style="stop-color:var(--hm-bubble-tint);stop-opacity:.01"/><stop offset=".82" style="stop-color:var(--hm-bubble-tint);stop-opacity:var(--hm-bubble-mid)"/><stop offset=".94" style="stop-color:var(--hm-bubble-tint);stop-opacity:var(--hm-bubble-edge)"/><stop offset="1" style="stop-color:var(--hm-bubble-tint);stop-opacity:.015"/></radialGradient></defs><circle r="4.8" fill="url(#${id})"/>${fine?'<circle r="2.9" fill="var(--hm-bubble-tint)" fill-opacity=".28"/>':''}<g fill="none" style="stroke:var(--hm-bubble-tint)" stroke-linecap="round"><path d="M-4.35 -2.03A4.8 4.8 0 0 1 .67 -4.75" style="stroke-opacity:var(--hm-bubble-glint);stroke-width:var(--hm-bubble-glint-width)"/><path d="M4.56 1.48A4.8 4.8 0 0 1 -.08 4.8" style="stroke-opacity:var(--hm-bubble-counter);stroke-width:var(--hm-bubble-counter-width)"/><ellipse cx="-1.68" cy="-2.21" rx=".91" ry=".38" transform="rotate(-42 -1.68 -2.21)" style="fill:var(--hm-bubble-tint);fill-opacity:var(--hm-bubble-spot)" stroke="none"/></g></svg>`;
}
function hmBubbleField(withBurst=true){
  const burst=withBurst?Array.from({length:36},(_,i)=>'<i class="bubble-burst '+(i<24?'hm-fine':'hm-near')+'" data-burst="'+i+'" data-drift="'+((readerNoise(i,2)-.5)*54).toFixed(2)+'" data-delay="'+(readerNoise(i,3)*520).toFixed(0)+'" data-duration="'+(2100+readerNoise(i,4)*1500).toFixed(0)+'" style="--bubble-size:'+((i<24?2.4:5.5)+readerNoise(i,5)*(i<24?2:3)).toFixed(1)+'px;left:'+(9+readerNoise(i,1)*82).toFixed(2)+'%;bottom:'+(-8+readerNoise(i,6)*19).toFixed(1)+'px">'+hmBubbleSvg(i<24)+'</i>').join(''):'';
  // Three loose streams of microbubbles, plus a few larger transparent spheres.
  // Size, drift and phase vary deterministically, without new timers or physics.
  const bubble=(i,still=false)=>{
    const fine=i<18,size=(fine?2.6:5.6)+readerNoise(i,7)*(fine?1.7:3.6);
    const x=fine?[16,47,79][i%3]+(readerNoise(i,8)-.5)*14:8+readerNoise(i,8)*84;
    return '<i class="'+(still?'hm-still':'bubble-ambient')+' '+(fine?'hm-fine':'hm-near')+'"'+(still?'':' data-ambient="'+i+'"')+' style="--bubble-size:'+size.toFixed(1)+'px;left:'+x.toFixed(2)+'%;bottom:'+(still?(9+readerNoise(i,11)*76).toFixed(2)+'%':'-7px')+'">'+hmBubbleSvg(fine)+'</i>';
  };
  const ambient=Array.from({length:28},(_,i)=>bubble(i)).join('');
  const still=Array.from({length:20},(_,i)=>bubble(i,true)).join('');
  return '<div class="card-bubble-field" aria-hidden="true">'+burst+ambient+still+'</div>';
}
function hmAmbientBubbleMotion(el,rise){
  const i=Number(el.dataset.ambient),fine=el.classList.contains('hm-fine');
  const drift=(readerNoise(i,9)-.5)*22,duration=3900+rise*8+readerNoise(i,10)*1900,peak=fine?.9:.82;
  return [[
    {opacity:0,transform:'translate(0,0) scale(.65)'},
    {opacity:peak,transform:`translate(${drift*.22}px,-${rise*.14}px) scale(.82)`,offset:.14},
    {opacity:peak*.92,transform:`translate(${drift*.6+3}px,-${rise*.50}px) scale(.95)`,offset:.5},
    {opacity:peak*.78,transform:`translate(${drift*.75-2}px,-${rise*.82}px) scale(1.03)`,offset:.82},
    {opacity:0,transform:`translate(${drift}px,-${rise+10}px) scale(1.1)`}
  ],{duration,iterations:Infinity,delay:-readerNoise(i,11)*duration,easing:'linear'}];
}
function hmStartAmbient(){
  const face=$('.reader-card-face',page);
  if(reducedMotion()){readerStopAmbient();return;}
  if(reader.ambientRoot===face){readerAmbientPlayback();return;}
  readerStopAmbient();const water=face?.querySelector('.water');
  if(!water||water.dataset.empty==='true')return;
  reader.ambientRoot=face;
  const scale=app.getBoundingClientRect().width/app.clientWidth,rise=Math.max(20,water.getBoundingClientRect().height/scale);
  for(const el of face.querySelectorAll('[data-ambient]'))reader.ambient.push(el.animate(...hmAmbientBubbleMotion(el,rise)));
  readerAmbientPlayback();
}
function hmSplashMarkup(){
  return '<g class="hm-contact-splash" aria-hidden="true">'+Array.from({length:12},(_,i)=>`<g transform="translate(${(24+readerNoise(i,16)*352).toFixed(1)} 14)"><ellipse class="hm-contact-drop" data-splash="${i}" rx="${(1+readerNoise(i,17)*.7).toFixed(1)}" ry="2.2"/></g>`).join('')+'</g>';
}
function hmContactSplash(face){
  if(reducedMotion()||face.querySelector('.water')?.dataset.empty==='true')return;
  for(const el of face.querySelectorAll('[data-splash]')){
    const i=Number(el.dataset.splash),x=(readerNoise(i,18)-.5)*19,lift=4+readerNoise(i,19)*8;
    // A non-blocking contact accent, owned and cancelled by reader.motions.
    readerAnimate(el,[{opacity:0,transform:'translate(0,2px) scale(.6)'},{opacity:.86,transform:`translate(${x*.45}px,-${lift}px) scale(.9)`,offset:.38},{opacity:0,transform:`translate(${x}px,4px) scale(.6)`}],{duration:480+readerNoise(i,20)*240,delay:readerNoise(i,21)*100,easing:'cubic-bezier(.2,.5,.4,1)'});
  }
}
