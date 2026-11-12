"""Passive adapter for the previously delivered v1, with identical results."""
from experiments import BASE

def load():
    s=BASE.replace('def simulate(seed=17,n=16,difficulty=80,dt=DT):','def simulate(seed=17,n=16,difficulty=80,dt=DT,observe=None):')
    s=s.replace("        old={i:rs[i]['d'] for i in active}","        old={i:rs[i]['d'] for i in active}\n        before={i:dict(rs[i]) for i in active}\n        info={i:{} for i in active}")
    s=s.replace('            powers[i]=phys(r,target*difficulty/80,dt)',
                "            info[i].update(wheel=wheel,raw_request=target*difficulty/80,feasible_request=target*difficulty/80,traffic_limited=False)\n            powers[i]=phys(r,target*difficulty/80,dt)")
    s=s.replace("            proposed[i]=r['d']+predicted[i]*dt/metric", "            proposed[i]=r['d']+predicted[i]*dt/metric\n            info[i].update(safety_leader=-1,cap=False)")
    s=s.replace('                limit=proposed[lead]-MIN_GAP',"                info[follow]['safety_leader']=lead\n                limit=proposed[lead]-MIN_GAP")
    s=s.replace('                    anticipations+=1',"                    anticipations+=1\n                    info[follow]['cap']=True")
    s=s.replace('        clock+=dt','        if observe is not None:observe(seed,clock,dt,rs,active,before,info,drafts,powers,final,line)\n        clock+=dt')
    ns={};exec(compile(s,'baseline_v1_logged','exec'),ns)
    return ns['simulate']
