"""Build the portable documentation site: python examples/build_site.py."""
from pathlib import Path
from html import escape
from html.parser import HTMLParser
from urllib.parse import unquote, urlsplit
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'public'
CSS = '''body{margin:0;background:#f3f5f4;color:#20342e;font:17px/1.6 system-ui,sans-serif}main,nav{max-width:1080px;margin:auto;padding:24px}nav{display:flex;gap:24px;flex-wrap:wrap}a{color:#126c60}h1{font:normal 46px/1.15 Georgia,serif}h2{font:normal 30px Georgia,serif;margin-top:42px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:20px}.card,section{background:white;border:1px solid #d8e2dc;border-radius:12px;padding:24px;margin-bottom:20px}.badge{font-size:13px;letter-spacing:.06em;text-transform:uppercase;color:#64664d}img{max-width:100%;height:auto}pre{overflow:auto;background:#e9efeb;padding:16px}footer{margin-top:48px;color:#586c62}a:focus-visible{outline:3px solid #c07a21} @media(max-width:600px){h1{font-size:34px}main,nav{padding:16px}}'''

def page(path, title, body, prefix=''):
    dest = OUT / path
    dest.parent.mkdir(parents=True, exist_ok=True)
    nav = ''.join('<a href="{}{}">{}</a>'.format(prefix, url, label) for url,label in [('index.html','Surface diagrams'),('docs/TUTORIAL.html','Tutorial'),('gallery.html','Gallery'),('relations/index.html','Relations'),('fibrations/index.html','Lefschetz fibrations'),('releases.html','Releases')])
    dest.write_text('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+escape(title)+' | Surface diagrams</title><style>'+CSS+'</style><nav aria-label="Main">'+nav+'</nav><main><h1>'+escape(title)+'</h1>'+body+'<footer>Surface diagrams · SVG and TikZ · Mathematical catalog in development</footer></main></html>',encoding='utf-8')

def build():
    OUT.mkdir(exist_ok=True)
    shutil.copytree(ROOT/'docs', OUT/'docs', dirs_exist_ok=True)
    shutil.copytree(ROOT/'examples'/'output', OUT/'examples'/'output', dirs_exist_ok=True)
    for script in (ROOT/'examples').glob('*.py'):
        shutil.copy2(script, OUT/'examples'/script.name)
    entries = [json.loads(p.read_text(encoding='utf-8')) for p in sorted((ROOT/'docs'/'catalog').glob('*.json'))]
    for category, title in [('relations','Mapping class relations'),('fibrations','Lefschetz fibrations')]:
        cards = []
        for e in (e for e in entries if e['category']==category):
            cards.append('<article class="card"><span class="badge">'+escape(e['status'])+'</span><h2><a href="'+e['slug']+'.html">'+escape(e['title'])+'</a></h2><p>'+escape(e['description'])+'</p></article>')
            body = '<p class="badge">'+escape(e['status'])+' · no verified factorization supplied yet</p><p>'+escape(e['description'])+'</p>'
            body += ''.join('<section><h2>'+escape(k)+'</h2><p>'+escape(v)+'</p></section>' for k,v in e['sections'].items())
            body += '<p>Future formats will use common curve and factor IDs, an explicit multiplication order, and documented correspondences. A drawing alone does not verify an equivalence.</p>'
            page(category+'/'+e['slug']+'.html',e['title'],body,'../')
        page(category+'/index.html',title,'<p>Browse the planned library. Each entry has space for derivations and equivalent presentations.</p><div class="grid">'+''.join(cards)+'</div>','../')
    figures=[]
    for p in sorted((OUT/'examples/output/tutorial').glob('*.svg')):
        url=p.relative_to(OUT).as_posix()
        label=p.stem.replace('-',' ')
        tikz=p.with_suffix('.tikz')
        figures.append('<article class="card"><h2>'+escape(label)+'</h2><a href="'+url+'"><img loading="lazy" src="'+url+'" alt="'+escape(label)+'"></a><p><a href="'+url+'">SVG</a>'+(' · <a href="'+tikz.relative_to(OUT).as_posix()+'">TikZ</a>' if tikz.exists() else '')+'</p></article>')
    page('gallery.html','Illustrated gallery','<p>Runnable examples from the <a href="docs/TUTORIAL.html">tutorial</a>. These show implemented drawing features; the mathematical catalog is planned separately.</p>'+''.join(figures))
    page('index.html','Draw surfaces. Explore factorizations.','<p>A Python library and growing mathematical atlas for surface diagrams, relations and Lefschetz fibrations.</p><div class="grid"><section><h2><a href="docs/TUTORIAL.html">Start with the tutorial</a></h2><p>Runnable Python recipes and SVG/TikZ output.</p></section><section><h2><a href="gallery.html">Explore the gallery</a></h2><p>Planar curves, braids, genus surfaces and bordered reference families.</p></section><section><h2><a href="relations/index.html">Relations</a></h2><p>Lantern, half lantern, rose and daisy.</p></section><section><h2><a href="fibrations/index.html">Lefschetz fibrations</a></h2><p>MCK, hyperelliptic, BK, numbered examples and Gurtas.</p></section></div>')
    page('releases.html','Versioned releases','<p>Development version: 0.1.0a3. This is alpha software; catalog entries are placeholders.</p><p><a href="https://github.com/richardbuckman-math/surface-diagrams/releases">Published release downloads</a> · <a href="docs/RELEASING.md">Release procedure</a></p>')
    check_links()
    print('Built site and checked local links:', OUT)

def check_links():
    missing=[]
    class Links(HTMLParser):
        def handle_starttag(self, tag, attrs):
            for key,value in attrs:
                if key in ('href','src') and value:
                    url=urlsplit(value)
                    if not url.scheme and not url.netloc and url.path:
                        target=source.parent/unquote(url.path)
                        if not target.exists(): missing.append((source.relative_to(OUT),value))
    for source in OUT.rglob('*.html'):
        Links().feed(source.read_text(encoding='utf-8'))
    if missing: raise ValueError('Broken local links: '+repr(missing))

if __name__=='__main__':
    build()
