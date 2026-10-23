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
const cardRenderer='function ui(t,l=!1,e=!1){'+
 'let p=l?{ink:"#f0fbff",top:"#48bad8",bottom:"#102b38",water1:"#c5f6ff33",water2:"#102b388c",rim:"#e7fbff9c"}:{ink:"#123c4e",top:"#c5eaf2",bottom:"#83aebc",water1:"#e0faff40",water2:"#245c713d",rim:"#ffffffeb"},f=300*(1-t.fill/100),r=e?38:23,h=e?53:43,'+
 'g=`<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600" viewBox="0 0 400 300"><defs><linearGradient id="base" x1="0" y1="0" x2=".65" y2="1"><stop stop-color="${p.top}"/><stop offset="1" stop-color="${p.bottom}"/></linearGradient><linearGradient id="water" x1="0" y1="0" x2="0" y2="1"><stop stop-color="${p.water1}"/><stop offset="1" stop-color="${p.water2}"/></linearGradient><radialGradient id="shine" cx="0.06" cy="0" r="1"><stop stop-color="#fff" stop-opacity="${l?.24:.55}"/><stop offset=".65" stop-color="#fff" stop-opacity=".025"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient><linearGradient id="rim" x1="0" y1="0" x2="1" y2="1"><stop stop-color="${p.rim}"/><stop offset=".5" stop-color="${l?"#b1e4f650":"#efffff77"}"/><stop offset="1" stop-color="${l?"#a4d6ea50":"#fcffffaa"}"/></linearGradient><clipPath id="clip"><rect x="1.3" y="1.3" width="397.4" height="297.4" rx="29"/></clipPath></defs><g clip-path="url(#clip)"><rect width="400" height="300" fill="url(#base)"/><path d="M0 ${f} Q50 ${f-8} 100 ${f} T200 ${f} T300 ${f} T400 ${f} V300H0Z" fill="url(#water)"/><rect width="400" height="300" fill="url(#shine)"/><g fill="${p.ink}" font-family="-apple-system,BlinkMacSystemFont,Arial,\'PingFang SC\',sans-serif"><text fill="${l?"#102b38":"#163c4d"}" x="28" y="${e?62:51}" font-size="${r}" font-weight="450">${Sr(t.name)}</text><text x="371" y="${e?253:260}" text-anchor="end" font-size="${h}" font-weight="500" letter-spacing="-1"><tspan font-size="${e?30:23}">${Sr(t.symbol||"\\xA5")} </tspan>${Sr(t.value)}</text></g></g><rect x="1" y="1" width="398" height="298" rx="29" fill="none" stroke="url(#rim)" stroke-width="1.6"/></svg>`;return"data:image/svg+xml;charset=utf-8,"+encodeURIComponent(g)}';
html=html.slice(0,oldStart)+cardRenderer+html.slice(oldEnd);
once('var br=new Map;window.CheckLineLibrary={mount(t,l){let e=(0,Oh.createRoot)(t);br.set(t,e),e.render((0,w.jsx)(xp,{...l}))},unmount(){for(let[t,l]of br)l.unmount(),br.delete(t)}};',
 'var br=new Map,materialLibraryProps=new WeakMap;window.CheckLineLibrary={mount(t,l){let e=br.get(t);if(!e){e=(0,Oh.createRoot)(t);br.set(t,e)}materialLibraryProps.set(t,l);e.render((0,w.jsx)(xp,{...l}))},appearance(dark){for(let[t,l]of br){let p=materialLibraryProps.get(t);if(p){let next={...p,dark};materialLibraryProps.set(t,next);l.render((0,w.jsx)(xp,next))}}},unmount(){for(let[t,l]of br)l.unmount(),br.delete(t)}};');

// Isolate this study's browser example data from R34 and the real device.
html=html.replace(/data-review-storage="[^"]*"/,'data-review-storage="checkline-material-themes-r36-20261023"');
if(!html.includes('data-review-storage="checkline-material-themes-r36-20261023"'))html=html.replace('<html ','<html data-review-storage="checkline-material-themes-r36-20261023" ');
html=html.replace(/<title>[^<]*<\/title>/,'<title>CheckLine · 透光玻璃浅暗主题</title>');
once('id="app" class="app" data-theme="light"','id="app" class="app" data-material-study="r3-aligned" data-theme="light"');

const header='<header class="review-header"><div><span class="wordmark">CheckLine<span class="brand-dot"></span></span><span class="review-label">透光材质 · 浅暗主题研究</span></div><div class="material-toolbar"><div class="material-theme-group" role="group" aria-label="样稿主题"><button data-material-theme="light" aria-pressed="true">浅色</button><button data-material-theme="dark" aria-pressed="false">暗色</button></div><a class="material-compare" href="material-compare-20261023.html" target="_blank" rel="noreferrer">并排对照</a><span class="prototype-badge">隔离示例 · App 未改动</span></div></header>';
const headerMatches=[...html.matchAll(/<header class="review-header">[\s\S]*?<\/header>/g)];
if(headerMatches.length!==1)throw Error('Review header boundary mismatch');
html=html.replace(headerMatches[0][0],header);
// The old research links are not shipped with this self-contained study.
html=html.replace(/<a[^>]*href="(?:review-20261022-r33\.html[^"]*|motion-lab-20261017[^"]*|reward-references-r32\.html[^"]*)"[^>]*>[\s\S]*?<\/a>/g,'');
const css=fs.readFileSync(path.join(work,'surfaces.css'),'utf8')+'\n'+fs.readFileSync(path.join(work,'home.css'),'utf8');
once('</head>','<style id="material-theme-r3">\n'+css+'\n</style></head>');
const bridge=fs.readFileSync(path.join(work,'study-bridge.js'),'utf8');
once('outcomeSetupReview();\n\n});\n</script>','outcomeSetupReview();\n\n'+bridge+'\n\n});\n</script>');

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
 '#bc9dd8':'#95bfd0'
};
const fxStart=html.indexOf('function glass(s,ms){'),fxEnd=html.indexOf('function outcomeSummary',fxStart);
if(fxStart<0||fxEnd<0)throw Error('Outcome palette boundary missing');
let fx=html.slice(fxStart,fxEnd);for(const[a,b]of Object.entries(palette))fx=fx.split(a).join(b);
html=html.slice(0,fxStart)+fx+html.slice(fxEnd);

const scripts=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)].map(m=>m[1]);
for(const [i,src]of scripts.entries())new vm.Script(src,{filename:'material-r35-script-'+i+'.js'});
fs.mkdirSync(archive,{recursive:true});
fs.writeFileSync(path.join(archive,'index.html'),html);
console.log(JSON.stringify({bytes:Buffer.byteLength(html),scripts:scripts.length,preview:'http://127.0.0.1:18873/compare.html'}));
