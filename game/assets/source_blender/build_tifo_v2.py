"""Trace the approved boarding pixels into fixed paths; no fonts or live text.
Run with Python + Pillow + numpy, then Godot tests/bake_tifo_v2.gd.
"""
from pathlib import Path
from collections import defaultdict
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'branding'

def outline(mask):
    edges = defaultdict(list)
    h,w = mask.shape
    for y,x in zip(*np.nonzero(mask)):
        x,y=int(x),int(y)
        if y==0 or not mask[y-1,x]: edges[(x,y)].append((x+1,y))
        if x==w-1 or not mask[y,x+1]: edges[(x+1,y)].append((x+1,y+1))
        if y==h-1 or not mask[y+1,x]: edges[(x+1,y+1)].append((x,y+1))
        if x==0 or not mask[y,x-1]: edges[(x,y+1)].append((x,y))
    paths=[]
    while edges:
        start=next(iter(edges)); p=start; points=[]
        while True:
            points.append(p); q=edges[p].pop()
            if not edges[p]: del edges[p]
            p=q
            if p==start: break
        area=abs(sum(p[0]*points[(i+1)%len(points)][1]-points[(i+1)%len(points)][0]*p[1] for i,p in enumerate(points)))/2
        if area<85: continue
        # Keep corners only: exact pixel silhouette, all counters preserved.
        corners=[p for i,p in enumerate(points) if (p[0]-points[i-1][0],p[1]-points[i-1][1]) != (points[(i+1)%len(points)][0]-p[0],points[(i+1)%len(points)][1]-p[1])]
        paths.append('M'+'L'.join(f'{x},{y}' for x,y in corners)+'Z')
    return ''.join(paths)

def build():
    # Crop only the authentic wordmark; exclude the small boarding slogan.
    im=Image.open(ROOT/'boarding/velodrome-boarding.png').convert('RGB').crop((85,125,2098,500))
    a=np.array(im).astype(float); r,g,b=a[:,:,0],a[:,:,1],a[:,:,2]
    masks=[('#10aceb',(b>135)&(g>105)&(r<95)&(g>r*1.6)),
           ('#ffffff',(r>195)&(g>195)&(b>195)),
           ('#f5bf5b',(r>175)&(g>100)&(b<155)&(r>g*1.08))]
    svg=['<svg xmlns="http://www.w3.org/2000/svg" width="4096" height="1024" viewBox="0 0 4096 1024">',
         '<rect width="4096" height="1024" fill="#10264b"/>',
         '<g transform="translate(205 170) scale(1.83 1.83)">']
    for color,mask in masks:
        mask=np.array(Image.fromarray(mask).filter(ImageFilter.MedianFilter(5)))
        svg.append(f'<path fill="{color}" fill-rule="evenodd" d="{outline(mask)}"/>')
    svg.extend(['</g>','</svg>'])
    (OUT/'velodrome_tifo.svg').write_text('\n'.join(svg),encoding='utf-8')
    print('Outlined boarding wordmark written; no text, fonts, external images.')

if __name__=='__main__': build()
