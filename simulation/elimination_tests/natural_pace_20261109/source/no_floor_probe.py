"""User-requested causal probe: speed emerges from wheels, power and position."""
import csv,statistics
from experiments import ROOT
from metrics import Recorder
s=(ROOT/'source/elimination_v2_with_floor.py').read_text(encoding='utf-8')
start=s.index('                # Existing improved race-speed anchor')
end=s.index('                if not final and urgency>.0:',start)
s=s[:start]+'                # No minimum-speed demand: wheel following and position only.\n'+s[end:]
# This legacy special case is unreachable for an active race leader. Remove it
# as well so no hidden 11.5m/s floor remains in the natural-pace variant.
start=s.index("                elif rank==0 and rs[0]['d']")
end=s.index('                # No minimum-speed demand',start)
s=s[:start]+s[end:]
ns={};exec(compile(s,'no_floor_probe','exec'),ns)
rows=[];laps=[];diags={}
for seed in range(17,65):
    rec=Recorder();r=ns['simulate'](seed,observe=rec);d=rec.finish()
    assert r['finished'] and r['blocked']==0
    r.update(mean_ai_span_m=d['mean_ai_span_m'],max_span_m=d['max_span_m'],max_ai_span_m=d['max_ai_span_m']);rows.append(r);laps.extend(rec.laps);diags[seed]=d
    if seed in (23,40,52,64):
        print(seed,{k:round(statistics.mean(r[k] for r in rows),3) for k in ('span_m','elimination_kmh','draft','mean_wprime_after_eliminations')},flush=True)
for name,data in [('no_floor_exploration.csv',rows),('no_floor_laps.csv',laps)]:
    with (ROOT/'results'/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
lookup={(r['seed'],r['lap']):r for r in laps}
pairs=[lookup[seed,odd+1]['field_mean_kmh']-lookup[seed,odd]['field_mean_kmh'] for seed in range(17,65) for odd in range(5,29,2)]
print('Natural phase contrast',statistics.mean(pairs),sum(d>0 for d in pairs),len(pairs),flush=True)
