"""Probe earlier passing when the immediate wheel loses the field's tempo."""
import csv,statistics
from experiments import ROOT
from metrics import Recorder
s=(ROOT/'source/elimination_v2_pre_departure.py').read_text(encoding='utf-8')
old='                    options=[]'
new='''                    options=[]
                    front=min(((rs[j]['d']-r['d'],j) for j in active if j!=i and 0<rs[j]['d']-r['d']<8 and rs[j]['lane']==cur),default=(100.,-1))
                    if front[1]>=0:
                        f=rs[front[1]]
                        pace=statistics.median(rs[j]['v']/lane_metric(rs[j]['lane']) for j in active)
                        if head-f['d']>12 and f['v']/lane_metric(f['lane'])<pace-.25:
                            if cur+1<LANES:options.append(cur+1)
                            if cur>0:options.append(cur-1)'''
assert s.count(old)==1
s=s.replace(old,new)
ns={};exec(compile(s,'slow_wheel_probe','exec'),ns)
rows=[]
for seed in (25,36,17,41):
    rec=Recorder();r=ns['simulate'](seed,observe=rec);d=rec.finish()
    r.update(max_span_m=d['max_span_m'],max_ai_span_m=d['max_ai_span_m']);rows.append(r)
    print(seed,r['span_m'],r['max_span_m'],r['max_ai_span_m'],r['blocked'],flush=True)
with (ROOT/'results/slow_wheel_probe.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
