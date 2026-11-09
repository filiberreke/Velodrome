"""No speed floor: defend a real progress margin to the last rider."""
import csv,statistics
from experiments import ROOT
from metrics import Recorder
s=(ROOT/'source/elimination_v2_with_floor.py').read_text(encoding='utf-8')
start=s.index('                # Existing improved race-speed anchor')
end=s.index('                if not final and urgency>.0:',start)
s=s[:start]+s[end:]
start=s.index("                elif rank==0 and rs[0]['d']")
end=s.index('                if not final and urgency>.0:',start)
s=s[:start]+s[end:]
anchor='                    if risk>0:'
assert s.count(anchor)==1
s=s.replace(anchor,"                    margin=r['d']-rs[active[-1]]['d']\n                    risk=max(risk,clamp((2*MIN_GAP-margin)/(2*MIN_GAP),0,1))\n"+anchor)
ns={};exec(compile(s,'position_defense_probe','exec'),ns)
rows=[];laps=[]
for seed in range(17,65):
    rec=Recorder();r=ns['simulate'](seed,observe=rec);d=rec.finish()
    assert r['finished'] and r['blocked']==0
    r.update(max_span_m=d['max_span_m'],mean_ai_span_m=d['mean_ai_span_m'],max_ai_span_m=d['max_ai_span_m']);rows.append(r);laps.extend(rec.laps)
    if seed in (23,40,52,64):print(seed,{k:round(statistics.mean(r[k] for r in rows),3) for k in ('span_m','elimination_kmh','draft','mean_wprime_after_eliminations')},flush=True)
for name,data in [('position_defense_exploration.csv',rows),('position_defense_laps.csv',laps)]:
    with (ROOT/'results'/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
lookup={(r['seed'],r['lap']):r for r in laps}
pairs=[lookup[seed,odd+1]['field_mean_kmh']-lookup[seed,odd]['field_mean_kmh'] for seed in range(17,65) for odd in range(5,29,2)]
print('Positional phase contrast',statistics.mean(pairs),sum(d>0 for d in pairs),len(pairs),flush=True)
