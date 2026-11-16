const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const dir = __dirname;
const read = name => fs.readFileSync(path.join(dir, name), 'utf8');
const source = read('../budget-detail-2026-11-06/index.html');
let html = source;
function once(before, after) {
  if (html.split(before).length !== 2) throw new Error('Source boundary changed: ' + before.slice(0, 100));
  html = html.replace(before, () => after);
}
const textureStart = html.indexOf('function ui(t,dark=false,enlarged=false){');
const textureEnd = html.indexOf('var w=Vl(La(),1);function xp(', textureStart);
if (textureStart < 0 || textureEnd < textureStart) throw new Error('Missing existing library texture renderer');
const originalTexture = html.slice(textureStart, textureEnd);
once(originalTexture, 'function ui(t,dark=false,enlarged=false){return window.CheckLineLibraryCard.texture({...t,fill:t.libraryFill??t.fill/100},dark);\n}');
// The retained renderer is used only for the sphere. The study owns the arc.
once('let[c,f]=(0,bl.useState)("arc")', 'let[c,f]=(0,bl.useState)("dome")');
// The empty-library fixture is a real empty collection, with a real empty home.
once('if (materialNeedBudget()) readerLibrary(true);', 'readerLibrary(true);');
once('<head>', '<head>\n<meta name="library-study-source-sha256" content="' + createHash('sha256').update(source).digest('hex') + '">');
once('</head>', '<style id="library-study-style">\n' + ['card.css', 'orb.css', 'library.css'].map(read).join('\n') + '\n</style>\n<script>\n' + ['card.js', 'orb.js'].map(read).join('\n') + '\n</script>\n</head>');
once('  installBudgetDetailStudy();', '  installBudgetDetailStudy();\n' + read('library.js') + '\n  installCardLibraryStudy();');
html = html.replace(/<title>[^<]*<\/title>/, '<title>CheckLine · 卡库光点与回收样稿</title>');
fs.writeFileSync(path.join(dir, 'index.html'), html);
console.log('Built card library study from current detail sample. ' + Buffer.byteLength(html) + ' bytes.');
