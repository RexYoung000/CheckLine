// Injected inside the existing interaction closure. Domain and gestures stay
// in the baseline; these helpers paint only the home cartridge face.
function hmOptics(kind,id){
  const templates={body:__HOME_BODY__,edge:__HOME_EDGE__};
  return templates[kind].replaceAll('HMID',id);
}
function hmMaterializeFace(face,c){
  const id='hm-face-'+(++readerLiquidSequence);
  // The backdrop is actual DOM rear cards, blurred through the front face.
  // Do not bake the pair's illustrative rear cards into the moving cartridge.
  face='<div class="hm-card-body">'+hmOptics('body',id+'-body')+'</div><div class="hm-card-edge">'+hmOptics('edge',id+'-edge')+'</div>'+face;
  face=face.replace(/<div class="water continuous-water"[\s\S]*?<\/div>/,hmLiquidWaterMarkup(c,id+'-water'));
  return face;
}
function hmBubbleSvg(){
  const id='hm-bubble-'+(++readerLiquidSequence);
  return `<svg class="hm-bubble-svg" viewBox="-5.4 -5.4 10.8 10.8" aria-hidden="true"><defs><radialGradient id="${id}"><stop style="stop-color:var(--hm-bubble-tint);stop-opacity:0"/><stop offset=".64" style="stop-color:var(--hm-bubble-tint);stop-opacity:.01"/><stop offset=".82" style="stop-color:var(--hm-bubble-tint);stop-opacity:var(--hm-bubble-mid)"/><stop offset=".94" style="stop-color:var(--hm-bubble-tint);stop-opacity:var(--hm-bubble-edge)"/><stop offset="1" style="stop-color:var(--hm-bubble-tint);stop-opacity:.015"/></radialGradient></defs><circle r="4.8" fill="url(#${id})"/><g fill="none" style="stroke:var(--hm-bubble-tint)" stroke-linecap="round"><path d="M-4.35 -2.03A4.8 4.8 0 0 1 .67 -4.75" style="stroke-opacity:var(--hm-bubble-glint);stroke-width:var(--hm-bubble-glint-width)"/><path d="M4.56 1.48A4.8 4.8 0 0 1 -.08 4.8" style="stroke-opacity:var(--hm-bubble-counter);stroke-width:var(--hm-bubble-counter-width)"/><ellipse cx="-1.68" cy="-2.21" rx=".91" ry=".38" transform="rotate(-42 -1.68 -2.21)" style="fill:var(--hm-bubble-tint);fill-opacity:var(--hm-bubble-spot)" stroke="none"/></g></svg>`;
}
function hmBubbleField(){
  const burst=Array.from({length:32},(_,i)=>'<i class="bubble-burst" data-burst="'+i+'" data-drift="'+((readerNoise(i,2)-.5)*90).toFixed(2)+'" data-delay="'+(readerNoise(i,3)*780).toFixed(0)+'" data-duration="'+(2400+readerNoise(i,4)*1900).toFixed(0)+'" style="--bubble-size:'+(4+readerNoise(i,5)*5.5).toFixed(1)+'px;left:'+(9+readerNoise(i,1)*82).toFixed(2)+'%;bottom:'+(-8+readerNoise(i,6)*19).toFixed(1)+'px">'+hmBubbleSvg()+'</i>').join('');
  const ambient=Array.from({length:16},(_,i)=>'<i class="bubble-ambient '+(i<10?'hm-far':'hm-near')+'" data-ambient="'+i+'" style="--bubble-size:'+((i<10?3.2:7)+readerNoise(i,7)*(i<10?1.5:3.5)).toFixed(1)+'px;left:'+(6+readerNoise(i,8)*88).toFixed(2)+'%;bottom:-7px">'+hmBubbleSvg()+'</i>').join('');
  const still=Array.from({length:16},(_,i)=>'<i class="hm-still '+(i<10?'hm-far':'hm-near')+'" style="--bubble-size:'+((i<10?3.2:7)+readerNoise(i,7)*(i<10?1.5:3.5)).toFixed(1)+'px;left:'+(7+readerNoise(i,8)*85).toFixed(2)+'%;bottom:'+(8+readerNoise(i,11)*78).toFixed(2)+'%">'+hmBubbleSvg()+'</i>').join('');
  return '<div class="card-bubble-field" aria-hidden="true">'+burst+ambient+still+'</div>';
}
