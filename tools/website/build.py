# -*- coding: utf-8 -*-
"""Bouw de statische site vanuit de repository. Zie --help voor de uitvoeropties."""
import argparse
import base64
from functools import cache
import html
from pathlib import Path
import re
import shutil
from PIL import Image
from content import PAGES, SLUG, UI, REPO, page

SITE = Path(__file__).resolve().parents[2] / "website"
IMG_DIR = SITE / "assets" / "img"
DOMAIN = "https://velodrome.wielerpraat.be"
LANGS = ["nl", "en"]

@cache
def img_dims(path):
    with Image.open(path) as image:
        return image.size


@cache
def data_uri(path, mime):
    return f"data:{mime};base64," + base64.b64encode(path.read_bytes()).decode()


def render(lang, key, mode, root):
    """mode 'site': echte paden; mode 'bundle': hash-routes en ingebedde beelden."""
    ui = UI[lang]
    other = "en" if lang == "nl" else "nl"

    def L(p, lg=None):
        lg = lg or lang
        if mode == "bundle":
            return f"#{lg}-{p}"
        slug = SLUG[lg][p]
        return root + lg + "/" + (slug + "/" if slug else "")

    def IMG(k, alt, cls="", eager=False, full_width=False):
        path = IMG_DIR / f"{k}.jpg"
        w, h = img_dims(path)
        alt = html.escape(alt, quote=True)
        c = f' class="{cls}"' if cls else ""
        if mode == "bundle":
            src = data_uri(path.with_name(f"{path.stem}-800.jpg"), "image/jpeg")
            load = 'fetchpriority="high"' if eager else 'loading="lazy"'
            return f'<img{c} src="{src}" alt="{alt}" width="{w}" height="{h}" {load}>'
        load = 'fetchpriority="high"' if eager else 'loading="lazy" decoding="async"'
        sizes = "100vw" if full_width else "(max-width: 860px) 100vw, 560px"
        return (f'<img{c} src="{root}assets/img/{k}.jpg" srcset="{root}assets/img/{k}-800.jpg 800w, {root}assets/img/{k}.jpg {w}w" '
                f'sizes="{sizes}" alt="{alt}" width="{w}" height="{h}" {load}>')

    def PREVIEW(key, alt):
        filename = "hero-omnium-800.jpg" if key == "omnium" else f"mode-previews/{key}.png"
        path = IMG_DIR / filename
        width, height = img_dims(path)
        mime = "image/jpeg" if key == "omnium" else "image/png"
        src = data_uri(path, mime) if mode == "bundle" else f"{root}assets/img/{filename}"
        return (f'<img class="mode-card-image" src="{src}" alt="{html.escape(alt, quote=True)}" '
                f'width="{width}" height="{height}" loading="lazy" decoding="async">')

    def VIDEO(name, label):
        directory = SITE / "assets" / "video"
        filename = f"{name}.mp4"
        poster_name = f"{name}.jpg"
        width, height = img_dims(directory / poster_name)
        if mode == "bundle":
            src = data_uri(directory / filename, "video/mp4")
            poster = data_uri(directory / poster_name, "image/jpeg")
        else:
            src = f"{root}assets/video/{filename}"
            poster = f"{root}assets/video/{poster_name}"
        return (f'<video controls playsinline preload="none" poster="{poster}" width="{width}" height="{height}" '
                f'aria-label="{html.escape(label, quote=True)}">\n'
                f'  <source src="{src}" type="video/mp4">\n'
                f'  <a href="{src}">{html.escape(label)}</a>\n'
                '</video>')

    title, desc, body = page(lang, key, L, IMG, PREVIEW, VIDEO)
    if mode == "bundle":
        body = re.sub(r'href="#(nl|en)-(\w+)#[^"]*"', r'href="#\1-\2"', body)

    logo = (data_uri(IMG_DIR / "wordmark-sm.png", "image/png") if mode == "bundle" else root + "assets/img/wordmark-sm.png")
    bell = (data_uri(IMG_DIR / "piste-o.svg", "image/svg+xml") if mode == "bundle" else root + "assets/img/piste-o.svg")
    nav_links = []
    for p in PAGES:
        current = ' aria-current="page"' if p == key else ""
        nav_links.append(f'<a href="{L(p)}"{current}>{ui["nav"][p]}</a>')
    nav = "".join(nav_links)
    header = f'''<a class="skip" href="#main">{ui["skip"]}</a>
<header class="top"><div class="wrap">
  <a class="brand" href="{L("home")}"><img src="{logo}" alt="Vélodrome" width="216" height="42"></a>
  <nav class="nav" aria-label="{ui["menu"]}">{nav}</nav>
  <a class="lang" href="{L(key, other)}" hreflang="{other}" lang="{other}" data-lang="{other}" aria-label="{ui["switch_label"]}">{ui["switch"]}</a>
</div></header>'''
    footer = f'''<footer class="foot"><div class="wrap">
  <img src="{bell}" alt="" width="32" height="32">
  <p>{ui["footer"]}</p>
  <a href="{REPO}">{ui["source"]}</a>
</div></footer>'''
    return title, desc, header + body + footer

def site_page(lang, key):
    slug = SLUG[lang][key]
    depth = 1 + (1 if slug else 0)
    root = "../" * depth
    title, desc, content = render(lang, key, "site", root)
    url = lambda lg: f"{DOMAIN}/{lg}/" + (SLUG[lg][key] + "/" if SLUG[lg][key] else "")
    alt = "".join(f'<link rel="alternate" hreflang="{lg}" href="{url(lg)}">' for lg in LANGS)
    alt += f'<link rel="alternate" hreflang="x-default" href="{DOMAIN}/">'
    og_locale = "nl_BE" if lang == "nl" else "en_GB"
    script_name = {"home": "carousel.js", "downloads": "downloads.js"}.get(key)
    script = f'\n<script src="{root}assets/{script_name}" defer></script>' if script_name else ""
    return f'''<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(desc, quote=True)}">
<link rel="canonical" href="{url(lang)}">{alt}
<meta property="og:type" content="website"><meta property="og:site_name" content="Vélodrome">
<meta property="og:title" content="{html.escape(title, quote=True)}"><meta property="og:description" content="{html.escape(desc, quote=True)}">
<meta property="og:url" content="{url(lang)}"><meta property="og:image" content="{DOMAIN}/assets/img/og.jpg"><meta property="og:locale" content="{og_locale}">
<meta name="twitter:card" content="summary_large_image">
<meta name="theme-color" content="#122C50">
<link rel="icon" href="{root}assets/img/piste-o.svg" type="image/png">
<link rel="stylesheet" href="{root}assets/site.css">{script}
</head>
<body>
{content}
<script>document.addEventListener("click",function(e){{var a=e.target.closest("[data-lang]");if(a)try{{localStorage.setItem("velodrome-lang",a.dataset.lang)}}catch(_){{}}}});</script>
</body>
</html>
'''

ROOT_INDEX = '''<!doctype html>
<html lang="nl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Vélodrome</title>
<meta name="description" content="Vélodrome – baanwielerspel op een piste van 250 meter. Track cycling game on a 250-metre velodrome.">
<link rel="canonical" href="https://velodrome.wielerpraat.be/nl/">
<link rel="alternate" hreflang="nl" href="https://velodrome.wielerpraat.be/nl/"><link rel="alternate" hreflang="en" href="https://velodrome.wielerpraat.be/en/"><link rel="alternate" hreflang="x-default" href="https://velodrome.wielerpraat.be/">
<link rel="icon" href="assets/img/piste-o.svg" type="image/png">
<link rel="stylesheet" href="assets/site.css">
<script>
(function(){var l;try{l=localStorage.getItem("velodrome-lang")}catch(e){}
if(l!=="nl"&&l!=="en"){var ls=navigator.languages||[navigator.language||""];l="en";for(var i=0;i<ls.length;i++){var c=(ls[i]||"").toLowerCase();if(c.indexOf("nl")===0){l="nl";break}if(c.indexOf("en")===0){break}}}
location.replace(l+"/");})();
</script>
</head>
<body>
<main class="wrap page">
<img src="assets/img/wordmark-sm.png" alt="Vélodrome" width="216" height="42" style="height:56px;width:auto;margin-bottom:24px">
<p><a class="btn primary" href="nl/" hreflang="nl" lang="nl">Nederlands</a> <a class="btn" href="en/" hreflang="en" lang="en">English</a></p>
</main>
</body>
</html>
'''

NOT_FOUND = '''<!doctype html>
<html lang="nl"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Pagina niet gevonden – Vélodrome</title><link rel="stylesheet" href="/assets/site.css"><meta name="robots" content="noindex"></head>
<body><main class="wrap page"><img src="/assets/img/wordmark-sm.png" alt="Vélodrome" width="216" height="42" style="height:48px;width:auto;margin-bottom:28px">
<h1>Deze pagina bestaat niet.</h1><p>Controleer het adres of ga terug naar de startpagina.</p>
<p lang="en">This page doesn’t exist. Check the address or go back to the home page.</p>
<p class="actions"><a class="btn primary" href="/nl/">Naar de startpagina</a><a class="btn" href="/en/" lang="en">Go to the home page</a></p></main></body></html>
'''

def build_site(site):
    if site.resolve() != SITE:
        shutil.copytree(SITE / "assets", site / "assets", dirs_exist_ok=True)
    for lang in LANGS:
        for key in PAGES:
            directory = site / lang / SLUG[lang][key]
            directory.mkdir(parents=True, exist_ok=True)
            (directory / "index.html").write_text(site_page(lang, key), encoding="utf-8")

    urls = [f"{DOMAIN}/{lang}/{SLUG[lang][key]}".rstrip("/") + "/" for lang in LANGS for key in PAGES]
    sitemap = (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'
        + "".join(f"  <url><loc>{url}</loc></url>\n" for url in urls)
        + "</urlset>\n"
    )
    files = {
        "index.html": ROOT_INDEX,
        "404.html": NOT_FOUND,
        "CNAME": "velodrome.wielerpraat.be\n",
        ".nojekyll": "",
        "robots.txt": f"User-agent: *\nAllow: /\nSitemap: {DOMAIN}/sitemap.xml\n",
        "sitemap.xml": sitemap,
    }
    for name, content in files.items():
        (site / name).write_text(content, encoding="utf-8")


def build_preview(output):
    css = (SITE / "assets" / "site.css").read_text(encoding="utf-8")
    scripts = "\n".join((SITE / "assets" / name).read_text(encoding="utf-8") for name in ("carousel.js", "downloads.js"))
    # Eén bestand met alle pagina’s als views (#nl-home, #en-races, ...)
    views = []
    for lang in LANGS:
        for key in PAGES:
            title, desc, content = render(lang, key, "bundle", "")
            content = content.replace('href="#main"', f'href="#{lang}-{key}"').replace('id="main"', "")
            views.append(f'<div class="view" id="{lang}-{key}" lang="{lang}" data-title="{html.escape(title, quote=True)}" hidden>{content}</div>')
    preview = f'''<!doctype html>
<html lang="nl"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Vélodrome – baanwielrennen op 250 meter</title>
<style>{css}</style></head>
<body>
{''.join(views)}
<script>
(function(){{
  var cur=null;
  function show(){{
    var h=decodeURIComponent(location.hash.slice(1));
    var v=h&&document.getElementById(h);
    if(v&&v.classList.contains("view")){{
      if(cur)cur.hidden=true; cur=v; v.hidden=false; document.documentElement.lang=v.lang; document.title=v.dataset.title; window.scrollTo(0,0); return;
    }}
    if(cur&&h){{var t=null;try{{t=cur.querySelector("#"+CSS.escape(h))}}catch(e){{}}if(t){{t.scrollIntoView();return;}}}}
    if(!cur){{var l="nl";try{{l=localStorage.getItem("velodrome-lang")||((navigator.language||"").toLowerCase().indexOf("nl")===0?"nl":"en")}}catch(e){{}}
      cur=document.getElementById(l+"-home");cur.hidden=false;document.documentElement.lang=l;document.title=cur.dataset.title;}}
  }}
  document.addEventListener("click",function(e){{var a=e.target.closest("[data-lang]");if(a)try{{localStorage.setItem("velodrome-lang",a.dataset.lang)}}catch(_){{}}}});
  window.addEventListener("hashchange",show); show();
}})();
</script>
<script>{scripts}</script>
</body></html>'''
    output.write_text(preview, encoding="utf-8", newline="\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    output = parser.add_mutually_exclusive_group(required=True)
    output.add_argument("--in-place", action="store_true", help="Genereer de HTML in website/.")
    output.add_argument("--output", type=Path, help="Schrijf site/ en preview.html naar deze map.")
    args = parser.parse_args()
    if args.in_place:
        build_site(SITE)
    else:
        build_site(args.output / "site")
        build_preview(args.output / "preview.html")


if __name__ == "__main__":
    main()
