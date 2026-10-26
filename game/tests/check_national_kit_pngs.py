"""Semantic checks of final PNGs, including coverage and UV seam padding.

Requires Pillow. Run from any working directory.
"""
from pathlib import Path
import json
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/riders/national_kits'
entries=json.loads((ASSETS/'catalog.json').read_text(encoding='utf-8'))
assert len(entries)==10 and len({entry['id'] for entry in entries})==10
for entry in entries:
    suit=Image.open(ASSETS/entry['id']/'skinsuit.png').convert('RGBA')
    helmet=Image.open(ASSETS/entry['id']/'helmet.png').convert('RGBA')
    assert suit.size==helmet.size==(1024,1024)
    assert helmet.getextrema()[3]==(255,255), 'Helmet must stay opaque'
    for x in (700,900):
        assert suit.getpixel((x,100))[3]==255, 'Shoulder must be clothed'
        alpha=suit.getpixel((x,400))[3]
        assert alpha==(0 if entry['sleeves']=='short' else 255), 'Wrong sleeve length'
    # Degenerate torso UVs at V=.52 occur on the pelvic bridge. They must
    # sample a solid shorts color, including neighboring filter pixels.
    for x in (70,250,450,580):
        pixel=suit.getpixel((x,485))
        assert suit.getpixel((x,491))==pixel and suit.getpixel((x,496))==pixel, 'UV border color fringe'
    assert suit.getpixel((50,600))[3]==255, 'Shorts must be opaque'
    print(entry['id'],'PASS')
portugal=Image.open(ASSETS/'portugal/skinsuit.png').convert('RGB')
red,green=portugal.getpixel((700,100)),portugal.getpixel((900,100))
assert red[0]>red[1]*2 and green[1]>green[0]*2, 'Portugal front-reference sleeve assignment changed'
print('NATIONAL_KIT_PNGS: PASS (20 PNGs, coverage, seam padding, Portugal sleeves)')
