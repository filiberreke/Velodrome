"""Regression: a safe 3.2m following gap must not forbid leaving that wheel."""
import csv
from experiments import ROOT
from metrics import Recorder
s=(ROOT/'source/elimination_v2_pre_departure.py').read_text(encoding='utf-8')
old="                            if gap*future<=0 or min(abs(gap),abs(future))<3.6:"
new="""                            if cur==o['lane'] and candidate!=other:
                                departure=gap+(future-gap)*(.2/1.8)
                                if gap*departure>0 and min(abs(gap),abs(departure))>=MIN_GAP:
                                    continue
                            if gap*future<=0 or min(abs(gap),abs(future))<3.6:"""
assert s.count(old)==1
s=s.replace(old,new)
ns={};exec(compile(s,'departure_probe','exec'),ns)
rows=[]
for seed in (25,36,17,41):
    rec=Recorder();r=ns['simulate'](seed,observe=rec);d=rec.finish()
    r.update(max_span_m=d['max_span_m'],max_ai_span_m=d['max_ai_span_m']);rows.append(r)
    print(seed,r['span_m'],r['max_span_m'],r['max_ai_span_m'],r['blocked'],flush=True)
with (ROOT/'results/departure_probe.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
