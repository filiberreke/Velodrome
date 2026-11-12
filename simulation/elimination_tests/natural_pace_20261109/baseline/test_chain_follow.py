"""Compare original direct-attack chase with a local wheel-to-wheel relay.

Uses the same 12-lane simulation source and 650 W attack as test_breakaway.py.
Each AI rider targets only its nearest usable wheel ahead; the leading AI
may target the attacker. Never targets the attacker's wheel from deep in bunch.
"""
import argparse,csv,statistics
from pathlib import Path
from test_breakaway import SOURCE

def simulate(seed,policy='chain',attack_w=650,attack_start=35,attack_end=60):
    src=SOURCE.replace('final_distance=(n-1)*500.', 'final_distance=(n-1)*500.; probe=[]; peak_gap=0.; direct_targets=0; relay_targets=0')
    anchor='powers[i]=player_watts if player_watts>0 and i==0 else phys(r,target*difficulty/80,dt)'
    injected='''if i==0 and attack_start<=clock<attack_end:
                target=attack_w
            elif i==0 and clock>=attack_end:
                target=250.
            if policy=='chain' and i!=0 and clock>=attack_start and len(active)>2:
                # Local following: one wheel per rider, lateral overlap required.
                # Only the leading AI can chase the attacker directly.
                # Other riders respond to the nearest rider immediately ahead.
                candidates=[]
                for j2 in active:
                    if j2==i: continue
                    g2=rs[j2]['d']-r['d']
                    lateral=abs(rs[j2]['lane']-r['lane'])*LANE_WIDTH
                    if 1.8<g2<18 and lateral<1.35:
                        candidates.append((g2,j2))
                front_ai=max((rs[j2]['d'] for j2 in active if j2!=0),default=r['d'])
                if candidates:
                    wheel_gap,wheel_id=min(candidates)
                    wheel=rs[wheel_id]
                    # Respond to acceleration through the nearest wheel, rather
                    # than racing all riders towards a single distant target.
                    closing=clamp((wheel_gap-3.4)*.22,-.4,1.0)
                    desired_speed=max(0,wheel['v']+closing)
                    if desired_speed>r['v']+.12:
                        needed=(road(desired_speed,aero)+80*max(r['v'],1)*clamp((desired_speed-r['v'])*.34,0,1.5))/.975
                        target=max(target,min(needed,r['cp']+min(220,r['w']/18)))
                        relay_targets+=1
                elif r['d']>=front_ai-1.5 and rs[0]['d']>r['d']+3.5 and rs[0]['d']-r['d']<90:
                    # Only the frontmost AI has no other AI wheel to follow.
                    desired_speed=max(rs[0]['v']+.2,11.5)
                    needed=(road(desired_speed,aero)+80*max(r['v'],1)*clamp((desired_speed-r['v'])*.34,0,1.5))/.975
                    target=max(target,min(needed,r['cp']+min(240,r['w']/15)))
                    direct_targets+=1
            '''+anchor
    src=src.replace(anchor,injected)
    src=src.replace('clock+=dt\n        if int', '''clock+=dt
        if attack_start<=clock<=attack_end+40 and int(clock*2)!=int((clock-dt)*2):
            gap=rs[0]['d']-max(rs[j]['d'] for j in active if j!=0)
            peak_gap=max(peak_gap,gap)
            followers=sum(1 for j in active if j!=0 and 2<=rs[0]['d']-rs[j]['d']<=12 and abs(rs[0]['lane']-rs[j]['lane'])*LANE_WIDTH<1.35)
            probe.append((round(clock,1),round(gap,2),followers))
        if int''')
    src=src.replace('return dict(seed=seed,finished=', 'return dict(probe=probe,peak_gap=round(peak_gap,2),direct_targets=direct_targets,relay_targets=relay_targets,seed=seed,finished=')
    ns={'__name__':'lane_sim_chain','attack_start':attack_start,'attack_end':attack_end,'attack_w':attack_w}
    exec(compile(src,'lane_sim.py','exec'),ns)
    return ns['run'](seed=seed,policy=policy)

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--seeds',type=int,default=5);ap.add_argument('--out',default='chain_results');a=ap.parse_args()
    out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
    rows=[]
    for seed in range(17,17+a.seeds):
        for policy in ('improved','chain'):
            r=simulate(seed,policy);trace=r.pop('probe')
            row=dict(seed=seed,policy=policy,finished=r['finished'],elimination_kmh=r['elimination_kmh'],final_kmh=r['final_kmh'],span_m=r['span_m'],draft=r['draft'],blocked=r['blocked'],peak_gap_m=r['peak_gap'],mean_attack_followers=round(statistics.mean(x[2] for x in trace),2) if trace else 0,direct_targets=r['direct_targets'],relay_targets=r['relay_targets'])
            rows.append(row);print(row,flush=True)
    with (out/'races.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
    for policy in ('improved','chain'):
        subset=[r for r in rows if r['policy']==policy]
        print('SUMMARY',policy,{k:round(statistics.mean(r[k] for r in subset),2) for k in ('elimination_kmh','final_kmh','span_m','draft','blocked','peak_gap_m','mean_attack_followers')},flush=True)
