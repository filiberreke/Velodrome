"""Generate the Belgium sample and labeled SVG UV template; Python stdlib only."""
import ast
from pathlib import Path
import struct
import zlib

HERE = Path(__file__).resolve().parent
SIZE = 1024
REGIONS = next(ast.literal_eval(n.value) for n in ast.parse(
    (HERE / 'skinsuit_uv.py').read_text()).body
    if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'REGIONS' for t in n.targets))
BLUE, BLACK, YELLOW, RED = (169, 217, 244), (24, 26, 30), (255, 213, 0), (228, 35, 44)


def color(region, v):
    if region.startswith('shorts') or (region == 'torso' and v < 0.20):
        return BLACK
    if region == 'torso':
        if 0.64 <= v < 0.75: return BLACK
        if 0.53 <= v < 0.64: return YELLOW
        if 0.42 <= v < 0.53: return RED
    if region.startswith('sleeve'):
        if 0.12 <= v < 0.18: return BLACK
        if 0.06 <= v < 0.12: return YELLOW
        if v < 0.06: return RED
    return BLUE


def build():
    # Extend each painted cell into its gutter to prevent mipmap edge bleeding.
    pixels = bytearray(BLACK * (SIZE * SIZE))
    for name, (x0, y0, x1, y1) in REGIONS.items():
        for y in range(max(0, int((1-y1)*SIZE)-8), min(SIZE, int((1-y0)*SIZE)+8)):
            v = max(0, min(1, (1-(y+0.5)/SIZE-y0)/(y1-y0)))
            rgb = bytes(color(name, v))
            for x in range(max(0, int(x0*SIZE)-8), min(SIZE, int(x1*SIZE)+8)):
                offset = (y*SIZE+x)*3
                pixels[offset:offset+3] = rgb
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind+data))
    raw = b''.join(b'\0'+pixels[y*SIZE*3:(y+1)*SIZE*3] for y in range(SIZE))
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>2I5B', SIZE, SIZE, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    out = HERE.parent / 'riders/national_kits/belgium/skinsuit.png'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(png)
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">',
           '<rect width="1024" height="1024" fill="#eee"/>']
    for name, (x0, y0, x1, y1) in REGIONS.items():
        x, y, w, h = x0*SIZE, (1-y1)*SIZE, (x1-x0)*SIZE, (y1-y0)*SIZE
        svg += [f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#a9d9f4" stroke="black"/>',
                f'<text x="{x+6}" y="{y+24}" font-size="18">{name}</text>']
    svg.append('</svg>')
    (HERE / 'skinsuit_uv_template.svg').write_text('\n'.join(svg))
    print(out)


if __name__ == '__main__':
    build()
