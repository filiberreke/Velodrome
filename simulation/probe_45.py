#!/usr/bin/env python3
"""Passive W' telemetry during 50-lap runs of existing shelter-first simulator.

Usage: python probe_45.py --races 100 --seed 1001 --workers 4 --out results
No physics or tactics are changed; uses sim_f.run(..., lap_probe=observer).
"""
import argparse
import collections
import csv
import json
import statistics
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from sim_f import run, LAP

MILESTONES=(10,20,30,40,45)

class EnergyProbe:
    def __init__(self):
        self.race_rows=[]
        self.own_rows=[]
        self.done_race=set()
        self.done_own=set()

    def record(self, seed, time_s, rider, milestone, observation, leader):
        return {
            'seed':seed,'time_s':round(time_s,2), 'checkpoint_laps':milestone,
            'observation':observation,'rider_id':rider.id,'role':rider.role,
            'actual_laps':round(rider.d/LAP,3),
            'gap_to_leader_m':round(leader-rider.d,2),
            'wprime_kj':round(rider.phys.w/1000,3),
            'wprime_max_kj':round(rider.phys.wmax/1000,3),
            'wprime_pct':round(100*rider.phys.w/max(1,rider.phys.wmax),2),
            'fatigue_pct':round(100*rider.phys.fatigue,2),
            'cp_w':round(rider.phys.cp,2),
            'speed_kmh':round(rider.v*3.6,2),
            'mode':rider.mode,
            'draft_time_pct_so_far':round(100*rider.draft_s/max(1,rider.draft_elapsed_s),2),
            'mean_power_w_so_far':round(rider.power_sum/max(time_s,1),2),
            'dropped_before':rider.dropped_events>0,
        }

    def observe(self, t, riders, seed):
        mid=statistics.median(r.d for r in riders)
        leader=max(r.d for r in riders)
        for milestone in MILESTONES:
            if milestone not in self.done_race and mid>=milestone*LAP:
                self.done_race.add(milestone)
                for rider in riders:
                    self.race_rows.append(self.record(seed,t,rider,milestone,'peloton_median',leader))
        for rider in riders:
            if rider.id not in self.done_own and rider.d>=45*LAP:
                self.done_own.add(rider.id)
                self.own_rows.append(self.record(seed,t,rider,45,'individual_crossing',leader))

def job(seed):
    n=8 if seed%2 else 12
    probe=EnergyProbe()
    row,_,_,riders,_,_,_,_=run(seed=seed,count=n,laps=50,variant='L',final750=True,
        no_speed_cap=True,breakaway_v=True,chase_scale=1.0,
        break_follow=True,real_laps=True,lap_probe=probe)
    return row, probe.race_rows, probe.own_rows, riders

def save_csv(path, rows):
    if not rows: return
    with open(path,'w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]))
        writer.writeheader();writer.writerows(rows)

def stats(rows):
    if not rows: return {}
    pcts=[r['wprime_pct'] for r in rows]
    fatigue=[r['fatigue_pct'] for r in rows]
    gaps=[r['gap_to_leader_m'] for r in rows]
    speeds=[r['speed_kmh'] for r in rows]
    return dict(n=len(rows),mean_wprime_pct=round(statistics.mean(pcts),2),
        median_wprime_pct=round(statistics.median(pcts),2),
        mean_wprime_kj=round(statistics.mean(r['wprime_kj'] for r in rows),2),
        mean_wprime_max_kj=round(statistics.mean(r['wprime_max_kj'] for r in rows),2),
        p10_wprime_pct=round(sorted(pcts)[int(.10*(len(pcts)-1))],2),
        pct_below_5=round(100*sum(x<5 for x in pcts)/len(rows),1),
        pct_below_15=round(100*sum(x<15 for x in pcts)/len(rows),1),
        pct_below_25=round(100*sum(x<25 for x in pcts)/len(rows),1),
        mean_fatigue_pct=round(statistics.mean(fatigue),2),
        median_gap_to_leader_m=round(statistics.median(gaps),2),
        pct_more_than_20m_back=round(100*sum(x>20 for x in gaps)/len(rows),1),
        mean_speed_kmh=round(statistics.mean(speeds),2),
        pct_dropped_prior=round(100*sum(r['dropped_before'] for r in rows)/len(rows),1),
        mean_draft_pct=round(statistics.mean(r['draft_time_pct_so_far'] for r in rows),2),
        mean_power_w=round(statistics.mean(r['mean_power_w_so_far'] for r in rows),2))

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--races',type=int,default=100)
    p.add_argument('--seed',type=int,default=1001)
    p.add_argument('--workers',type=int,default=4)
    p.add_argument('--out',default='results')
    args=p.parse_args()
    out=Path(args.out);out.mkdir(parents=True,exist_ok=True)
    race_rows=[];own_rows=[];finishes=[]; races=[]
    with ProcessPoolExecutor(max_workers=args.workers) as pool:
        for i,(race,rrows,orows,frows) in enumerate(pool.map(job,range(args.seed,args.seed+args.races),chunksize=2),1):
            races.append(race);race_rows.extend(rrows);own_rows.extend(orows);finishes.extend(frows)
            if i%20==0:print(f'Races completed {i}/{args.races}',flush=True)
    save_csv(out/'energie_per_renner_checkpoints.csv',race_rows)
    save_csv(out/'energie_per_renner_eigen_45_ronden.csv',own_rows)
    save_csv(out/'finish_per_renner.csv',finishes)
    summary=[]
    for m in MILESTONES:
        for role in ('tt','sprinter','attacker'):
            rows=[r for r in race_rows if r['checkpoint_laps']==m and r['role']==role]
            summary.append({'checkpoint_laps':m,'type':role,'observation':'peloton_median',**stats(rows)})
    save_csv(out/'energie_per_type_tijdens_koers.csv',summary)
    own_summary=[]
    for role in ('tt','sprinter','attacker'):
        own_summary.append({'checkpoint_laps':45,'type':role,'observation':'individual_crossing',**stats([r for r in own_rows if r['role']==role])})
    save_csv(out/'energie_per_type_eigen_45_ronden.csv',own_summary)
    finish_stats=[]
    for role in ('tt','sprinter','attacker'):
        rows=[r for r in finishes if r['role']==role]
        finish_stats.append({'type':role,'n':len(rows),'mean_final_reserve_pct':round(statistics.mean(float(r['final_reserve_pct']) for r in rows),2),
          'pct_final_under_5':round(100*sum(float(r['final_reserve_pct'])<5 for r in rows)/len(rows),1),
          'mean_cp_w':round(statistics.mean(float(r['critical_power_w']) for r in rows),1),
          'mean_finish_fatigue_pct':round(statistics.mean(float(r['end_fatigue_pct']) for r in rows),2)})
    save_csv(out/'energie_per_type_finish.csv',finish_stats)
    wins=collections.Counter(r['finish_winner_role'] for r in races)
    baseline={'races':len(races),'ai_wins':dict(wins),'draft_pct':round(statistics.mean(r['mean_drafting_share'] for r in races)*100,2),
       'peloton_spread_m':round(statistics.mean(r['mean_peloton_spread_m'] for r in races),2)}
    result={'baseline_check':baseline,'checkpoints':summary,'own_lap_45':own_summary,'finish':finish_stats,
       'method':'Wprime measured with passive lap_probe; same 100 seeds as prior 50-lap experiments, original physics and AI code unmodified.'}
    (out/'summary.json').write_text(json.dumps(result,indent=2,ensure_ascii=False),encoding='utf-8')
    print('BASELINE',json.dumps(baseline),flush=True)
    print('PEL 45',json.dumps([r for r in summary if r['checkpoint_laps']==45]),flush=True)
    print('OWN 45',json.dumps(own_summary),flush=True)
    print('FINISH',json.dumps(finish_stats),flush=True)
if __name__=='__main__':main()
