// A frozen interaction baseline keeps rejected, uncommitted full-page palettes
// out of this scoped material study. Git is read-only; no existing draft is replaced.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {execFileSync} = require('node:child_process');
const dir = __dirname;
const repo = path.resolve(dir, '../../../..');
const baseline = 'f10d619';
const baselinePath = 'docs/design/explorations/material-themes-2026-10-23/index.html';
let html = execFileSync('git', ['show', baseline + ':' + baselinePath], {cwd:repo, encoding:'utf8', maxBuffer:16*1024*1024});
const pair = fs.readFileSync(path.join(dir,'budget-card-pair.html'),'utf8');
function match(text, expression) {const found=text.match(expression);if(!found)throw Error('Missing material source: '+expression);return found[0];}
function once(before,after) {if(html.split(before).length!==2)throw Error('Expected one baseline boundary: '+before.slice(0,80));html=html.replace(before,after);}
const themeTokens = ['light','dark'].map(theme => {
  const block=match(pair,new RegExp('\\.'+theme+' \\{[\\s\\S]*?\\n\\}'));
  return block.replace('.'+theme, '.app[data-home-material][data-theme='+theme+']').replace(/\s*color-scheme: [^;]+;/,'').replaceAll('--','--hm-');
}).join('\n');
const scene=match(pair,/<section class="mode light"[\s\S]*?<\/section>/);
const defs=match(scene,/<defs>[\s\S]*?<\/defs>/);
// The dark wish front borrows the approved budget edge's light/shade separation.
// SourceAlpha comes from the CSS face's rounded shape, so small, wide and expanded
// cards keep their existing geometry. Static optics only; no new motion owner.
const wishThickness=match(defs,/<filter id="light-thickness"[\s\S]*?<\/filter>/)
  .replace(/<filter[^>]+>/,'<filter id="wish-front-thickness" x="-10%" y="-10%" width="120%" height="120%" color-interpolation-filters="sRGB">')
  .replace('stdDeviation="3.2"','stdDeviation="2.2"')
  .replaceAll('dx="1.728" dy="2.6"','dx="1.2" dy="1.6"')
  .replaceAll('dx="-1.728" dy="-2.6"','dx="-1.2" dy="-1.6"')
  .replace('style="flood-opacity:var(--edge-white)"','flood-opacity=".84"')
  .replace('style="flood-opacity:var(--edge-blue)"','flood-opacity=".48"');
once('<body>','<body>\n<svg width="0" height="0" style="position:absolute;pointer-events:none" aria-hidden="true" focusable="false"><defs>'+wishThickness+'</defs></svg>');
const edgeStart=scene.indexOf('<rect x="40" y="76" width="352" height="300" rx="32" fill="#000" filter="url(#light-thickness)"/>');
const edgeEnd=scene.indexOf('<text x="62"',edgeStart);
if(edgeStart<0||edgeEnd<0)throw Error('Approved edge geometry missing');
const svg=(content)=>'<svg class="hm-optics" viewBox="40 76 352 300" preserveAspectRatio="none" aria-hidden="true">'+defs+content+'</svg>';
const body=svg('<rect x="40" y="76" width="352" height="300" style="fill:var(--body-tint,var(--ice));fill-opacity:var(--body-alpha,var(--ice-alpha))"/><rect x="40" y="76" width="352" height="300" fill="url(#light-reflection)"/>');
const edge=svg(scene.slice(edgeStart,edgeEnd));
const normalize=s=>s.replaceAll('light-','HMID-').replaceAll('var(--','var(--hm-');
// Arc, sphere and enlarged textures read the same approved optics as the DOM card.
const homeSource=fs.readFileSync(path.join(dir,'src/budget-home.js'),'utf8');
const liquidSource=fs.readFileSync(path.join(dir,'src/budget-home-liquid.js'),'utf8');
const homeCss=fs.readFileSync(path.join(dir,'src/budget-home.css'),'utf8');
const liquidShape=liquidSource.slice(liquidSource.indexOf('function hmLiquidFullness('),liquidSource.indexOf('function hmLiquidWaterMarkup('));
const bubbleSvg=homeSource.slice(homeSource.indexOf('function hmBubbleSvg('),homeSource.indexOf('function hmBubbleField(')).replace('hmBubbleSvg','libraryBubbleSvg').replaceAll('readerLiquidSequence','libraryBubbleSequence');
const fullColors=Object.fromEntries(['top','mid','bottom'].map(name=>[name==='bottom'?'base':name,match(homeCss,new RegExp('--hm-water-full-'+name+':[^;}]+')).split(':').slice(1).join(':')]));
const librarySource=fs.readFileSync(path.join(dir,'src/library-card-material.js'),'utf8')
  .replace('__LIBRARY_LIQUID_SHAPE__',liquidShape)
  .replace('__LIBRARY_BUBBLE_SVG__',bubbleSvg)
  .replace('__LIBRARY_FULL_COLORS__',JSON.stringify(fullColors))
  .replace('__LIBRARY_BODY__',JSON.stringify(normalize(body).replaceAll('HMID','library-body')))
  .replace('__LIBRARY_EDGE__',JSON.stringify(normalize(edge).replaceAll('HMID','library-edge')));
once(match(html,/function ui\(t, dark = false, enlarged = false\) \{[\s\S]*?\n\}/),librarySource.trim());

let helper=fs.readFileSync(path.join(dir,'src/budget-home.js'),'utf8').replace('__HOME_BODY__',JSON.stringify(normalize(body))).replace('__HOME_EDGE__',JSON.stringify(normalize(edge)));
helper+='\n'+fs.readFileSync(path.join(dir,'src/budget-home-liquid.js'),'utf8');
helper+='\n'+fs.readFileSync(path.join(dir,'src/budget-detail.js'),'utf8');
helper+='\n'+fs.readFileSync(path.join(dir,'src/budget-pages.js'),'utf8');
helper+='\n'+fs.readFileSync(path.join(dir,'src/wish-front.js'),'utf8');
helper+='\n'+fs.readFileSync(path.join(dir,'src/wish-collection-metal.js'),'utf8');
once('function cartridgeFace(c){',helper+'\nfunction cartridgeFace(c){');
// Share the accepted front optics with active rows and live cover previews.
// Achieved wishes, full-bleed photos and purchase outcomes keep their renderers.
once('${wishFaceFront(w)}<button class="wish-face-tap"','${wmWishFront(w,completion)}<button class="wish-face-tap"');
once('class="wish-face wish-face-back" aria-hidden="${face!==\'back\'}"','class="wish-face wish-face-back ${!w.achieved&&!completion?\'wish-layered-front wish-layered-back\':\'\'}" aria-hidden="${face!==\'back\'}"');
once('${wishFaceBack(w,compact,completion)}','${wmWishBack(w,compact,completion)}');
once('items.map(wishCollectionRow)','items.map(wmWishCollectionRow)');
once('wishFaceFront(w,true)','wmWishFront(w)');
once('wishFaceFront({...w,cover:s.working},true)','wmWishFront({...w,cover:s.working})');
once('wishFaceFront({...w,cover:c},true)','wmWishFront({...w,cover:c})');
once('wishFaceFront(wishTaskPreview(ui.task),true)','wmWishFront(wishTaskPreview(ui.task))');
once('const t=totals(c),ready=readerConnected();let face=readerLiquidFace(c);','const t=totals(c),ready=readerConnected();let face=hmMaterializeFace(readerLiquidFace(c),c,true);');
once('<div class="liquid-card restored-detail-card">${libraryCardFace(c)}</div>','${dmDetailCard(c)}');
const bubbles=match(html,/function readerBubbleMarkup\(\)\{[\s\S]*?\n\}/);
once(bubbles,'function readerBubbleMarkup(){return hmBubbleField();}');
once(match(html,/function readerStartAmbient\(\)\{[\s\S]*?\n\}/),'function readerStartAmbient(){hmStartAmbient();}');
once('const pause=document.hidden||!!ui.sheet||reader.library||!!window.CheckLineDrawerState?.active;',
     'const pause=document.hidden||reducedMotion()||!!ui.sheet||reader.library||readerFold.progress>.001||!!window.CheckLineDrawerState?.active;');
once("if(face){const liquid=$('.water',face),rise=", "if(face){hmContactSplash(face);const liquid=$('.water',face),rise=");
once('const materialQuery = new URL(location.href).searchParams;','smInstallPages();\n  const materialQuery = new URL(location.href).searchParams;');
once("['detail', '预算工作区'], ['record', '消费详情']", "['detail', '预算工作区'], ['budget-records', '预算消费记录'], ['record', '消费详情']");
once("} else if (['detail', 'record', 'trend', 'history', 'info'].includes(view)) {", "} else if (view === 'budget-records') {\n        const card = materialNeedBudget();\n        if (card) navigate('detail', {id:card.id, section:'records'});\n      } else if (['detail', 'record', 'trend', 'history', 'info'].includes(view)) {");
const css=['budget-home','budget-detail','budget-pages','wish-material','dark-ui','light-ui','selection-ui'].map(name=>fs.readFileSync(path.join(dir,'src/'+name+'.css'),'utf8')).join('\n');
once('</head>','<style id="budget-home-material">\n'+themeTokens+'\n'+css+'\n</style></head>');
once('</head>','<!-- React Bits ReflectiveCard: studio shader adapted for CheckLine.\n'+fs.readFileSync(path.join(dir,'licenses/ReactBits-ReflectiveCard.txt'),'utf8')+'\n-->\n</head>');
once('data-material-study="r3-aligned"','data-material-study="r3-aligned" data-home-material="approved-pair"');
once('data-review-storage="checkline-material-themes-r37-20261024"','data-review-storage="checkline-budget-home-material-20261024"');
html=html.replace(/<title>[^<]*<\/title>/,'<title>CheckLine · 冰蓝预算交互稿</title>');
html=html.replaceAll('浅暗玻璃材质全页面研究','冰蓝预算交互稿');
const final='\n});\n</script>';
const at=html.lastIndexOf(final);if(at<0)throw Error('Home review initializer boundary missing');
html=html.slice(0,at)+'\n'+fs.readFileSync(path.join(dir,'src/budget-home-review.js'),'utf8')+html.slice(at);
for(const [i,m] of [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].entries())new vm.Script(m[1],{filename:'budget-home-'+i+'.js'});
fs.writeFileSync(path.join(dir,'budget-home.html'),html);
console.log(JSON.stringify({baseline,source:'budget-card-pair.html',bytes:Buffer.byteLength(html),output:'budget-home.html'}));
