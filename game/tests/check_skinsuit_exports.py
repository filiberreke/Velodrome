"""Compare baseline/rebuilt GLBs without Blender dependencies.

python game/tests/check_skinsuit_exports.py baseline_build build
Allows new UVs/material splits, requires identical vertex positions and colors,
bone weights, morph deltas, skeleton nodes and animation samples.
"""
import collections
import json
from pathlib import Path
import struct
import sys


class GLB:
    def __init__(self, path):
        data = Path(path).read_bytes()
        size = struct.unpack_from('<I', data, 12)[0]
        self.doc = json.loads(data[20:20+size])
        self.binary = data[28+size:]

    def values(self, index):
        a = self.doc['accessors'][index]
        count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
        fmt = '<' + {5121:'B', 5123:'H', 5125:'I', 5126:'f'}[a['componentType']]*count
        result = [(0,)*count for _ in range(a['count'])]
        if 'bufferView' in a:
            v = self.doc['bufferViews'][a['bufferView']]
            offset = v.get('byteOffset', 0)+a.get('byteOffset', 0)
            stride = v.get('byteStride', struct.calcsize(fmt))
            result = [struct.unpack_from(fmt, self.binary, offset+i*stride) for i in range(a['count'])]
        if 'sparse' in a:
            sparse = a['sparse']
            idx, val = sparse['indices'], sparse['values']
            iv, vv = (self.doc['bufferViews'][x['bufferView']] for x in (idx,val))
            ifmt = '<'+{5121:'B',5123:'H',5125:'I'}[idx['componentType']]
            for i in range(sparse['count']):
                index = struct.unpack_from(ifmt, self.binary, iv.get('byteOffset',0)+idx.get('byteOffset',0)+i*struct.calcsize(ifmt))[0]
                result[index] = struct.unpack_from(fmt, self.binary, vv.get('byteOffset',0)+val.get('byteOffset',0)+i*struct.calcsize(fmt))
        return result

    def vertices(self):
        out = set()
        for mesh in self.doc['meshes']:
            for p in mesh['primitives']:
                attrs = {k:self.values(v) for k,v in p['attributes'].items()
                         if not k.startswith('TEXCOORD') and k not in ('TANGENT', 'NORMAL')}
                targets = [self.values(t['POSITION']) for t in p.get('targets', [])]
                material = self.doc['materials'][p['material']]
                name = material['name'].removesuffix('_kit')
                color = tuple(material.get('pbrMetallicRoughness', {}).get('baseColorFactor', [1,1,1,1]))
                for vi in range(len(attrs['POSITION'])):
                    vertex = tuple((k, tuple(round(x,6) for x in attrs[k][vi])) for k in sorted(attrs))
                    morph = tuple(tuple(round(x,6) for x in t[vi]) for t in targets)
                    out.add((mesh['name'], name, color, vertex, morph))
        return out

    def animations(self):
        out = {}
        for a in self.doc['animations']:
            channels = []
            for channel in a['channels']:
                sampler = a['samplers'][channel['sampler']]
                channels.append((channel['target'], sampler.get('interpolation', 'LINEAR'),
                                 self.values(sampler['input']), self.values(sampler['output'])))
            out[a['name']] = channels
        return out


def compare(before, after):
    a, b = GLB(before), GLB(after)
    assert a.doc['nodes'] == b.doc['nodes'], 'Skeleton / node transforms changed'
    assert a.doc['skins'] == b.doc['skins'], 'Skin bindings changed'
    for skin_a, skin_b in zip(a.doc['skins'], b.doc['skins']):
        assert a.values(skin_a['inverseBindMatrices']) == b.values(skin_b['inverseBindMatrices'])
    assert a.animations() == b.animations(), 'Animation samples changed'
    assert a.vertices() == b.vertices(), 'Vertex positions / weights / morphs / default colors changed'
    for mesh in b.doc['meshes']:
        if mesh['name'] == 'Rider':
            assert len(mesh['extras']['targetNames']) == 6
    print(Path(after).name, 'PASS: identical geometry, weights, six morphs, colors, rig and animations')


if __name__ == '__main__':
    for name in ('velodrome_rider.glb', 'velodrome_pursuit.glb'):
        compare(Path(sys.argv[1])/name, Path(sys.argv[2])/name)
