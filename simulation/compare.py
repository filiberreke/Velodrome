#!/usr/bin/env python3
"""Paired-seed A/B tests: unchanged vs economical wheel-following sprinters."""
import argparse,csv,json,collections,statistics
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from sim_f import run
from probe_45 import EnergyProbe


def job(item):
    seed, variant = item
    n=8 if seed%2 else 12
    probe=EnergyProbe()
    res=run(seed=seed,count=n,laps=50,variant='L',final750=True,
        no_speed_cap=True,breakaway_v=True,chase_scale=1.0,
        break_follow=True,real_laps=True,lap_probe=probe,
        sprinter_wheel_economy=(variant=='improved'))
    race=res[0]
    rrows=probe.race_rows
    own=probe.own_rows
    own45={(r['role'],r['rider_id']):r for r in own}
    riders=[]
    for r in res[3]:
        role=r['role']; rid=r['id']
        # finish positions provided by simulator plus matching own-45 checkpoint
        result={'scenario':variant,'seed':seed,**r}
        checkpoint=own45.get((role,rid))
        if checkpoint:
            result.update(wprime_45_pct=checkpoint['wprime_pct'],draft_45_pct=checkpoint['draft_time_pct_so_far'],
                gap_45_m=checkpoint['gap_to_leader_m'],mean_power_45_w=checkpoint['mean_power_w_so_far'])
        riders.append(result)
    return {'scenario':variant,'seed':seed,**race},riders,[{'scenario':variant,**x} for x in rrows]

def write(path,rows):
    if not rows: return
    names=sorted(set(k for r in rows for k in r.keys()))
    with open(path,'w',newline='',encoding='utf-8') as f:
        w=csv.DictWriter(f,fieldnames=names);w.writeheader();w.writerows(rows)

def aggs(races,riders):
    result={}
    for variant in ('baseline','improved'):
        r=[x for x in races if x['scenario']==variant]
        spr=[x for x in riders if x['scenario']==variant and x['role']=='sprinter']
        def mean(field,items):
            values=[float(x[field]) for x in items if x.get(field) not in ('',None)]
            return round(statistics.mean(values),2) if values else None
        result[variant]=dict(races=len(r),
            winners=dict(collections.Counter(x['finish_winner_role'] for x in r)),
            drafting_all_pct=round(statistics.mean(float(x['mean_drafting_share']) for x in r)*100,2),
            spread_m=mean('mean_peloton_spread_m',r),
            sprinter_wprime_45_pct=mean('wprime_45_pct',spr),
            sprinter_draft_45_pct=mean('draft_45_pct',spr),
            sprinter_gap_45_m=mean('gap_45_m',spr),
            sprinter_mean_power_45_w=mean('mean_power_45_w',spr),
            sprinter_final_reserve_pct=mean('final_reserve_pct',spr),
            sprinter_drop_events=mean('drop_events',spr),
            sprinter_n=len(spr),
            sprinter_missing_45=sum('wprime_45_pct' not in x for x in spr))
    return result

def main():
    p=argparse.ArgumentParser();p.add_argument('--races',type=int,default=100)
    p.add_argument('--seed',type=int,default=1001);p.add_argument('--workers',type=int,default=4);p.add_argument('--out',default='results_comparison')
    a=p.parse_args();out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
    inputs=[(seed,variation) for seed in range(a.seed,a.seed+a.races) for variation in ('baseline','improved')]
    races=[];riders=[];checkpoints=[]
    with ProcessPoolExecutor(max_workers=a.workers) as pool:
        for ix,(race,rs,cp) in enumerate(pool.map(job,inputs,chunksize=2),1):
            races.append(race);riders.extend(rs);checkpoints.extend(cp)
            if ix%40==0:print(f'{ix}/{len(inputs)} scenarios completed',flush=True)
    write(out/'races.csv',races)
    write(out/'riders.csv',riders)
    write(out/'checkpoints.csv',checkpoints)
    result=aggs(races,riders)
    (out/'summary.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
    print(json.dumps(result,indent=2,ensure_ascii=False),flush=True)
if __name__=='__main__':main()
