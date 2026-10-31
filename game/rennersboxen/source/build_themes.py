"""Rebuild the eleven original, editable national booth texture designs.

Run with Python + Pillow; the Godot assets have no Python dependency.
Dimensions use metres. Images are material artwork, not concept screenshots.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
import math

ROOT = Path(__file__).resolve().parents[1]
FONT = Path('C:/Windows/Fonts/arialbd.ttf')
THEMES = [
    ('belgium','België','BEL','BELGIUM','#73c7ef','#16191c'),
    ('netherlands','Nederland','NED','TeamNL','#ff7900','#ffffff'),
    ('france','Frankrijk','FRA','FRANCE','#142e59','#ffffff'),
    ('italy','Italië','ITA','ITALIA','#0968bf','#ffffff'),
    ('germany','Duitsland','GER','DEUTSCHLAND','#f4f4ee','#17191d'),
    ('great_britain','Groot-Brittannië','GBR','GREAT BRITAIN','#f5f5ee','#122849'),
    ('denmark','Denemarken','DEN','DANMARK','#bd1930','#ffffff'),
    ('australia','Australië','AUS','AUSTRALIA','#075043','#f5c622'),
    ('new_zealand','Nieuw-Zeeland','NZL','NEW ZEALAND','#15171b','#eeeeea'),
    ('portugal','Portugal','POR','PORTUGAL','#f5f4ed','#14294d'),
    ('united_states','Verenigde Staten','USA','USA','#14284d','#ffffff'),
]


def star(d,x,y,r,color,points=5):
    d.polygon([(x+math.cos(-math.pi/2+i*math.pi/points)*r*(1 if i%2==0 else .42),
                y+math.sin(-math.pi/2+i*math.pi/points)*r*(1 if i%2==0 else .42))
               for i in range(points*2)],fill=color)


def union_jack(d,x,y,w,h):
    d.rectangle((x,y,x+w,y+h),fill='#143568')
    # Flag strokes are clipped to this dedicated flag-sized image by flag().
    for col,sw in [('#ffffff',h*.22),('#c6253d',h*.075)]:
        d.line((x,y,x+w,y+h),fill=col,width=round(sw))
        d.line((x+w,y,x,y+h),fill=col,width=round(sw))
    d.rectangle((x+w*.4,y,x+w*.6,y+h),fill='#ffffff')
    d.rectangle((x,y+h*.32,x+w,y+h*.68),fill='#ffffff')
    d.rectangle((x+w*.44,y,x+w*.56,y+h),fill='#c6253d')
    d.rectangle((x,y+h*.4,x+w,y+h*.6),fill='#c6253d')


def flag(country,w=300,h=180):
    im=Image.new('RGB',(w,h),'#ffffff');d=ImageDraw.Draw(im)
    triples={'belgium':('#111111','#f6d222','#e82c35'),
             'france':('#17458e','#ffffff','#e52d3c'),
             'italy':('#009768','#ffffff','#e52c39'),
             'netherlands':('#bc2134','#ffffff','#174484'),
             'germany':('#141414','#d92332','#efc42b')}
    if country in triples:
        vertical=country in ('belgium','france','italy')
        for i,c in enumerate(triples[country]):
            d.rectangle((round(i*w/3),0,round((i+1)*w/3),h) if vertical else
                        (0,round(i*h/3),w,round((i+1)*h/3)),fill=c)
    elif country=='great_britain': union_jack(d,0,0,w,h)
    elif country=='denmark':
        d.rectangle((0,0,w,h),fill='#bd1930')
        d.rectangle((w*.3,0,w*.41,h),fill='white')
        d.rectangle((0,h*.43,w,h*.57),fill='white')
    elif country in ('australia','new_zealand'):
        d.rectangle((0,0,w,h),fill='#122957')
        jack=flag('great_britain',w//2,h//2);im.paste(jack,(0,0))
        if country=='australia':
            for xx,yy,rr,pts in [(.25,.75,.13,7),(.75,.2,.09,7),(.6,.55,.09,7),(.88,.5,.09,7),(.75,.85,.09,7),(.8,.62,.05,5)]:
                star(d,xx*w,yy*h,rr*h,'white',pts)
        else:
            for xx,yy in [(.75,.2),(.6,.52),(.88,.48),(.75,.84)]:
                star(d,xx*w,yy*h,.105*h,'white');star(d,xx*w,yy*h,.075*h,'#d3233a')
    elif country=='portugal':
        d.rectangle((0,0,w*.4,h),fill='#087a48');d.rectangle((w*.4,0,w,h),fill='#d92236')
        cx,cy=w*.4,h*.5;r=h*.23
        d.ellipse((cx-r,cy-r,cx+r,cy+r),outline='#f4cc29',width=max(2,h//26))
        d.rectangle((cx-r*.42,cy-r*.65,cx+r*.42,cy+r*.5),fill='white',outline='#c82937',width=max(2,h//35))
        for xx,yy in [(0,-.25),(-.2,0),(.2,0),(0,.25),(0,0)]:
            d.ellipse((cx+(xx-.06)*r,cy+(yy-.06)*r,cx+(xx+.06)*r,cy+(yy+.06)*r),fill='#17488a')
    elif country=='united_states':
        for i in range(13):
            d.rectangle((0,i*h/13,w,(i+1)*h/13),fill='#c72b3b' if i%2==0 else 'white')
        d.rectangle((0,0,w*.4,h*7/13),fill='#14284e')
        for row in range(9):
            n=6 if row%2==0 else 5
            for col in range(n):
                star(d,w*.4*(col+(0.5 if n==6 else 1))/6,h*7/13*(row+.5)/9,h*.021,'white')
    return im


def label(d,text,cx,cy,maxw,size,color):
    font=ImageFont.truetype(str(FONT),size)
    while d.textbbox((0,0),text,font=font)[2]>maxw:
        size-=1;font=ImageFont.truetype(str(FONT),size)
    d.text((cx,cy),text,fill=color,font=font,anchor='mm')


def fern(d,x,y,w,h):
    d.line((x,y+h,x+w,y),fill='#e9eeed',width=12)
    for i in range(13):
        t=(i+1)/15;cx=x+w*t;cy=y+h*(1-t);length=w*.5*math.sin(math.pi*t)
        for side in [-1,1]:
            d.polygon([(cx,cy),(cx+side*length*.75,cy-length*.72),
                       (cx+side*length*.65,cy-length*.26)],fill='#e9eeed')


def artwork(country,title,bg,ink):
    w,h=1280,1024;im=Image.new('RGB',(w,h),bg);d=ImageDraw.Draw(im)
    if country=='belgium':
        im.paste(flag(country,w,260),(0,430));label(d,title,w/2,250,w*.88,138,ink)
    elif country=='netherlands': label(d,title,w/2,420,w*.88,220,ink)
    elif country in ('france','italy'):
        band=flag(country,240,h);im.paste(band,(w//2-120,0))
        d.rectangle((60,220,w-60,410),fill=bg);label(d,title,w/2,315,w*.85,155,ink)
    elif country=='germany':
        im.paste(flag(country,w,280),(0,440));d.rectangle((0,870,w,h),fill='#17191d')
        label(d,title,w/2,275,w*.9,130,ink)
    elif country=='great_britain':
        d.polygon([(0,530),(w,925),(w,h),(0,655)],fill='#14284e')
        d.polygon([(0,390),(w,785),(w,865),(0,470)],fill='#c92339')
        d.rectangle((0,900,w,h),fill='#14284e')
        label(d,title,w/2,250,w*.87,130,ink)
    elif country=='denmark':
        d.rectangle((w*.25,0,w*.35,h),fill='white');d.rectangle((0,490,w,630),fill='white')
        label(d,title,w*.66,260,w*.59,130,ink)
    elif country=='australia':
        for top,thick in [(90,28),(590,75),(710,26)]:d.rectangle((0,top,w,top+thick),fill=ink)
        label(d,title,w/2,300,w*.9,150,ink);star(d,w/2,460,90,ink,7)
    elif country=='new_zealand':
        fern(d,80,70,710,700);label(d,title,w*.53,875,w*.91,114,ink)
    elif country=='portugal':
        d.rectangle((0,580,w*.4,h),fill='#07814c');d.rectangle((w*.4,580,w,h),fill='#d82136')
        d.rectangle((0,570,w,590),fill='#e8c34a');label(d,title,w/2,310,w*.9,150,ink)
        d.ellipse((w*.4-95,510,w*.4+95,700),outline='#e8c34a',width=16)
        d.ellipse((w*.4-45,510,w*.4+45,700),outline='#e8c34a',width=10)
        d.line((w*.4-95,605,w*.4+95,605),fill='#e8c34a',width=10)
    elif country=='united_states':
        for i in range(10):d.rectangle((i*w/10,590,(i+1)*w/10,h),fill='#d3293b' if i%2==0 else 'white')
        for i in range(5):star(d,250+i*195,155,45,'white')
        label(d,title,w/2,400,w*.85,245,ink)
    return im


def main():
    catalog=[]
    for country,name,code,title,bg,ink in THEMES:
        folder=ROOT/'textures'/country;folder.mkdir(parents=True,exist_ok=True)
        art=artwork(country,title,bg,ink)
        art.save(folder/'panel.png');art.save(folder/'curtain.png')
        header=Image.new('RGB',(1024,160),'#f4f3ed');header.paste(flag(country,210,126),(20,17))
        label(ImageDraw.Draw(header),code,635,83,700,119,'#142031');header.save(folder/'header.png')
        catalog.append(dict(id=country,name=name,code=code,base=bg,ink=ink))
        (ROOT/'scenes').mkdir(exist_ok=True)
        (ROOT/'scenes'/f'{country}.tscn').write_text(
            '[gd_scene load_steps=2 format=3]\n\n'
            '[ext_resource type="Script" path="res://rennersboxen/rider_box.gd" id="1"]\n\n'
            f'[node name="Rennersbox_{code}" type="Node3D"]\nscript = ExtResource("1")\ncountry = "{country}"\n',encoding='utf-8')
    (ROOT/'themes.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf-8')
    lines=['extends RefCounted', '# Explicit preloads preserve all texture dependencies during Godot export.', 'const DATA := {']
    for item in catalog:
        country=item['id']
        lines.append('    '+json.dumps(country)+': {')
        lines.append('        "name": '+json.dumps(item['name'],ensure_ascii=False)+',')
        for part in ('panel','curtain','header'):
            lines.append(f'        "{part}": preload("res://rennersboxen/textures/{country}/{part}.png"),')
        lines.append('    },')
    lines.append('}')
    (ROOT/'themes.gd').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(f'{len(catalog)} themes, {len(catalog)*3} PNG textures, {len(catalog)} scenes')


if __name__=='__main__':main()
