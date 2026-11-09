"""Test genuine recovery between eliminations without suppressing gap closing."""
import csv,statistics
from experiments import ROOT
from metrics import Recorder
s=(ROOT/'source/elimination_v2_pre_recovery.py').read_text(encoding='utf-8')
old='                if clock>14:'
assert s.count(old)==1
s=s.replace(old,"                if clock>14 and (final or urgency>0 or not (head-r['d']<8 or (wheel>=0 and gap<8 and sheltered))):")
ns={};exec(compile(s,'recovery_probe','exec'),ns)
rows=[];laps=[]
for seed in range(17,41):
    rec=Recorder();r=ns['simulate'](seed,observe=rec);summary=rec.finish()
    assert r['finished'] and r['blocked']==0
    r.update(mean_ai_span_m=summary['mean_ai_span_m'],max_span_m=summary['max_span_m']);rows.append(r);laps.extend(rec.laps)
    if seed in (23,28,40):print(seed,statistics.mean(r['span_m'] for r in rows),flush=True)
for name,data in [('recovery_exploration.csv',rows),('recovery_laps.csv',laps)]:
    with (ROOT/'results'/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
lookup={(r['seed'],r['lap']):r for r in laps}
pairs=[lookup[s,l+1]['field_mean_kmh']-lookup[s,l]['field_mean_kmh'] for s in range(17,41) for l in range(5,29,2)]
print('Recovery',statistics.mean(r['span_m'] for r in rows),statistics.mean(pairs),sum(d>0 for d in pairs),flush=True)
