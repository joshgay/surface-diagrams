// Optional documentation build: npm install --no-save marked
// Then: node examples/build_tutorial_html.cjs
// The Python library and figure generator have no added dependencies.
const fs = require('node:fs');
const path = require('node:path');
const {marked} = require('marked');
const docs = path.resolve(__dirname, '../docs');
const body = marked.parse(fs.readFileSync(path.join(docs, 'TUTORIAL.md'), 'utf8'));
const css = `
:root{color-scheme:light;font-family:Georgia,serif;color:#202e38;background:#eef2f5}
body{margin:0}main{max-width:980px;margin:32px auto;padding:48px 60px;background:white;box-shadow:0 6px 32px #13273814}
h1{font-size:38px;line-height:1.15;color:#142f46}h2{font-size:26px;color:#174560;margin-top:55px;border-top:1px solid #dbe5eb;padding-top:28px}
p,li{font-size:17px;line-height:1.65}a{color:#00688e;text-underline-offset:3px}
pre{background:#142a3a;color:#f5f8fa;padding:22px;overflow:auto;border-radius:8px;font-size:13px;line-height:1.65}
code{font-family:Consolas,monospace}p code,li code,td code{font-size:.88em;background:#edf3f6;padding:2px 4px;border-radius:3px}
pre code{background:none}img{display:block;max-width:100%;max-height:1100px;margin:25px auto;box-sizing:border-box;padding:16px;border:1px solid #dbe5eb;border-radius:8px;background:#fff}
table{border-collapse:collapse;width:100%;margin:24px 0;font-size:15px}th,td{padding:11px 13px;text-align:left;vertical-align:top;border:1px solid #dbe5eb;line-height:1.5}th{background:#edf3f6}
@media(max-width:700px){main{padding:24px 18px;margin:0}h1{font-size:30px}table{font-size:12px}th,td{padding:6px}}
@media print{main{margin:0;padding:0;box-shadow:none}h2{break-after:avoid}pre,img,table{break-inside:avoid}}
`;
fs.writeFileSync(path.join(docs,'TUTORIAL.html'), `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Surface diagrams: illustrated tutorial</title><style>${css}</style></head><body><main>${body}</main></body></html>\n`);
console.log('Built docs/TUTORIAL.html from docs/TUTORIAL.md');
