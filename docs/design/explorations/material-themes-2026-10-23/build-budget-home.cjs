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
const edgeStart=scene.indexOf('<rect x="40" y="76" width="352" height="300" rx="32" fill="#000" filter="url(#light-thickness)"/>');
const edgeEnd=scene.indexOf('<text x="62"',edgeStart);
if(edgeStart<0||edgeEnd<0)throw Error('Approved edge geometry missing');
const svg=(content)=>'<svg class="hm-optics" viewBox="40 76 352 300" preserveAspectRatio="none" aria-hidden="true">'+defs+content+'</svg>';
const body=svg('<rect x="40" y="76" width="352" height="300" style="fill:var(--ice);fill-opacity:var(--ice-alpha)"/><rect x="40" y="76" width="352" height="300" fill="url(#light-reflection)"/>');
const edge=svg(scene.slice(edgeStart,edgeEnd));
const normalize=s=>s.replaceAll('light-','HMID-').replaceAll('var(--','var(--hm-');
let helper=fs.readFileSync(path.join(dir,'src/budget-home.js'),'utf8').replace('__HOME_BODY__',JSON.stringify(normalize(body))).replace('__HOME_EDGE__',JSON.stringify(normalize(edge)));
helper+='\n'+fs.readFileSync(path.join(dir,'src/budget-home-liquid.js'),'utf8');
helper+='\n'+fs.readFileSync(path.join(dir,'src/budget-detail.js'),'utf8');
helper+='\n'+fs.readFileSync(path.join(dir,'src/budget-pages.js'),'utf8');
once('function cartridgeFace(c){',helper+'\nfunction cartridgeFace(c){');
once('const t=totals(c),ready=readerConnected();let face=readerLiquidFace(c);','const t=totals(c),ready=readerConnected();let face=hmMaterializeFace(readerLiquidFace(c),c);');
once('<div class="liquid-card restored-detail-card">${libraryCardFace(c)}</div>','${dmDetailCard(c)}');
const bubbles=match(html,/function readerBubbleMarkup\(\)\{[\s\S]*?\n\}/);
once(bubbles,'function readerBubbleMarkup(){return hmBubbleField();}');
once('const materialQuery = new URL(location.href).searchParams;','smInstallPages();\n  const materialQuery = new URL(location.href).searchParams;');
once("['detail', '预算工作区'], ['record', '消费详情']", "['detail', '预算工作区'], ['budget-records', '预算消费记录'], ['record', '消费详情']");
once("} else if (['detail', 'record', 'trend', 'history', 'info'].includes(view)) {", "} else if (view === 'budget-records') {\n        const card = materialNeedBudget();\n        if (card) navigate('detail', {id:card.id, section:'records'});\n      } else if (['detail', 'record', 'trend', 'history', 'info'].includes(view)) {");
const css=['budget-home','budget-detail','budget-pages','wish-material','dark-ui','light-ui'].map(name=>fs.readFileSync(path.join(dir,'src/'+name+'.css'),'utf8')).join('\n');
once('</head>','<style id="budget-home-material">\n'+themeTokens+'\n'+css+'\n</style></head>');
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
