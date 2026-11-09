"""One-factor studies of residual gaps, based on the previously delivered fix."""
import sys,math,statistics,csv
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'baseline'))
BASE=(ROOT/'baseline/predictive_fixed.py').read_text(encoding='utf-8')

TRAFFIC='''        predicted={}; proposed={}
        # Request work only for motion that the occupied corridor allows.
        # Leaders are integrated before followers; all tactical decisions above
        # still read the same beginning-of-tick snapshot.
        lane_leaders={}
        for i in active:
            r=rs[i];v=r['v'];aero=max(.31,1-.69*drafts[i])
            metric=1.+math.pi*(r['lane']*LANE_WIDTH)/250.
            leader=lane_leaders.get(r['lane'])
            if leader is not None:
                safe_v=max(0,(proposed[leader]-MIN_GAP-r['d'])*metric/dt)
                drag=.5*1.2*.334*v*v*aero+.004*80*9.81
                safe_power=max(0,(drag+80*(safe_v-v)/dt)*max(v,2.5)/.975)
                requests[i]=min(requests[i],safe_power)
            powers[i]=phys(r,requests[i],dt)
            drive=powers[i]*.975/max(v,2.5)
            predicted[i]=max(0,v+(drive-.5*1.2*.334*v*v*aero-.004*80*9.81)/80*dt)
            proposed[i]=r['d']+predicted[i]*dt/metric
            lane_leaders[r['lane']]=i
'''

def source(name):
    s=BASE
    if 'traffic' in name:
        s=s.replace("        drafts={i:draft_strength(rs[i],rs,active) for i in active};powers={}",
                    "        drafts={i:draft_strength(rs[i],rs,active) for i in active};powers={};requests={}")
        s=s.replace('            powers[i]=phys(r,target*difficulty/80,dt)','            requests[i]=target*difficulty/80')
        start=s.index('        predicted={}; proposed={}')
        end=s.index('        by_lane=',start)
        s=s[:start]+TRAFFIC+s[end:]
    if 'pass' in name:
        s=s.replace('                options=[]', '''                options=[]
                front=min(((rs[j]['d']-r['d'],j) for j in active if j!=i and 0<rs[j]['d']-r['d']<10 and rs[j]['lane']==cur),default=(100.,-1))
                if front[1]>=0 and (r['v']>rs[front[1]]['v']+.15 or rs[front[1]]['v']<11.3):
                    if cur+1<LANES:options.append(cur+1)
                    if cur>0:options.append(cur-1)''')
    if 'metric' in name:
        s=s.replace("w['v']+clamp((gap-3.2)*.24,-.65,1.1)","w['v']*(1+math.pi*r['lane']*LANE_WIDTH/250)/(1+math.pi*w['lane']*LANE_WIDTH/250)+clamp((gap-3.2)*.24,-.65,1.1)")
    if 'feedback' in name:
        s=s.replace('road(desired_speed,aero)/.975',"(road(r['v'],aero)+80*max(r['v'],2.5)*clamp((desired_speed-r['v'])*.8,-1.5,1.5))/.975")
    if 'clock' in name:
        s=s.replace('    while clock<2400:', '    tick=0\n    while clock<2400:')
        s=s.replace('        clock+=dt','        tick+=1;clock=tick*dt')
    if 'align' in name:
        s=s.replace('                options=[]', '''                options=[]
                useful=[(rs[j]['d']-r['d']+2*abs(rs[j]['lane']-cur),j) for j in active if j!=i and 3.6<rs[j]['d']-r['d']<40]
                if useful:
                    _,j=min(useful)
                    if rs[j]['lane']!=cur:options.append(cur+(1 if rs[j]['lane']>cur else -1))''')
    if 'no_upstream' in name:
        s=s.replace('if upstream and min(upstream)>8 and gap<8:','if False:')
    if 'reach' in name:
        s=s.replace('if 1.8<gap<60 and lateral<1.35:', 'if 1.8<gap<120 and lateral<1.35:')
    if 'safe_corridor' in name:
        s=s.replace("if max(min(cur,candidate),min(o['lane'],other))-min(max(cur,candidate),max(o['lane'],other))>1:continue", 
            "if max(min(cur,candidate),min(o['lane'],other))-min(max(cur,candidate),max(o['lane'],other))>0:continue")
    if 'swept' in name:
        s=s.replace("if max(min(cur,candidate),min(o['lane'],other))-min(max(cur,candidate),max(o['lane'],other))>1:continue",
                    "if (cur-o['lane'])*(candidate-other)>0 and min(abs(cur-o['lane']),abs(candidate-other))>=1:continue")
    if 'prediction_metric' in name:
        s=s.replace("future=gap+(o['v']-r['v'])*1.8", "future=gap+(o['v']/(1+math.pi*other*LANE_WIDTH/250)-r['v']/(1+math.pi*candidate*LANE_WIDTH/250))*1.8")
    if 'cycle' in name:
        s=s.replace('urgency=clamp((250.-remaining)/190.,0.,1.) if not final',
                    'urgency=clamp((250.-(500.-head%500.))/190.,0.,1.) if not final')
    if 'no_override' in name:
        s=s.replace("            if i==0 and 35<=clock<60:target=650.\n            elif i==0 and clock>=60:target=250.", '            pass')
    return s

def load(name):
    ns={};exec(compile(source(name),'experiment_'+name,'exec'),ns)
    return ns['simulate']

def main():
    names=['v1','traffic','pass','align','metric','safe_corridor','traffic_pass','traffic_align','traffic_metric',
           'traffic_pass_safe_corridor','traffic_pass_align_safe_corridor','traffic_pass_metric_safe_corridor',
           'traffic_pass_safe_corridor_no_upstream','traffic_pass_safe_corridor_reach','traffic_no_override']
    rows=[]
    for name in names:
        fn=load(name)
        for seed in range(17,29):
            r=fn(seed);r['variant']=name;rows.append(r)
        print(name,{k:round(statistics.mean(r[k] for r in rows[-12:]),3) for k in ('span_m','draft','anticipations','blocked','elimination_kmh','mean_wprime_after_eliminations')},flush=True)
    with (ROOT/'results/exploration.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)

if __name__=='__main__':main()
