#!/usr/bin/env python3
"""Standalone *reference* simulator; does NOT execute main.gd and is not yet gameplay source of truth.
Physics parameters/AI power anchors transcribed from beta 16.15.1; deterministic for reproducible balancing.
"""
import argparse, csv, math, random, statistics
from pathlib import Path

LAP=250.0
CURVE_T=[1,15,30,60,180,300,600,1200]
CURVE_P=[1100,890,600,435,390,350,310,285]
TYPES=['sprinter','time_trialist','attacker']

def tt_power(seconds):
    t=max(CURVE_T[0],min(seconds,CURVE_T[-1]))
    for i in range(1,len(CURVE_T)):
        if t <= CURVE_T[i]:
            f=(math.log(t)-math.log(CURVE_T[i-1]))/(math.log(CURVE_T[i])-math.log(CURVE_T[i-1]))
            return CURVE_P[i-1]+f*(CURVE_P[i]-CURVE_P[i-1])
    return CURVE_P[-1]

def sprinter_cruise(laps):
    frac=max(0,min((laps-1)/9,1))
    return 365+(245-365)*(frac**.6)

def speed_step(speed,power,dt,draft=0):
    force=power/max(speed,3)
    drag=.5*1.225*.32*speed**2*(1-.48*draft)
    rolling=.004*82*9.81
    accel=max(-3.5,min(3.5,(force-drag-rolling)/82))
    return max(0,min(26,speed+accel*dt))

def sprint_laps(laps):
    return list(range(5,laps,5))+[laps]

def score(points,order,final):
    rewards=(6,4,2,1) if final else (3,2,1)
    for i,r in enumerate(order[:len(rewards)]): points[r]+=rewards[i]

def simulate(laps=25,riders=8,difficulty=80,seed=1,mode='scratch',dt=.25):
    rng=random.Random(seed)
    distance=[0.]*riders; speed=[0.]*riders
    names=['PLAYER']+[f'{TYPES[(i-1)%3]}_{i}' for i in range(1,riders)]
    types=['player']+[TYPES[(i-1)%3] for i in range(1,riders)]
    forms=[1]+[rng.uniform(.95,1.05) for _ in range(1,riders)]
    reserve=[0.]+[18000 if k=='sprinter' else (30000 if k=='attacker' else 11500) for k in types[1:]]
    finished=[None]*riders; lap_records=[[] for _ in range(riders)]; last_lap_time=[0.]*riders
    point_total=[0]*riders; awarded=set(); sprint_records=[]
    times=0.; limit=max(250, laps*90); phase=0
    tt=tt_power(laps*30)*difficulty/100
    while times < limit and any(f is None for f in finished):
        previous=distance[:]
        for i in range(riders):
            if finished[i] is not None: continue
            kind=types[i]
            if kind=='player': power=305*(difficulty/80)
            elif kind=='time_trialist': power=tt*forms[i]
            elif kind=='sprinter':
                sustainable=sprinter_cruise(laps)*forms[i]; target=(860*forms[i] if laps*LAP-distance[i]<65 else sustainable)
                extra=max(0,target-sustainable); usable=min(extra,reserve[i]/dt)
                power=min((sustainable+usable)*(difficulty/80),960*forms[i]); reserve[i]-=usable*dt
            else:
                sustained=100*forms[i]; current=distance[i]
                target=(700 if current<50 else 100 if current>95 else 700-(current-50)*(600/45))*forms[i]
                extra=max(0,target-sustained); usable=min(extra,reserve[i]/dt)
                power=(sustained+usable)*(difficulty/80); reserve[i]-=usable*dt
            # Simplified pack drafting; assumes nearest cyclist in front is within 10 m.
            ahead=[distance[j]-distance[i] for j in range(riders) if j!=i and 1.2<distance[j]-distance[i]<12]
            draft=.4 if ahead else 0
            speed[i]=speed_step(speed[i],power,dt,draft)
            distance[i]=min(laps*LAP,distance[i]+speed[i]*dt)
            oldlap=int(previous[i]//LAP)
            newlap=int(distance[i]//LAP)
            for lap in range(oldlap+1,min(laps,newlap)+1):
                crossing=times+dt*(lap*LAP-previous[i])/max(1e-10,distance[i]-previous[i])
                lap_records[i].append(crossing-last_lap_time[i]); last_lap_time[i]=crossing
            if distance[i]>=laps*LAP:
                finished[i]=times+dt*(laps*LAP-previous[i])/max(1e-10,distance[i]-previous[i])
        if mode=='points':
            # For each sprint line, wait for all riders to cross; rank by interpolated crossing time.
            for lap in sprint_laps(laps):
                if lap in awarded: continue
                if all(d>=lap*LAP for d in distance):
                    cross=[]
                    for i in range(riders):
                        # reconstruct from cumulative lap split data, in exact time order
                        cross.append((sum(lap_records[i][:lap]),i))
                    order=[i for _,i in sorted(cross)]
                    score(point_total,order,lap==laps)
                    sprint_records.append({'lap':lap,'order':order,'points_awarded':[6,4,2,1] if lap==laps else [3,2,1]})
                    awarded.add(lap)
        times+=dt
    ranks=sorted(range(riders),key=lambda i: finished[i] if finished[i] is not None else 1e30)
    placements={id:i+1 for i,id in enumerate(ranks)}
    standings=sorted(range(riders),key=lambda i:(-point_total[i],placements[i])) if mode=='points' else ranks
    return {'seed':seed,'laps':laps,'riders':riders,'mode':mode,'names':names,'types':types,'forms':forms,'finish':finished,'places':placements,'points':point_total,'standings':standings,'sprints':sprint_records,'energy_left':reserve,'lap_times':lap_records,'elapsed':times}

def validate(result):
    laps=result['laps']; finish=result['finish']; ranks=result['places']
    assert all(x is not None for x in finish),'stalled rider'
    # Identical timestamps are possible in this simplified discrete model.
    assert all(len(l)==laps for l in result['lap_times']),'lap count mismatch'
    assert all(all(t>0 for t in rec) for rec in result['lap_times']),'non-positive lap split'
    assert len(ranks)==result['riders']
    if result['mode']=='points':
        assert len(result['sprints'])==len(sprint_laps(laps))
        expected=(len(sprint_laps(laps))-1)*6+13
        assert sum(result['points'])==expected,(sum(result['points']),expected)

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--races',type=int,default=100)
    ap.add_argument('--riders',type=int,default=8,choices=range(6,13),metavar='6..12')
    ap.add_argument('--laps',type=int,default=25)
    ap.add_argument('--mode',choices=['scratch','points'],default='points')
    ap.add_argument('--difficulty',type=float,default=80)
    ap.add_argument('--seed',type=int,default=42)
    ap.add_argument('--out',default='simulator/results.csv')
    args=ap.parse_args()
    path=Path(args.out); path.parent.mkdir(parents=True,exist_ok=True)
    wins={k:0 for k in ['player']+TYPES}; durations=[]
    with path.open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(['seed','mode','laps','field','rider','type','form','finish_s','place','points','anaerobic_left_j','lap_times_s'])
        for seed in range(args.seed,args.seed+args.races):
            r=simulate(args.laps,args.riders,args.difficulty,seed,args.mode)
            validate(r)
            durations.append(r['elapsed'])
            wins[r['types'][r['standings'][0]]]+=1
            for i in range(args.riders):
                w.writerow([seed,args.mode,args.laps,args.riders,r['names'][i],r['types'][i],round(r['forms'][i],4),round(r['finish'][i],3),r['places'][i],r['points'][i],round(r['energy_left'][i],1),';'.join(f'{x:.3f}' for x in r['lap_times'][i])])
    print('PASS',args.races,'races;',args.mode,args.laps,'laps;',args.riders,'riders')
    print('Winner profile counts:',wins)
    print('Mean simulated race time:',round(statistics.mean(durations),1),'seconds')
    print('CSV:',path)

if __name__=='__main__': main()
