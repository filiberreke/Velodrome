"""Controlled breakaway probe, using lane_sim physics and policies."""
import argparse,csv,statistics
from pathlib import Path
import lane_sim

SOURCE=Path(__file__).with_name('lane_sim.py').read_text()

def simulate(seed,policy,attack_w=650,attack_start=35,attack_end=60):
    # Instrument the existing 12-lane simulation without altering its original file.
    src=SOURCE.replace("def run(seed=17,n=16,difficulty=80,policy='improved',dt=DT,player_watts=0):", "def run(seed=17,n=16,difficulty=80,policy='improved',dt=DT,player_watts=0):")
    src=src.replace("final_distance=(n-1)*500.", "final_distance=(n-1)*500.; probe=[]; peak_gap=0.; first_chase=None")
    src=src.replace("powers[i]=player_watts if player_watts>0 and i==0 else phys(r,target*difficulty/80,dt)", """\
if i==0 and attack_start<=clock<attack_end:
                target=attack_w
            elif i==0 and clock>=attack_end:
                target=250.
            if policy=='chase' and i!=0 and attack_start<=clock and len(active)>2:
                # Seek the attacker's wheel, but do not demand everyone pulls on the front.
                # Leaders close the gap; riders behind follow the faster wheel ahead.
                gap_to_attack=rs[0]['d']-r['d']
                if gap_to_attack>3.2 and gap_to_attack<90:
                    front_ai=max((rs[j]['d'] for j in active if j!=0),default=r['d'])
                    if r['d']>=front_ai-9:
                        catch_speed=max(rs[0]['v']+.45, 11.5)
                        chase_power=(road(catch_speed,aero)+80*max(r['v'],1)*clamp((catch_speed-r['v'])*.35,-1.5,1.5))/.975
                        target=max(target,min(chase_power,r['cp']+min(240,r['w']/15)))
            powers[i]=phys(r,target*difficulty/80,dt)""")
    src=src.replace("clock+=dt\n        if int", """clock+=dt
        if clock>=attack_start and clock<=attack_end+40 and int(clock*2)!=int((clock-dt)*2):
            gap=rs[0]['d']-max(rs[j]['d'] for j in active if j!=0)
            peak_gap=max(peak_gap,gap)
            followers=sum(1 for j in active if j!=0 and 2<=rs[0]['d']-rs[j]['d']<=12 and abs(rs[0]['lane']-rs[j]['lane'])*LANE_WIDTH<1.35)
            probe.append((round(clock,1),round(gap,2),followers,round(rs[0]['v']*3.6,1),round(max(rs[j]['v'] for j in active if j!=0)*3.6,1)))
        if int""")
    src=src.replace("return dict(seed=seed,finished=", "return dict(probe=probe,peak_gap=round(peak_gap,2),seed=seed,finished=")
    namespace={'__name__':'lane_sim_breakaway','attack_start':attack_start,'attack_end':attack_end,'attack_w':attack_w}
    exec(compile(src,'lane_sim.py','exec'),namespace)
    return namespace['run'](seed=seed,policy=policy)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--seeds',type=int,default=3);p.add_argument('--out',default='breakaway_results');a=p.parse_args()
    out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
    rows=[];traces=[]
    for seed in range(17,17+a.seeds):
        for policy in ('baseline','improved','chase'):
            r=simulate(seed,policy)
            t=r.pop('probe');last=t[-1] if t else (0,0,0,0,0)
            rows.append(dict(seed=seed,policy=policy,peak_gap_m=r['peak_gap'],gap_after_40s_m=last[1],max_followers=max((x[2] for x in t),default=0),mean_followers=round(statistics.mean(x[2] for x in t),2) if t else 0,finished=r['finished'],blocked=r['blocked']))
            traces.extend(dict(seed=seed,policy=policy,time_s=x[0],gap_m=x[1],followers=x[2],attacker_kmh=x[3],fastest_ai_kmh=x[4]) for x in t)
            print(rows[-1],flush=True)
    for name,data in [('summary.csv',rows),('trace.csv',traces)]:
        with (out/name).open('w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=data[0].keys());w.writeheader();w.writerows(data)
