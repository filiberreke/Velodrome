"""One-factor probe: safely leave a wheel that has lost the bunch."""
import csv,json,statistics
from experiments import ROOT
from metrics import Recorder
s=(ROOT/'source/elimination_v2_pre_departure.py').read_text(encoding='utf-8')
old='                    options=[]'
new='''                    options=[]
                    front=min(((rs[j]['d']-r['d'],j) for j in active if j!=i and 0<rs[j]['d']-r['d']<8 and rs[j]['lane']==cur),default=(100.,-1))
                    if front[1]>=0:
                        f=rs[front[1]]
                        upstream_gap=min((rs[j]['d']-f['d'] for j in active if j!=front[1] and rs[j]['d']-f['d']>.5),default=0.)
                        if upstream_gap>8:
                            if cur+1<LANES:options.append(cur+1)
                            if cur>0:options.append(cur-1)'''
assert s.count(old)==1
s=s.replace(old,new)
ns={};exec(compile(s,'detached_wheel_probe','exec'),ns)
rows=[];laps=[]
for seed in range(17,53):
    rec=Recorder();r=ns['simulate'](seed,observe=rec);d=rec.finish()
    assert r['finished'] and r['blocked']==0
    r.update(max_span_m=d['max_span_m'],mean_ai_span_m=d['mean_ai_span_m'],max_ai_span_m=d['max_ai_span_m']);rows.append(r);laps.extend(rec.laps)
    if seed in (23,40,52):print(seed,statistics.mean(r['span_m'] for r in rows),max(r['max_span_m'] for r in rows),max(r['max_ai_span_m'] for r in rows),flush=True)
for name,data in [('detached_wheel_exploration.csv',rows),('detached_wheel_laps.csv',laps)]:
    with (ROOT/'results'/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
