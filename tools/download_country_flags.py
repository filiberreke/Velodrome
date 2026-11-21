"""Refresh original PNGs from Countryflags.com; retain provenance and checksums."""
import concurrent.futures
import hashlib
import html
import json
from pathlib import Path
import re
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "game/assets/flags"


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=40) as response:
        return response.read()


def download(country):
    slug = {"great_britain": "united-kingdom"}.get(country, country.replace("_", "-"))
    page = f"https://www.countryflags.com/{slug}-flag-image/original/"
    content = fetch(page).decode()
    urls = re.findall(r'href="([^"]+/flag-png-medium\.png[^"]*)"', content)
    if not urls:
        raise RuntimeError(f"No original medium PNG: {page}")
    url = html.unescape(urls[0])
    data = fetch(url)
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise RuntimeError(f"Not a PNG: {url}")
    (DEST / f"{country}.png").write_bytes(data)
    print(country, len(data), flush=True)
    return country, {"page": page, "download": url, "sha256": hashlib.sha256(data).hexdigest()}


def license_text(content):
    main = re.search(r"<main\b[^>]*>(.*?)</main>", content, re.S)[1]
    lines = html.unescape(re.sub(r"<[^>]+>", "\n", main)).splitlines()
    text = "\n".join(line.strip() for line in lines if line.strip())
    return "Source: https://www.countryflags.com/license-agreement/\n\n" + text + "\n"


if __name__ == "__main__":
    DEST.mkdir(parents=True, exist_ok=True)
    source = (ROOT / "game/rennersboxen/rider_box.gd").read_text(encoding="utf-8")
    countries = re.findall(r'"([a-z_]+)"', re.search(r"const COUNTRIES := (\[.*?\])", source)[1])
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        manifest = dict(pool.map(download, countries))
    (DEST / "sources.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    license_page = fetch("https://www.countryflags.com/license-agreement/").decode()
    (DEST / "license-source.txt").write_text(license_text(license_page), encoding="utf-8")
