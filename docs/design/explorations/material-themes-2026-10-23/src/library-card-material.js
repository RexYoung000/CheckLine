// SVG snapshots for the existing arc / sphere renderer. The builder supplies
// the approved budget body, edge, water shape and bubble art from their sources.
// Texture size, content, hit areas and library animation remain unchanged.
__LIBRARY_LIQUID_SHAPE__
function ui(t,dark=false,enlarged=false){
  const style=getComputedStyle(document.querySelector('.app[data-home-material]'));
  const ratio=Math.max(0,Math.min(1,Number(t.fill)/100||0)),fullness=hmLiquidFullness(ratio);
  const values={'--hm-fullness':String(fullness)};
  if(dark)values['--hm-body-alpha']=String(parseFloat(style.getPropertyValue('--hm-body-alpha'))-.10*fullness);
  const token=name=>values[name]??style.getPropertyValue(name).trim();
  const resolve=text=>{
    // Resolve inner fallbacks first; images cannot inherit the page's variables.
    for(let pass=0;pass<8&&text.includes('var(');pass++)text=text.replace(/var\((--[\w-]+)(?:,([^()]*))?\)/g,(_,name,fallback)=>token(name)||fallback||'0');
    return text;
  };
  const fullColors=__LIBRARY_FULL_COLORS__;
  const water=name=>dark?`color-mix(in srgb, ${token('--hm-water-'+name+'-color')} ${(1-fullness)*100}%, ${fullColors[name]})`:token('--hm-water-'+name+'-color');
  const optics=template=>resolve(template).replace('viewBox=','width="400" height="300" viewBox=');
  let libraryBubbleSequence=0;
  __LIBRARY_BUBBLE_SVG__
  const h=Math.max(0,300*ratio-20*fullness),shape=hmLiquidShape(ratio,0),shapeHeight=Math.max(24,258*ratio+24);
  const positions=[[.13,.2,3],[.28,.57,2.6],[.44,.31,3],[.63,.72,2.7],[.79,.48,3.1],[.9,.85,2.8],[.22,.82,5.9],[.68,.22,6.6],[.48,.88,5.4],[.84,.69,6.2]];
  const bubbles=ratio>0?positions.map(([x,y,size],i)=>`<svg x="${x*400}" y="${300-h+14+(Math.max(0,h-34))*y}" width="${size}" height="${size}" viewBox="-5.4 -5.4 10.8 10.8" opacity="${i<6?.64:.92}">${libraryBubbleSvg(i<6).replace(/<svg[^>]*>|<\/svg>/g,'')}</svg>`).join(''):'';
  const liquid=ratio>0?`<svg x="0" y="${300-h}" width="400" height="${h}" viewBox="0 0 400 ${shapeHeight}" preserveAspectRatio="none"><defs><linearGradient id="library-water" x2="0" y2="1"><stop stop-color="${water('top')}"/><stop offset=".33" stop-color="${water('mid')}"/><stop offset="1" stop-color="${water('base')}"/></linearGradient></defs><path d="${shape.volume}" fill="url(#library-water)"/><path d="${shape.surface}" fill="#edfbff" fill-opacity=".085"/><path d="${shape.rear}" fill="none" stroke="#e2faff" stroke-opacity=".22" stroke-width=".85"/><path d="${shape.line}" fill="none" stroke="#fff" stroke-opacity=".68" stroke-width="1.2"/></svg>`:'';
  const titleSize=enlarged?38:23,valueSize=enlarged?53:43;
  const amount=dark&&ratio<=.2?token('--hm-ink'):token('--hm-amount-ink');
  const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 400 300"><defs><clipPath id="library-clip"><rect x=".6" y=".6" width="398.8" height="298.8" rx="31.4"/></clipPath></defs><g clip-path="url(#library-clip)">${optics(__LIBRARY_BODY__)}${liquid}${resolve(bubbles)}${optics(__LIBRARY_EDGE__)}<g fill="${amount}" font-family="-apple-system,BlinkMacSystemFont,Arial,'PingFang SC',sans-serif"><text fill="${token('--hm-ink')}" x="28" y="${enlarged?62:51}" font-size="${titleSize}" font-weight="450">${Sr(t.name)}</text><text x="371" y="${enlarged?253:260}" text-anchor="end" font-size="${valueSize}" font-weight="500" letter-spacing="-1"><tspan font-size="${enlarged?30:23}">${Sr(t.symbol||'\xA5')} </tspan>${Sr(t.value)}</text></g></g></svg>`;
  return 'data:image/svg+xml;charset=utf-8,'+encodeURIComponent(svg);
}
