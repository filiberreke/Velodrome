"""No floor: allow time to reserve a route and gain position before the cut."""
import argparse,csv,statistics
from experiments import ROOT
from metrics import Recorder
ap=argparse.ArgumentParser();ap.add_argument('--seeds',type=int,default=7);args=ap.parse_args()
s=(ROOT/'source/elimination_v2_with_floor.py').read_text(encoding='utf-8')
start=s.index('                # Existing improved race-speed anchor')
end=s.index('                if not final and urgency>.0:',start)
s=s[:start]+s[end:]
start=s.index("                elif rank==0 and rs[0]['d']")
end=s.index('                if not final and urgency>.0:',start)
s=s[:start]+s[end:]
old='return clamp((250.-(500.-head%500.))/190.,0.,1.)'
assert s.count(old)==1
s=s.replace(old,'return clamp((head%500.-200.)/100.,0.,1.)')
ns={};exec(compile(s,'anticipation_probe','exec'),ns)
rows=[];laps=[]
for seed in range(17,17+args.seeds):
    rec=Recorder();r=ns['simulate'](seed,observe=rec);d=rec.finish()
    assert r['finished'] and r['blocked']==0
    r.update(max_span_m=d['max_span_m'],mean_ai_span_m=d['mean_ai_span_m'],max_ai_span_m=d['max_ai_span_m']);rows.append(r);laps.extend(rec.laps)
lookup={(r['seed'],r['lap']):r for r in laps}
pairs=[lookup[seed,odd+1]['field_mean_kmh']-lookup[seed,odd]['field_mean_kmh'] for seed in range(17,17+args.seeds) for odd in range(5,29,2)]
print('Anticipation',args.seeds,{k:round(statistics.mean(r[k] for r in rows),3) for k in ('span_m','elimination_kmh','draft','mean_wprime_after_eliminations')},'contrast',statistics.mean(pairs),sum(d>0 for d in pairs),len(pairs),flush=True)
for name,data in [(f'anticipation_{args.seeds}_exploration.csv',rows),(f'anticipation_{args.seeds}_laps.csv',laps)]:
    with (ROOT/'results'/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(data[0]));w.writeheader();w.writerows(data)
