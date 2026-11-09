"""Inspect the largest residual gaps without modifying a race."""
import json
from experiments import ROOT
from elimination_v2 import simulate
out={}
for seed in (25,36):
    peaks={'span':0.,'ai_span':0.}
    def observe(s,t,h,rs,active,before,info,drafts,powers,final,line):
        if final:return
        for label,ids in (('span',active),('ai_span',[i for i in active if i!=0])):
            value=max(rs[i]['d'] for i in ids)-min(rs[i]['d'] for i in ids)
            if value>peaks[label]:
                peaks[label]=value
                peaks[label+'_state']=dict(time=t,line=line,riders=[dict(rs[i],draft=drafts[i],**info[i]) for i in active])
    simulate(seed,observe=observe);out[seed]=peaks
(ROOT/'results/residual_peaks.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
for seed,p in out.items():
    for label in ('span','ai_span'):
        state=p[label+'_state'];rs=state['riders'];print(seed,label,p[label],state['time'],[(r['id'],round(r['d']-rs[0]['d'],2),r['lane'],round(r['w']),r['wheel'],round(r['v'],2)) for r in rs],flush=True)
