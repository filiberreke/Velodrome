"""Editable SVG sources for the ten user-supplied country designs.

Python stdlib emits exact UV-v1 layouts. Render the SVGs to PNG using sharp:
node render_national_kits.cjs
No photographs, human skin tones, lighting or model silhouettes are baked in.
"""
from pathlib import Path
import json
import math
from html import escape

HERE = Path(__file__).resolve().parent
DEST = HERE.parent / 'riders/national_kits'
SOURCE = HERE / 'national_kits'
REGIONS = {
    'torso': (.02, .52, .60, .98),
    'sleeve_L': (.62, .52, .78, .98),
    'sleeve_R': (.80, .52, .96, .98),
    'shorts_L': (.02, .02, .30, .48),
    'shorts_R': (.32, .02, .60, .48),
}
COUNTRIES = [
    ('denmark','Denemarken','DENMARK','#bd1930','#181a20','long'),
    ('portugal','Portugal','PORTUGAL','#f6f7fb','#17191e','long'),
    ('italy','Italie','ITALIA','#0862bd','#172332','short'),
    ('great_britain','Groot-Brittannie','GREAT BRITAIN','#f8f9fc','#122346','short'),
    ('australia','Australie','AUSTRALIA','#07524b','#151a1d','long'),
    ('new_zealand','Nieuw-Zeeland','NEW ZEALAND','#141519','#141519','short'),
    ('germany','Duitsland','GERMANY','#f7f8fc','#17191f','short'),
    ('france','Frankrijk','FRANCE','#162e5b','#16243d','long'),
    ('netherlands','Nederland','NEDERLAND','#ff7918','#142031','long'),
    ('united_states','Verenigde Staten','USA','#14284e','#14284e','long'),
]


def rect(x,y,w,h,color):
    return f'<rect x="{x:.3f}" y="{y:.3f}" width="{w:.3f}" height="{h:.3f}" fill="{color}"/>'


def text(x,y,label,size,color,rotation=0):
    return (f'<text transform="translate({x:.3f} {y:.3f}) rotate({rotation})" '
            f'text-anchor="middle" dominant-baseline="middle" font-family="Arial, sans-serif" '
            f'font-weight="700" font-size="{size:.3f}" fill="{color}">{escape(label)}</text>')


def star(x,y,r,color,points=5):
    pts=[]
    for i in range(points*2):
        angle=-math.pi/2+i*math.pi/points
        radius=r if i%2==0 else r*.43
        pts.append(f'{x+radius*math.cos(angle):.3f},{y+radius*math.sin(angle):.3f}')
    return f'<polygon points="{" ".join(pts)}" fill="{color}"/>'


def fern(x,y,w,h,color):
    # Original geometric fern, adapted to the reference's diagonal silver motif.
    bits=[f'<path d="M{x:.2f},{y+h:.2f} Q{x+w*.42:.2f},{y+h*.45:.2f} {x+w:.2f},{y:.2f}" stroke="{color}" stroke-width="{w*.035:.2f}" fill="none"/>']
    for i in range(11):
        t=(i+1)/12; cx=x+w*t; cy=y+h*(1-t)
        length=w*.37*math.sin(math.pi*t)**.6
        for sign in (-1,1):
            tipx=cx+sign*length*.72; tipy=cy-length*.58
            bits.append(f'<path d="M{cx:.2f},{cy:.2f} Q{tipx:.2f},{cy-length*.08:.2f} {tipx:.2f},{tipy:.2f} Q{cx+sign*length*.1:.2f},{cy-length*.3:.2f} {cx:.2f},{cy:.2f}" fill="{color}"/>')
    return ''.join(bits)


def crest(x,y,size,country,color):
    if country=='new_zealand': return fern(x-size/2,y-size/2,size,size,color)
    if country=='australia': return star(x,y,size*.4,color,7)
    if country=='italy':
        return (f'<g><path d="M{x-size*.4},{y-size*.5}h{size*.8}v{size*.55}q0,{size*.4} {-size*.4},{size*.55}q{-size*.4},{-size*.15} {-size*.4},{-size*.55}z" fill="#fff"/>'
                +rect(x-size*.34,y-size*.44,size*.23,size*.65,'#00995e')
                +rect(x+size*.11,y-size*.44,size*.23,size*.65,'#e92b3d')+'</g>')
    # Compact original heraldic silhouettes, rather than commercial sponsor marks.
    shapes={
        'germany':'M-10,-2 -26,-14 -21,1 -29,5 -16,10 -6,6 -8,22 0,16 8,22 6,6 16,10 29,5 21,1 26,-14 10,-2 6,-12 0,-18 -6,-12Z',
        'netherlands':'M-5,22 -2,8 -16,13 -20,6 -10,1 -15,-8 -7,-6 -9,-20 0,-15 6,-23 11,-12 6,-2 16,6 23,0 25,5 17,15 5,12 8,23Z',
        'france':'M-6,23 -3,7 -15,0 -25,-15 -12,-12 -4,-3 1,-13 -2,-20 6,-25 10,-18 18,-17 10,-10 12,4 6,12 15,20 7,22 2,15Z',
    }
    path=shapes.get(country)
    if path: return f'<path transform="translate({x} {y}) scale({size/55})" d="{path}" fill="{color}"/>'
    return ''


def flag(x,y,w,h,country):
    if country=='great_britain':
        return (rect(x,y,w,h,'#142b57')
            +f'<path d="M{x},{y}l{w},{h}M{x+w},{y}l{-w},{h}" stroke="#fff" stroke-width="{h*.22}"/>'
            +f'<path d="M{x},{y}l{w},{h}M{x+w},{y}l{-w},{h}" stroke="#d51d34" stroke-width="{h*.09}"/>'
            +rect(x+w*.40,y,w*.2,h,'#fff')+rect(x,y+h*.32,w,h*.36,'#fff')
            +rect(x+w*.45,y,w*.10,h,'#d51d34')+rect(x,y+h*.40,w,h*.20,'#d51d34'))
    if country=='denmark':
        return rect(x,y,w,h,'#bd1930')+rect(x+w*.30,y,w*.12,h,'#fff')+rect(x,y+h*.43,w,h*.16,'#fff')
    if country=='portugal':
        return rect(x,y,w*.4,h,'#009568')+rect(x+w*.4,y,w*.6,h,'#ed2939')+f'<circle cx="{x+w*.4}" cy="{y+h*.5}" r="{h*.18}" fill="#ffd24a"/>'
    if country=='united_states':
        bits=[rect(x,y,w,h,'#fff')]
        bits += [rect(x,y+i*h/13,w,h/13,'#db2f42') for i in range(0,13,2)]
        bits += [rect(x,y,w*.44,h*.54,'#14284e')]
        for row in range(3):
            for col in range(4): bits += [star(x+w*(.06+col*.10),y+h*(.09+row*.17),h*.035,'#fff')]
        return ''.join(bits)
    colors={
        'italy':['#00995e','#fff','#e92b3d'],
        'france':['#174695','#fff','#ec3344'],
        'germany':['#111318','#d82c36','#f3cb31'],
        'netherlands':['#e6323c','#fff','#174695'],
    }.get(country)
    if not colors: return ''
    vertical=country in ('italy','france')
    return ''.join(rect(x+i*w/3 if vertical else x,y if vertical else y+i*h/3,
                        w/3 if vertical else w,h if vertical else h/3,c) for i,c in enumerate(colors))


class Cell:
    def __init__(self, name):
        x0,y0,x1,y1=REGIONS[name]
        self.x,self.y=x0*1024,(1-y1)*1024
        self.w,self.h=(x1-x0)*1024,(y1-y0)*1024
        self.circ=self.w/1.5
    def xat(self,u): return self.x+self.circ*u
    def yat(self,v): return self.y+self.h*(1-v)
    def box(self,u0,v0,u1,v1,color): return rect(self.xat(u0),self.yat(v1),(u1-u0)*self.circ,(v1-v0)*self.h,color)
    def label(self,u,v,label,size,color,rotate=0): return text(self.xat(u),self.yat(v),label,size,color,rotate)


def art(country,title,shirt,shorts,sleeves):
    b=['<defs>']; masks=[]
    for name in REGIONS:
        c=Cell(name)
        b += [f'<clipPath id="{name}">'+rect(c.x-8,c.y-8,c.w+16,c.h+16,'#fff')+'</clipPath>']
        if name.startswith('sleeve') and sleeves=='short':
            masks += [rect(c.x-8,c.yat(.56),c.w+16,c.h*.56+16,'#000')]
    b += ['<mask id="coverage">'+rect(0,0,1024,1024,'#fff')+''.join(masks)+'</mask></defs><g mask="url(#coverage)">',rect(0,0,1024,1024,shorts)]
    for name in REGIONS:
        c=Cell(name); b += [f'<g clip-path="url(#{name})">']
        cloth=shirt
        if country=='portugal' and name.startswith('sleeve'): cloth='#ed2939' if name.endswith('L') else '#009d79'
        b += [rect(c.x-8,c.y-8,c.w+16,c.h+16,shorts if name.startswith('shorts') else cloth)]
        if name=='torso':
            if country in ('denmark','germany'):
                bands=[(.66,.74,'#fff'),(.47,.55,'#fff')] if country=='denmark' else [(.68,.73,'#111318'),(.63,.68,'#d82c36'),(.58,.63,'#f3cb31')]
                for v0,v1,color in bands: b += [c.box(-.10,v0,1.60,v1,color)]
            for u in (0,.5,1,1.5):
                front=abs(u-.5)<.01
                ink='#ffd23a' if country=='australia' else ('#15284e' if country in ('portugal','great_britain') else ('#17191e' if country in ('germany','netherlands') else '#fff'))
                if country not in ('netherlands','united_states') and (country!='denmark' or front):
                    size=21 if len(title)<10 else 16
                    label='GBR' if country=='great_britain' and front else ('NZL' if country=='new_zealand' and not front else title)
                    b += [c.label(u,.84,label,size,ink)]
                if country in ('italy','france'):
                    if not front or country=='italy':
                        colors=['#00995e','#fff','#e92b3d'] if country=='italy' else ['#174695','#fff','#ec3344']
                        for i,color in enumerate(colors): b += [c.box(u-.033+i*.022,.20,u-.011+i*.022,.72,color)]
                if country=='united_states':
                    b += [c.box(u-.11,.20,u+.11,1.02,'#cf2c3f'),c.box(u-.055,.20,u+.055,1.02,'#fff')]
                    if front: b += [flag(c.xat(u+.13),c.yat(.90),31,18,country)]
                if country=='portugal':
                    b += [flag(c.xat(u-.20),c.yat(.86),24,15,country),flag(c.xat(u-.035),c.yat(.31),22,14,country)]
                if country=='denmark' and front: b += [flag(c.xat(u+.20),c.yat(.87),30,20,country)]
                if country=='germany': b += [crest(c.xat(u+.19),c.yat(.85),24,country,'#222')]
                if country=='italy': b += [crest(c.xat(u+.18),c.yat(.91),22,country,'#fff')]
                if country=='france' and front: b += [crest(c.xat(u+.18),c.yat(.89),27,country,'#fff')]
                if country=='new_zealand': b += [fern(c.xat(u-.19),c.yat(.72),c.circ*.39,c.h*.47,'#eef0f3')]
                if country=='netherlands':
                    if front:
                        b += [flag(c.xat(u-.22),c.yat(.88),27,17,country),crest(c.xat(u+.16),c.yat(.85),31,country,'#fff')]
                    else:
                        b += [flag(c.xat(u-.04),c.yat(.95),27,17,country),c.label(u,.63,title,16,'#fff',90)]
                if country=='australia':
                    for du,v,r in [(0,.72,8),(-.10,.62,7),(.10,.66,7),(.04,.57,5),(0,.48,7)]: b += [star(c.xat(u+du),c.yat(v),r,'#ffd23a',7)]
                    pts=[(u-.25,.54),(u,.32),(u+.25,.48),(u+.25,.39),(u,.24),(u-.25,.46)]
                    b += ['<polygon fill="#ffd23a" points="'+' '.join(f'{c.xat(a):.2f},{c.yat(v):.2f}' for a,v in pts)+'"/>']
                if country=='great_britain':
                    for side in (-1,1):
                        pts=[(u+side*.19,.62),(u+side*.25,.69),(u+side*.25,.25),(u+side*.13,.29)]
                        b += ['<polygon fill="#d6243b" points="'+' '.join(f'{c.xat(a):.2f},{c.yat(v):.2f}' for a,v in pts)+'"/>']
                    if front:
                        for color,low in [('#172b53',.32),('#dd293e',.43)]:
                            pts=[(u-.23,low),(u+.23,low+.25),(u+.23,low+.34),(u-.23,low+.09)]
                            b += ['<polygon fill="'+color+'" points="'+' '.join(f'{c.xat(a):.2f},{c.yat(v):.2f}' for a,v in pts)+'"/>']
                    else: b += [flag(c.xat(u-.05),c.yat(.96),34,19,country)]
            for side in (.25,.75,1.25):
                if country=='portugal': b += [c.box(side-.045,.20,side+.045,.80,'#ed2939'),c.label(side,.45,'PORTUGAL',12,'#fff',90)]
                if country=='france':
                    b += [c.box(side-.045,.20,side+.045,.70,'#fff'),c.box(side-.010,.20,side+.018,.70,'#ed2939')]
                if country=='united_states': b += [c.box(side-.04,.20,side+.04,.63,'#cf2c3f')]
            b += [c.box(-.10,-.02,1.60,.20,shorts)]
            # The seated body's front pelvic bridge projects higher along the
            # torso axis than its rear waist. Cover that small central bridge
            # with shorts rather than leaking shirt color into the crotch.
            for center in (.5,1.5):
                points=[(center-.16,.20),(center-.10,.38),(center-.06,.45),
                        (center+.06,.45),(center+.10,.38),(center+.16,.20)]
                b += ['<polygon fill="'+shorts+'" points="'+' '.join(f'{c.xat(u):.2f},{c.yat(v):.2f}' for u,v in points)+'"/>']
        elif name.startswith('sleeve'):
            hem=.56 if sleeves=='short' else .0
            colors={
                'italy':['#00995e','#fff','#e92b3d'],
                'great_britain':['#cf263b','#fff','#172b53'],
                'germany':['#111318','#d82c36','#f3cb31'],
                'netherlands':['#e6323c','#fff','#174695'],
                'france':['#174695','#fff','#ec3344'],
            }.get(country)
            if colors:
                bandtop=.64 if sleeves=='short' else .73
                for i,color in enumerate(colors): b += [c.box(-.10,bandtop-(i+1)*.025,1.60,bandtop-i*.025,color)]
            if country=='portugal': b += [c.box(-.10,0,1.60,.05,'#fff')]
            if country=='australia': b += [c.box(-.10,.62,1.60,.69,'#ffd23a')]
            if country=='new_zealand': b += [c.label(.25,.62,'NZL',12,'#fff'),c.label(.75,.62,'NZL',12,'#fff')]
            if country=='france':
                for u in (.25,.75,1.25): b += [c.box(u-.08,0,u+.08,.59,'#fff'),c.box(u+.01,0,u+.07,.59,'#ed2939')]
            if country=='united_states':
                outer=.25 if name.endswith('L') else .75
                inner=.75 if name.endswith('L') else .25
                b += [c.box(inner-.12,0,inner+.12,1.02,'#cf2c3f')]
                for u in (outer,outer+1):
                    for v in (.14,.32,.50,.68,.86): b += [star(c.xat(u),c.yat(v),11,'#fff')]
        else:
            outer=.25 if name.endswith('L') else .75
            label={'united_states':'USA','great_britain':'GBR','france':'FRA','germany':'GER'}.get(country,title)
            ink='#ffd23a' if country=='australia' else '#f4f6fa'
            for u in (outer,outer+1):
                if country=='new_zealand': b += [fern(c.xat(u-.18),c.yat(.80),c.circ*.36,c.h*.50,'#eef0f3')]
                elif country!='united_states': b += [c.label(u,.52,label,24 if len(label)<8 else 18,ink,90 if name.endswith('L') else -90)]
                if country in ('denmark','italy','france'): b += [flag(c.xat(u-.08),c.yat(.12),25,17,country)]
            if country in ('germany','great_britain'):
                colors=['#111318','#d82c36','#f3cb31'] if country=='germany' else ['#fff','#d82c36','#fff']
                for i,color in enumerate(colors): b += [c.box(-.10,.025+i*.018,1.60,.043+i*.018,color)]
            if country=='netherlands': b += [c.box(outer-.11,.05,outer-.06,.16,shirt)]
        b += ['</g>']
    return ''.join(b)+'</g>'


def helmet(country):
    # Spherical helmet UV: back seam at u=0/1, face at u=.5; top V=1.
    c=Cell('torso'); c.x,c.y,c.w,c.h=.02*1024,.02*1024,.96*1024,.96*1024; c.circ=c.w/1.5
    bits=[rect(0,0,1024,1024,'#f7f8fb' if country!='united_states' else '#14284e')]
    for u in (0,.5,1,1.5):
        if country=='united_states': bits += [c.box(u-.055,0,u+.055,1,'#fff'),c.box(u-.024,0,u+.024,1,'#d52b40')]
        if country=='great_britain':
            if u in (0,1): bits += [flag(c.xat(u-.19),c.yat(.88),c.circ*.38,c.h*.30,country)]
            else: bits += [c.label(u,.77,'GBR',31,'#172b53')]
        if country in ('france','netherlands') and u in (0,1): bits += [flag(c.xat(u-.05),c.yat(.77),c.circ*.10,c.h*.10,country)]
        if country=='new_zealand' and u in (0,1): bits += [fern(c.xat(u-.07),c.yat(.83),c.circ*.14,c.h*.19,'#17191e')]
    return ''.join(bits)


def svg(content):
    return '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'+content+'</svg>\n'


def build():
    catalog=[]
    for country,name,title,shirt,shorts,sleeves in COUNTRIES:
        target=SOURCE/country; target.mkdir(parents=True,exist_ok=True)
        (DEST/country).mkdir(parents=True,exist_ok=True)
        (target/'skinsuit.svg').write_text(svg(art(country,title,shirt,shorts,sleeves)),encoding='utf-8')
        (target/'helmet.svg').write_text(svg(helmet(country)),encoding='utf-8')
        catalog.append(dict(id=country,name=name,sleeves=sleeves,
            skinsuit_png=f'res://assets/riders/national_kits/{country}/skinsuit.png',
            helmet_png=f'res://assets/riders/national_kits/{country}/helmet.png',visor='donker'))
    (DEST/'catalog.json').write_text(json.dumps(catalog,indent=2)+'\n',encoding='utf-8')
    cfg=['; Optional country examples. Copy selected keys into your personal config/riders_config.cfg.',
         '; These assignments are samples only; no personal configuration is distributed.','']
    for i,entry in enumerate(catalog,1):
        cfg += [f'; {entry["name"]} - {entry["sleeves"]} sleeves',f'[rider_{i:02d}]',
                f'skinsuit_png="{entry["skinsuit_png"]}"',f'helmet_png="{entry["helmet_png"]}"','visor="donker"','']
    (HERE.parent.parent/'config'/'riders_national_kits.example.cfg').write_text('\n'.join(cfg),encoding='utf-8')
    print('Generated 20 editable SVGs, catalog and example config')


if __name__=='__main__': build()
