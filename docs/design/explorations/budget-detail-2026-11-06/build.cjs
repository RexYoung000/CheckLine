const { readFileSync, writeFileSync } = require('node:fs');
const { join } = require('node:path');
const { createHash } = require('node:crypto');

const read = (name) => readFileSync(join(__dirname, name), 'utf8');
const base = read('../material-themes-2026-10-23/budget-home.html');
const sourceHash = createHash('sha256').update(base).digest('hex');
function replaceOnce(html, marker, replacement) {
  if (html.split(marker).length !== 2) throw new Error('Expected one source marker: ' + marker);
  return html.replace(marker, () => replacement);
}

let html = replaceOnce(base, '<head>', '<head>\n<meta name="prototype-source-sha256" content="' + sourceHash + '">');
html = replaceOnce(html, 'let data;\ntry {data=JSON.parse(localStorage.getItem(STORAGE)); if(data?.version!==1)data=null;}catch{}\ndata ||= fixture();', 'let data = fixture();');
html = replaceOnce(html, "function persist(){try{localStorage.setItem(STORAGE,JSON.stringify(data));}catch{toast('本页演示存储已满，输入仍保留在当前页面。');}}", 'function persist(){}');
html = replaceOnce(html, 'function wishSafePersist(){try{localStorage.setItem(STORAGE,JSON.stringify(data));return true;}catch{return false;}}', 'function wishSafePersist(){return true;}');
html = replaceOnce(html, '  smInstallPages();', '  smInstallPages();\n' + read('detail.js') + '\n  installBudgetDetailStudy();');
html = replaceOnce(html, '</head>', '<style id="budget-detail-study">\n' + read('detail.css') + '\n</style>\n</head>');
writeFileSync(join(__dirname, 'index.html'), html);
