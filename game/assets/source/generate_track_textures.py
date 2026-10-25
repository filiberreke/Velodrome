"""Rebuild the entirely original, procedural wood and paint textures.

Velodrome 250: no photography, third-party art or Blender is required.
Requires Python with numpy, scipy and Pillow. Run from anywhere.
The game ships with pregenerated PNGs; end users need no Python.
"""
from pathlib import Path
import numpy as np
from scipy.ndimage import gaussian_filter
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / 'textures'
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(250126)

W, H = 2048, 1024
N = 32  # Narrow timber boards in one tiled 2.24 m texture section.
BH = H // N
xx = np.linspace(0.0, 2 * np.pi, W, endpoint=False, dtype=np.float32)[None, :]
yy = np.arange(H, dtype=np.float32)[:, None]
board_id = np.arange(H, dtype=np.int32) // BH

# Small plank-to-plank shifts; original pale indoor-track timber color.
tints = rng.normal(0, 1, (N, 3)).astype(np.float32)
tints[:, 0] *= 7.5
tints[:, 1] *= 7.1
tints[:, 2] *= 6.0
base_rgb = np.array([193., 153., 107.], np.float32)

# Wood fibres extend mainly along the direction of travel, with wavy grain.
base_noise = rng.normal(size=(H,W)).astype(np.float32)
long_grain = gaussian_filter(base_noise, sigma=(1.5, 34), mode='wrap')
long_grain = long_grain / (np.std(long_grain) + 1e-6)
large_noise = gaussian_filter(rng.normal(size=(H,W)).astype(np.float32), sigma=(12,100), mode='wrap')
large_noise = large_noise / (np.std(large_noise) + 1e-6)
frequencies = (4.3 + 0.4*np.cos(board_id[:,None]*0.71))
feather = (np.sin((yy + 3.2*np.sin(xx*2.0 + board_id[:,None]*0.31))*0.24
                  + frequencies * np.sin(xx*0.5 + board_id[:,None]*0.33)) * 2.1)
stripe = 5.2 * long_grain + 2.4 * large_noise + feather
# Warm and cool fibres give the boards an organic appearance without visual noise.
arr = (base_rgb[None,None,:] + tints[board_id][:,None,:]
       + stripe[:,:,None] * np.array([1.0,0.95,0.84],np.float32)[None,None,:])
arr = np.broadcast_to(arr, (H,W,3)).copy()

# Inset dark joins between laminated boards, with a tiny beveled highlight.
within = np.arange(H) % BH
for j in (0,1):
    arr[within == j] *= 0.70 if j == 0 else 0.87
arr[within == 2] *= 1.035
arr[within == BH-1] *= 0.86

# Short end joints are staggered from one board to the next.
for plank in range(N):
    cuts = sorted(rng.choice(np.arange(280,W-170), size=2, replace=False))
    for cut in cuts:
        lo = plank * BH + 2
        hi = (plank+1) * BH - 2
        arr[lo:hi,cut:cut+2] *= 0.81
        arr[lo:hi,cut+2:cut+3] *= 1.025

# Satin finish: a faint nonuniform varnish highlight rather than plastic glare.
varnish = 0.7 * np.sin(xx*4 + 0.6*np.sin(yy/63))
arr += varnish[:,:,None]
Image.fromarray(np.uint8(np.clip(arr,0,255)), 'RGB').save(OUT/'velodrome_wood_pine.png', optimize=True)

# A blue cote d'azur made of scuffed, low-gloss paint (not neon cyan).
w,h = 1024,512
n = rng.normal(size=(h,w)).astype(np.float32)
fine = gaussian_filter(n, (1.2,16), mode='wrap')
fine /= max(np.std(fine),1e-6)
coarse = gaussian_filter(rng.normal(size=(h,w)).astype(np.float32), (17,70), mode='wrap')
coarse /= max(np.std(coarse),1e-6)
paint = np.zeros((h,w,3), np.float32)
paint[:] = [58,151,180]
paint += (2.6*fine + 2.2*coarse)[:,:,None]*[0.8,1.0,1.15]
# Fine longitudinal brushed-paint variation, a little faded in the middle.
p = np.arange(h)[:,None].astype(np.float32) / h
paint += (2.0*np.cos(2*np.pi*p))[:,:,None]*[0.8,1.0,1.0]
Image.fromarray(np.uint8(np.clip(paint,0,255)), 'RGB').save(OUT/'velodrome_cote_azur.png', optimize=True)

print('Generated original artwork:', *(f'{p.name} ({p.stat().st_size//1024} KB)' for p in sorted(OUT.glob('*.png'))))
