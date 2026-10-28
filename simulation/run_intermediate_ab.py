"""Run paired 100-race A/B experiment; never changes energy_core source."""
import argparse
import csv
import hashlib
import json
import platform
import statistics
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from energy_core import PARS
from sim_f import run

ROOT=Path(__file__).resolve().parent
BASE='edab6a112df472ec301603bf56919c827dde0355'
CP={'tt':265.,'sprinter':240.,'attacker':250.}


def configure():
    for role,cp in CP.items(): PARS[role]=(cp,*PARS[role][1:])


def race(task):
    seed,variant=task
    configure()
    return run(seed,16,40,race_mode='points',variant='L',no_speed_cap=True,
               breakaway_v=True,real_laps=True,sprinter_wheel_economy=True,points_experiment=variant)


def write_csv(path,rows):
    rows=list(rows)
    with path.open('w',newline='',encoding='utf-8') as f:
        if rows:
            writer=csv.DictWriter(f,fieldnames=list(rows[0]))
            writer.writeheader(); writer.writerows(rows)
        else: f.write('seed,variant\n')


def audit(r):
    errors=[]
    if [s['lap'] for s in r['sprints']] != [10,20,30,40]: errors.append('schedule')
    for s in r['sprints']:
        if len(s['order'])!=16 or len(set(s['order']))!=16: errors.append('duplicate/missing crossing')
        if sorted(s['crossing_times'])!=s['crossing_times']: errors.append('time order')
        if not s['ties'] and sum(s['awards'])!=(22 if s['lap']==40 else 11): errors.append('sprint awards')
    expected=sum(sum(s['awards']) for s in r['sprints'])+20*sum(e['delta'] for e in r['lap_events'])
    if sum(x['points'] for x in r['riders'])!=expected: errors.append('point conservation')
    if any(e['time_s']>r['finish_time_s'] for e in r['lap_events']): errors.append('late lap event')
    if len(r['energy35'])!=16 or len(r['energy'])!=64 or len(r['energy_crossing'])!=64: errors.append('energy coverage')
    for x in r['energy']+r['energy35']+r['energy_crossing']:
        if not 0<=x['w_pct']<=100.0000001: errors.append('W range')
    # Quantify cases requiring a real bell-frozen jury review. These are
    # suspected rule divergences, not confirmed incorrect awards.
    bell_changes=0
    for s in r['sprints']:
        bell=r['bells'].get(s['lap'])
        if bell and any(bell['time_s']<e['time_s']<=s['time_s'] for e in r['lap_events']): bell_changes+=1
    return dict(seed=r['seed'],variant=r['variant'],invariant_errors=';'.join(errors),
                bell_to_sprint_lap_change_sprints=bell_changes,exact_ties=sum(s['ties'] for s in r['sprints']))


def summarize(results):
    rows=[]
    for variant in ('A','B'):
        races=[r for r in results if r['variant']==variant]
        for role in CP:
            riders=[x for r in races for x in r['riders'] if x['role']==role]
            energy35=[x for r in races for x in r['energy35'] if x['role']==role]
            row=dict(variant=variant,role=role,races=len(races),rider_observations=len(riders),
                race_wins=sum(r['winner_role']==role for r in races),
                sprint_wins=sum(x['sprint_wins'] for x in riders),sprint_points=sum(x['sprint_points'] for x in riders),
                lap_gains=sum(x['gains'] for x in riders),lap_losses=sum(x['losses'] for x in riders),
                mean_w35_j=statistics.mean(x['w_j'] for x in energy35),
                mean_w35_pct=statistics.mean(x['w_pct'] for x in energy35),
                low_before35_riders=sum(x['low_before35_s']>0 for x in riders),
                empty_before35_riders=sum(x['empty_before35_s']>0 for x in riders),
                low_before35_seconds=sum(x['low_before35_s'] for x in riders),
                aborts=sum(x['aborts'] for x in riders))
            for lap in (10,20,30,40):
                samples=[x for r in races for x in r['energy'] if x['role']==role and x['lap']==lap]
                row[f'mean_w_after{lap}_j']=statistics.mean(x['w_j'] for x in samples)
                row[f'mean_w_after{lap}_pct']=statistics.mean(x['w_pct'] for x in samples)
                row[f'sprint{lap}_wins']=sum(next(x['role'] for x in r['riders'] if x['id']==s['order'][0])==role for r in races for s in r['sprints'] if s['lap']==lap)
            rows.append(row)
    return rows


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--races',type=int,default=100); p.add_argument('--seed',type=int,default=1001)
    p.add_argument('--workers',type=int,default=4); p.add_argument('--out',type=Path,default=ROOT/'results_intermediate_ab')
    a=p.parse_args()
    if a.races<1 or a.workers<1: p.error('positive races/workers required')
    tasks=[(seed,v) for seed in range(a.seed,a.seed+a.races) for v in ('A','B')]
    if a.workers==1: results=list(map(race,tasks))
    else:
        with ProcessPoolExecutor(a.workers) as pool:
            results=[]
            for r in pool.map(race,tasks):
                results.append(r)
                if len(results)%20==0: print(f'{len(results)}/{len(tasks)} races complete',flush=True)
    for seed in range(a.seed,a.seed+a.races):
        pair=[r for r in results if r['seed']==seed]
        assert pair[0]['initial']==pair[1]['initial'], 'unpaired initial states'
    audits=[audit(r) for r in results]
    assert not any(x['invariant_errors'] for x in audits),audits
    a.out.mkdir(parents=True,exist_ok=True)
    summary=summarize(results)
    write_csv(a.out/'profiles.csv',summary)
    write_csv(a.out/'audit.csv',audits)
    for key in ('riders','initial','energy','energy35','energy_crossing','lap_events','decisions'):
        write_csv(a.out/f'{key}.csv',(dict(seed=r['seed'],variant=r['variant'],**x) for r in results for x in r[key]))
    write_csv(a.out/'races.csv',(dict(seed=r['seed'],variant=r['variant'],winner_id=r['winner_id'],winner_role=r['winner_role'],finish_time_s=r['finish_time_s']) for r in results))
    write_csv(a.out/'sprints.csv',(dict(seed=r['seed'],variant=r['variant'],lap=s['lap'],rank=i+1,
        id=ident,time_s=s['crossing_times'][i],points=s['awards'][i]) for r in results for s in r['sprints'] for i,ident in enumerate(s['order'])))
    paired=[]
    for seed in range(a.seed,a.seed+a.races):
        aa,bb=[r for r in results if r['seed']==seed]
        for role in CP:
            aw=statistics.mean(x['w_pct'] for x in aa['energy35'] if x['role']==role)
            bw=statistics.mean(x['w_pct'] for x in bb['energy35'] if x['role']==role)
            paired.append(dict(seed=seed,role=role,w35_delta_pct=bw-aw,
                win_delta=int(bb['winner_role']==role)-int(aa['winner_role']==role)))
    write_csv(a.out/'paired.csv',paired)
    manifest=dict(base_commit=BASE,races_per_variant=a.races,seeds=list(range(a.seed,a.seed+a.races)),
        laps=40,track_m=250,ai_riders=16,real_laps=True,no_speed_cap=True,shared_variant='L',base_cp_w=CP,parameters={k:list(v) for k,v in PARS.items()},
        python=platform.python_version(),source_sha256={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest() for n in ('sim_f.py','energy_core.py','intermediate_sprint.py','run_intermediate_ab.py')},
        invariant_errors=0,bell_review_sprints=sum(x['bell_to_sprint_lap_change_sprints'] for x in audits),
        summary=summary)
    # PARS must reflect the same explicit CP configuration in the parent process.
    manifest['parameters']={k:[CP[k],*v[1:]] for k,v in PARS.items()}
    (a.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(summary,indent=2),flush=True)


if __name__=='__main__': main()
