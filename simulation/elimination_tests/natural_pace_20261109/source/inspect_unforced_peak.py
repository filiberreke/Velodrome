"""Diagnose the largest remaining gap without the external power protocol."""
import json,csv
from experiments import ROOT
s=(ROOT/'source/elimination_v2.py').read_text(encoding='utf-8')
old="                if i==0 and 35<=clock<60:target=650.\n                elif i==0 and clock>=60:target=250."
assert s.count(old)==1
s=s.replace(old,'                pass')
ns={};exec(compile(s,'unforced_peak','exec'),ns)
peak={'span':0.}
def observe(seed,t,h,rs,active,before,info,drafts,powers,final,line):
    if final:return
    span=max(rs[i]['d'] for i in active)-min(rs[i]['d'] for i in active)
    if span>peak['span']:
        peak.update(span=span,time_s=t,riders=[dict(rs[i],draft=drafts[i],**info[i]) for i in active])
with (ROOT/'results/no_override_probe.csv').open(newline='') as f:
    rows=list(csv.DictReader(f))
seed=max(rows,key=lambda r:float(r['max_span_m']))['seed']
ns['simulate'](int(seed),observe=observe)
peak['seed']=int(seed)
(ROOT/'results/unforced_residual_peak.json').write_text(json.dumps(peak,indent=2),encoding='utf-8')
rs=peak['riders']
print(peak['span'],peak['time_s'],[(r['id'],round(r['d']-rs[0]['d'],2),round(r['w']),round(r['raw_request']),round(r['feasible_request']),r['wheel'],r['cap']) for r in rs],flush=True)
