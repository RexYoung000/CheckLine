const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.resolve(__dirname,'../../../..');
const work=path.join(__dirname,'src');
const archive=__dirname;
let html=fs.readFileSync(path.join(root,'docs/design/evidence/2026-10-22-native-r34/approved-r34.html'),'utf8');
function once(before,after){const at=html.indexOf(before);if(at<0||html.indexOf(before,at+before.length)>=0)throw Error('Expected exactly one match: '+before.slice(0,90));html=html.slice(0,at)+after+html.slice(at+before.length);}

// Keep the approved embedded React/WebGL library and its interaction contract.
// Only its existing card-texture renderer and appearance update hook change.
const oldStart=html.indexOf('function ui(t,l=!1,e=!1){');
const oldEnd=html.indexOf('var w=',oldStart);
if(oldStart<0||oldEnd<0)throw Error('Card texture renderer boundary missing');
function materialCardTexture(t, dark = false, enlarged = false) {
  const p = dark
    ? {ink:'#f0fbff',title:'#102b38',top:'#37b9e8',bottom:'#102b38',ambient:'#c5f6ff',ambientOpacity:.86,water1:'#c5f6ff33',waterMid:'#37b9e833',water2:'#102b388c',rim:'#fffffff2'}
    : {ink:'#123c4e',title:'#163c4d',top:'#b6e5ef',bottom:'#719fad',ambient:'#f4feff',ambientOpacity:.7,water1:'#d9f8fc33',waterMid:'#8bcada26',water2:'#335c6b45',rim:'#fffffffa'};
  const level = 300 * (1 - t.fill / 100), titleSize = enlarged ? 38 : 23, valueSize = enlarged ? 53 : 43;
  const contour = `M0 ${level} C58 ${level-6} 105 ${level+4} 170 ${level} S280 ${level-6} 340 ${level} S380 ${level+4} 400 ${level}`;
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 400 300"><defs>
    <linearGradient id="environment" x1="0" y1="0" x2="0" y2="1"><stop stop-color="${p.top}"/><stop offset=".205" stop-color="${p.top}"/><stop offset="1" stop-color="${p.bottom}"/></linearGradient>
    <radialGradient id="ambient" cx="-.057" cy="-.05" r="1.12" gradientTransform="scale(1 1.68)"><stop stop-color="${p.ambient}" stop-opacity="${p.ambientOpacity}"/><stop offset=".58" stop-color="${p.ambient}" stop-opacity=".08"/><stop offset="1" stop-color="${p.ambient}" stop-opacity="0"/></radialGradient>
    <linearGradient id="glass" x1="0" y1="0" x2=".58" y2="1"><stop stop-color="#fff" stop-opacity=".44"/><stop offset=".22" stop-color="#fff" stop-opacity=".2"/><stop offset=".63" stop-color="#fff" stop-opacity=".065"/><stop offset="1" stop-color="#fff" stop-opacity=".025"/></linearGradient>
    <radialGradient id="reflection" cx=".1" cy="0" r="1"><stop stop-color="#fff" stop-opacity=".28"/><stop offset=".62" stop-color="#fff" stop-opacity=".055"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
    <linearGradient id="water" x1="0" y1="0" x2="0" y2="1"><stop stop-color="${p.water1}"/><stop offset=".33" stop-color="${p.waterMid}"/><stop offset="1" stop-color="${p.water2}"/></linearGradient>
    <linearGradient id="rim" x1="0" y1="0" x2=".8" y2="1"><stop stop-color="${p.rim}"/><stop offset=".28" stop-color="#ffffff91"/><stop offset=".6" stop-color="#c5f6ff29"/><stop offset="1" stop-color="#ffffff4d"/></linearGradient>
    <clipPath id="clip"><rect x=".6" y=".6" width="398.8" height="298.8" rx="31.4"/></clipPath></defs>
    <g clip-path="url(#clip)"><rect width="400" height="300" fill="url(#environment)"/><rect width="400" height="300" fill="url(#ambient)"/><rect width="400" height="300" fill="url(#glass)"/><rect width="400" height="300" fill="url(#reflection)"/>
    <path d="${contour} V300H0Z" fill="url(#water)"/><path d="${contour}" fill="none" stroke="#c5f6ff52" stroke-width="1.1"/>
    <g fill="${p.ink}" font-family="-apple-system,BlinkMacSystemFont,Arial,'PingFang SC',sans-serif"><text fill="${p.title}" x="28" y="${enlarged?62:51}" font-size="${titleSize}" font-weight="450">${Sr(t.name)}</text><text x="371" y="${enlarged?253:260}" text-anchor="end" font-size="${valueSize}" font-weight="500" letter-spacing="-1"><tspan font-size="${enlarged?30:23}">${Sr(t.symbol||'\xA5')} </tspan>${Sr(t.value)}</text></g></g>
    <rect x=".6" y=".6" width="398.8" height="298.8" rx="31.4" fill="none" stroke="url(#rim)" stroke-width="1.2"/>
    <path d="M1.2 38V33Q1.2 1.2 33 1.2H350" fill="none" stroke="#fff" stroke-opacity=".5" stroke-width=".85"/>
    </svg>`;
  return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
}
const cardRenderer=materialCardTexture.toString().replace('function materialCardTexture','function ui');
html=html.slice(0,oldStart)+cardRenderer+html.slice(oldEnd);
once('var br=new Map;window.CheckLineLibrary={mount(t,l){let e=(0,Oh.createRoot)(t);br.set(t,e),e.render((0,w.jsx)(xp,{...l}))},unmount(){for(let[t,l]of br)l.unmount(),br.delete(t)}};',
 'var br=new Map,materialLibraryProps=new WeakMap;window.CheckLineLibrary={mount(t,l){let e=br.get(t);if(!e){e=(0,Oh.createRoot)(t);br.set(t,e)}materialLibraryProps.set(t,l);e.render((0,w.jsx)(xp,{...l}))},appearance(dark){for(let[t,l]of br){let p=materialLibraryProps.get(t);if(p){let next={...p,dark};materialLibraryProps.set(t,next);l.render((0,w.jsx)(xp,next))}}},unmount(){for(let[t,l]of br)l.unmount(),br.delete(t)}};');

// Isolate this study's browser example data from R34 and the real device.
html=html.replace(/data-review-storage="[^"]*"/,'data-review-storage="checkline-material-themes-r37-20261024"');
if(!html.includes('data-review-storage="checkline-material-themes-r37-20261024"'))html=html.replace('<html ','<html data-review-storage="checkline-material-themes-r37-20261024" ');
html=html.replace(/<title>[^<]*<\/title>/,'<title>CheckLine · 透光玻璃浅暗主题</title>');
once('id="app" class="app" data-theme="light"','id="app" class="app" data-material-study="r3-aligned" data-theme="light"');

// R3 uses a transparent three-stop volume and one fine illuminated waterline.
// Keep the same fill ratio, moving silhouette and animation used by R34.
const liquidStart=html.indexOf('function readerLiquidFace(c,interactive=true){');
const liquidEnd=html.indexOf('\nfunction cartridgeFace(c){',liquidStart);
if(liquidStart<0||liquidEnd<0)throw Error('Liquid face boundary missing');
let liquid=html.slice(liquidStart,liquidEnd);
liquid=liquid.replace('const shape=`M0 14 Q50 2 100 14 T200 14 T300 14 T400 14 T500 14 T600 14 T700 14 T800 14 V${height} H0Z`;',
 'const contour=`M0 14 C58 8 105 18 170 14 S280 8 340 14 S380 18 400 14 C458 8 505 18 570 14 S680 8 740 14 S780 18 800 14`;const shape=contour+` V${height} H0Z`;');
liquid=liquid.replace('<stop offset="0" stop-color="var(--water-top)"/><stop offset="1" stop-color="var(--water-bottom)"/>',
 '<stop offset="0" stop-color="var(--water-top)"/><stop offset=".33" stop-color="var(--water-middle)"/><stop offset="1" stop-color="var(--water-bottom)"/>');
liquid=liquid.replace('<path d="${shape}" fill="url(#${id}-sheen)"/>','<path class="r3-waterline" d="${contour}"/>');
if(!liquid.includes('class="r3-waterline"')||!liquid.includes('--water-middle')||!liquid.includes('const contour='))throw Error('R3 liquid optics patch incomplete');
html=html.slice(0,liquidStart)+liquid+html.slice(liquidEnd);

// The R3 upper gap is shorter than R34's old 70px launch space. Keep the
// resting lifted pose below the header; timing, contact feedback and gestures
// are unchanged. Live finger travel is still unconstrained by this resting pose.
const readerStart=html.indexOf('const READER_SEAT_Y=8;');
const readerEnd=html.indexOf('function wish',readerStart);
if(readerStart<0||readerEnd<0)throw Error('Reader optics boundary missing');
let readerStudy=html.slice(readerStart,readerEnd).replaceAll('-56','-18').replaceAll('-59','-21');
readerStudy=readerStudy.replace('d.wasConnected?-progress*64:0','d.wasConnected?-progress*26:0');
readerStudy=readerStudy.replace("parseFloat(getComputedStyle($('.cartridge-world',page)).getPropertyValue('--reader-expanded-stage-height'))","$('.cartridge-stage',page).offsetHeight");
html=html.slice(0,readerStart)+readerStudy+html.slice(readerEnd);

const header='<header class="review-header"><div><span class="wordmark">CheckLine<span class="brand-dot"></span></span><span class="review-label">透光材质 · 浅暗主题研究</span></div><div class="material-toolbar"><div class="material-theme-group" role="group" aria-label="样稿主题"><button data-material-theme="light" aria-pressed="true">浅色</button><button data-material-theme="dark" aria-pressed="false">暗色</button></div><a class="material-compare" href="material-compare-20261023.html" target="_blank" rel="noreferrer">并排对照</a><span class="prototype-badge">隔离示例 · App 未改动</span></div></header>';
const headerMatches=[...html.matchAll(/<header class="review-header">[\s\S]*?<\/header>/g)];
if(headerMatches.length!==1)throw Error('Review header boundary mismatch');
html=html.replace(headerMatches[0][0],header);
// The old research links are not shipped with this self-contained study.
html=html.replace(/<a[^>]*href="(?:review-20261022-r33\.html[^"]*|motion-lab-20261017[^"]*|reward-references-r32\.html[^"]*)"[^>]*>[\s\S]*?<\/a>/g,'');
// Buttons on the back stay still; retain pointer-driven flips on other surfaces.
once("button:not(.wish-face-tap):not(.wish-back-flip-zone),input,select,textarea'", "button:not(.wish-face-tap):not(.wish-back-flip-zone),input,select,textarea,.wish-liquid-actions'");
once("if(!card||e.pointerType==='touch'||reducedMotion()||wishMotion(card).task)return;const r=card.getBoundingClientRect()", "if(card&&(card.dataset.target==='back'||e.target.closest('.wish-liquid-actions'))){card.querySelector('.wish-hover-layer').style.transform='';return;}if(!card||e.pointerType==='touch'||reducedMotion()||wishMotion(card).task)return;const r=card.getBoundingClientRect()");
once("if(card&&!e.target.closest('button,input,select,textarea,a'))wishFlip(card,true)", "if(card&&!e.target.closest('button,input,select,textarea,a,.wish-liquid-actions'))wishFlip(card,true)");
// This isolated motion example must enter from 100% too: estimate 500, wallet
// 600, actual purchase 300. No wallet calculation or purchase rule is changed.
once("if(kind==='wish'){ui.tab='wish';render();startRedemption('w1');", "if(kind==='wish'){data.wishes.find(w=>w.id==='w1').reference=50000;ui.tab='wish';render();startRedemption('w1');");
const css=['surfaces.css','home.css','interactions.css'].map(file=>fs.readFileSync(path.join(work,file),'utf8')).join('\n');
once('</head>','<style id="material-theme-r3">\n'+css+'\n</style></head>');
const bridge=fs.readFileSync(path.join(work,'study-bridge.js'),'utf8');
const interactions=fs.readFileSync(path.join(work,'interactions.js'),'utf8');
once('outcomeSetupReview();\n\n});\n</script>','outcomeSetupReview();\n\n'+interactions+'\n\n'+bridge+'\n\n});\n</script>');

// Color only: retain the existing fracture geometry, impulse and six coin waves.
const palette={
 'rgba(241,231,252,':'rgba(226,247,252,',
 'rgba(179,154,205,.85)':'rgba(113,181,201,.85)',
 'rgba(247,241,254,.63)':'rgba(240,252,255,.63)',
 'rgba(164,137,193,.8)':'rgba(85,149,176,.8)',
 'rgba(117,90,146,.89)':'rgba(42,89,115,.89)',
 'rgba(62,40,91,.38)':'rgba(20,56,79,.38)',
 'rgba(63,43,88,.62)':'rgba(24,66,84,.62)',
 'rgba(241,224,255,':'rgba(212,242,252,',
 'rgba(189,151,221,':'rgba(137,207,229,',
 'rgba(165,133,198,0)':'rgba(113,179,208,0)',
 '#eee2fc':'#def5fc','#d1e5e0':'#c8e7e4',
 '#f6e7ff':'#e7faff','#c6a5e0':'#9bd4e7','#bfddd7':'#b7e0d8',
 '#bc9dd8':'#95bfd0',
 '#76528f':'#4c8297','#f5e8ff':'#e7f9ff','#c7a6e2':'#9ecddc',
 '#f4eaff':'#edfaff','#9b76b4':'#5c99af','#b593cf':'#83b6c8',
 '#f3e5ff':'#e9faff','#9470ab':'#538a9e','#76558d':'#47788d',
 '#ccb2e5':'#a4d9e8','#d9c2ed':'#c0eaf5','#f8f1ff':'#f0fcff',
 'rgba(252,245,255,':'rgba(240,252,255,',
 '#a58bbd':'#73a6b6','#ad8dc6':'#8ec8d9','#f5efff':'#effbff','#b8dcd5':'#bce7eb',
 '#d6c4e9':'var(--material-liquid-top)','#ae92c5':'var(--material-liquid-bottom)',
 '#d9b6f218':'#ace8f218'
};
const fxStart=html.indexOf('function glass(s,ms){'),fxEnd=html.indexOf('const OUTCOME_CASES=',fxStart);
if(fxStart<0||fxEnd<0)throw Error('Outcome palette boundary missing');
let fx=html.slice(fxStart,fxEnd);for(const[a,b]of Object.entries(palette))fx=fx.split(a).join(b);
html=html.slice(0,fxStart)+fx+html.slice(fxEnd);

const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
for(const [i,src]of scripts.entries())new vm.Script(src,{filename:'material-r35-script-'+i+'.js'});
fs.mkdirSync(archive,{recursive:true});
fs.writeFileSync(path.join(archive,'index.html'),html);
console.log(JSON.stringify({bytes:Buffer.byteLength(html),scripts:scripts.length,preview:'http://127.0.0.1:18873/compare.html'}));
