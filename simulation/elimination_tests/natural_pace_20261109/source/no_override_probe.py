"""Causal diagnostic only; shipped v2 keeps the imposed 650/250 W rider."""
import csv,statistics
from experiments import ROOT
from metrics import Recorder
s=(ROOT/'source/elimination_v2.py').read_text(encoding='utf-8')
old="                if i==0 and 35<=clock<60:target=650.\n                elif i==0 and clock>=60:target=250."
assert s.count(old)==1
s=s.replace(old,'                pass # diagnostic: remove externally imposed power protocol')
ns={};exec(compile(s,'v2_without_external_override','exec'),ns)
rows=[]
for seed in range(17,41):
    obs=Recorder();r=ns['simulate'](seed,observe=obs);d=obs.finish()
    assert r['finished'] and r['blocked']==0
    r.update(max_span_m=d['max_span_m'],mean_ai_span_m=d['mean_ai_span_m']);rows.append(r)
with (ROOT/'results/no_override_probe.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
print('Without external override',statistics.mean(r['span_m'] for r in rows),max(r['max_span_m'] for r in rows),flush=True)
