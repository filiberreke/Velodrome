"""Own geometry/palette diagrams; no reference photos or sponsor graphics.
Run from repository root: python docs/venues/tools/draw_gent_proposal.py
Requires numpy and matplotlib. Values are design proposals, not measured plans.
"""
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Arc, Rectangle

OUT = Path(__file__).resolve().parents[1] / 'gent'
PAPER, INK, MUTED = '#F5F1E9', '#243B55', '#666E74'
RED, GOLD, WOOD, BLUE = '#D82632', '#D4A63D', '#C6A87D', '#3F88BC'
plt.rcParams.update({'font.family': 'DejaVu Sans', 'text.color': INK, 'axes.labelcolor': INK,
                     'svg.fonttype': 'none', 'svg.hashsalt': 'velodrome-gent-proposal', 'font.size': 10})

def oval(length, radius, transition):
    n = int(np.ceil(length / 2 / .01)); ds = length / 2 / n
    straight = (length - 2*np.pi*radius) / 2
    def heading(s):
        unwrapped = s - (straight-transition/2)
        turns = np.floor(unwrapped / (length/2)); q = unwrapped % (length/2)
        arc = np.pi*radius
        integral = lambda t: t**4*(2.5+t*(-3+t))
        area = np.full_like(q, arc)
        mask = q < transition
        area[mask] = transition*integral(q[mask]/transition)
        mask = (q >= transition) & (q < arc)
        area[mask] = q[mask]-transition/2
        mask = (q >= arc) & (q < arc+transition)
        t = (q[mask]-arc)/transition
        area[mask] = arc-transition/2+transition*(t-integral(t))
        return turns*np.pi+area/radius
    mid = heading((np.arange(n)+.5)*ds)
    half = np.vstack(([0.,0.], np.cumsum(np.column_stack((-np.sin(mid),np.cos(mid)))*ds,axis=0)))
    half -= half[-1]/2
    outline = np.vstack((half,-half,half[0]))
    return np.vstack((outline[::20],outline[-1]))

fig=plt.figure(figsize=(15,10.2),facecolor=PAPER)
fig.text(.055,.955,'GENT',fontsize=30,fontweight='bold')
fig.text(.055,.923,'Voorstel voor een eigen korte piste en zaal',fontsize=15)
fig.text(.945,.952,'ISSUE #59  /  25.11.2026',ha='right',fontsize=10,color=MUTED)
fig.text(.945,.925,'TER GOEDKEURING',ha='right',fontsize=11,fontweight='bold',color=RED)

ax=fig.add_axes([.055,.47,.53,.39],facecolor=PAPER)
a=oval(250.,18.,36.);b=oval(1000/6,12.,24.)
ax.plot(a[:,1],a[:,0],color='#9A9E9F',linestyle='--',lw=2,label='Vélodrome · 250 m')
ax.fill(b[:,1],b[:,0],facecolor=WOOD,alpha=.15)
ax.plot(b[:,1],b[:,0],color=RED,lw=3,label='Gent · nominaal 1000/6 m')
ax.axhline(0,color=INK,lw=.5,alpha=.2);ax.axvline(0,color=INK,lw=.5,alpha=.2)
ax.set_aspect('equal');ax.set_xlabel('Lange as Z (m)');ax.set_ylabel('Dwarsas X (m)')
ax.legend(loc='upper center',bbox_to_anchor=(.5,-.15),frameon=False,ncol=1)
ax.set_title('Referentielijnen op dezelfde schaal',loc='left',fontweight='bold',pad=16)
ax.spines[['top','right']].set_visible(False)
for sp in ['bottom','left']:ax.spines[sp].set_color('#BBC0BF')
ax.tick_params(colors=MUTED)
ax.text(0,0,'Eigen Gent-inrichting\ngeen gekopieerd middenterrein',ha='center',va='center',fontsize=10)
fig.text(.055,.405,'Vorm van Gent: R = 12 m en overgang = 24 m zijn blockoutwaarden, geen opmeting.',fontsize=9,color=MUTED)

ax2=fig.add_axes([.64,.49,.305,.365],facecolor=PAPER);ax2.axis('off')
ax2.text(0,1,'Kenmerken voor de bouwer',fontweight='bold',fontsize=13,va='top')
lines=[('PISTE','Kort, steil, eigen breedte en rijlijnen'),('ZAAL','Rechthoekig; vlak leesbaar plafond'),('TRIBUNES','Nieuwe gele zitvakken en toegangen'),('MIDDENTERREIN','Nieuwe lege basis; gericht inrichten'),('WEL HERGEBRUIKEN','Official + attributen, tv-box + presentatoren'),('NIEUW VERDELEN','Publiek, techniek en optionele horeca')]
y=.84
for title,desc in lines:
 ax2.text(0,y,title,fontsize=9,fontweight='bold',color=RED)
 ax2.text(0,y-.067,desc,fontsize=10)
 y-=.15

ax3=fig.add_axes([.055,.16,.31,.21],facecolor=PAPER)
for angle,width,col,label in [(42,8.25,'#9A9E9F','Vélodrome 42°'),(52,7.,RED,'Gent 52°')]:
 r=np.deg2rad(angle);x=width*np.cos(r);y=width*np.sin(r)
 ax3.plot([0,x],[0,y],lw=5,color=col,solid_capstyle='round')
 ax3.text(6.9,6.2 if angle == 52 else 4.8,label,va='center',fontsize=10,color=col)
ax3.plot([0,7],[0,0],lw=1,color=INK)
ax3.add_patch(Arc((0,0),3,3,theta1=0,theta2=52,color=INK,lw=1))
ax3.set_xlim(-.2,12.8);ax3.set_ylim(-.4,6.9);ax3.set_aspect('equal');ax3.axis('off')
ax3.set_title('Bochtprofiel',loc='left',fontweight='bold',pad=8)
fig.text(.055,.135,'Breedtevoorstel Gent: 7,0 m over het houtoppervlak.',fontsize=9,color=MUTED)

ax4=fig.add_axes([.44,.15,.505,.23],facecolor=PAPER);ax4.axis('off')
ax4.text(0,1,'Eigen kleurenpalet',fontweight='bold',fontsize=13,va='top')
colors=[('Hout',WOOD),('Stoelen',GOLD),('Rood',RED),('Blauw',BLUE),('Plafond','#D8D1C4'),('Constructie',INK)]
for i,(label,color) in enumerate(colors):
 x=i/6
 ax4.add_patch(Rectangle((x,.39),.145,.38,facecolor=color,edgecolor='none'))
 ax4.text(x,.26,label,fontsize=9)
 ax4.text(x,.12,color,fontsize=8,color=MUTED)
fig.text(.055,.072,'ONTWERPKEUZES  •  Gent wordt getoond als 166,67 m; publieke bron: 166,66 m. Nominale zesrondenbaan vraagt akkoord.',fontsize=9,color=INK)
fig.text(.055,.046,'Bronnen, afwijkingen, gedeelde assets en bouwfasen staan in ontwerp.md en referenties.md. Schema is geen opgemeten bouwplan.',fontsize=9,color=MUTED)
OUT.mkdir(parents=True,exist_ok=True)
fig.savefig(OUT/'voorstel.svg',facecolor=PAPER,metadata={'Date': None})
svg = OUT/'voorstel.svg'
svg.write_text('\n'.join(line.rstrip() for line in svg.read_text().splitlines()) + '\n')
fig.savefig(OUT/'voorstel.png',dpi=140,facecolor=PAPER)
plt.close(fig)
