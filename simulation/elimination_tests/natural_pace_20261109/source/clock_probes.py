import sys,csv,statistics
from experiments import ROOT,load
from elimination_v2 import simulate
from metrics import Recorder
rows=[];laps=[]
for h in (.1,.05,.025):
    for seed in (17,23,24,25,26,27,28):
        obs=Recorder();r=simulate(seed,integration_dt=h,observe=obs);r.update(integration_dt=h,**obs.finish());r.pop('counts');r.pop('large_gap_events');rows.append(r)
        laps.extend(dict(r,integration_dt=h) for r in obs.laps)
    print(h,{k:round(statistics.mean(r[k] for r in rows[-7:]),3) for k in ('span_m','mean_ai_span_m','draft','blocked','elimination_kmh','mean_wprime_after_eliminations')},flush=True)
with (ROOT/'results/internal_step_exploration.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
with (ROOT/'results/internal_step_laps.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(laps[0]));w.writeheader();w.writerows(laps)
