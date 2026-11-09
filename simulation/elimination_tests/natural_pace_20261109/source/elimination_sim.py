#!/usr/bin/env python3
"""Standalone elimination AI diagnostic. Port of main elimination_ai.gd power policy.
NOT pixel/physics parity with Godot: approximates drafting, lanes and track banking.
"""
import argparse, csv, json, math, random, statistics
from pathlib import Path
CP=(265.,240.,250.); WMAX=(24120.4,30638.,32658.4); PMAX=(856.79,1661.88,1149.10)
DT=.2

def clamp(x,a,b): return max(a,min(b,x))
def road(v,a): return .5*1.2*.334*a*v**3+.004*80*9.81*v
def phys(r,target,dt):
    cp=r['cp']*(1-.10*r['fatigue']); ceiling=r['pmax']*(1-.25*r['fatigue']); demand=clamp(target,0,ceiling)
    if demand>cp:
        use=min(r['w'],(demand-cp)*dt); actual=cp+use/dt; r['w']-=use; r['fatigue']=min(1,r['fatigue']+use/r['wmax']*.1)
    else:
        actual=demand; ratio=actual/max(cp,1); tau=180+600*ratio**3
        r['w']=min(r['wmax'],r['w']+(r['wmax']-r['w'])*(1-math.exp(-dt/tau)))
        r['fatigue']=max(0,r['fatigue']-dt/1800*max(0,1-ratio))
    return actual

def run(seed=1,n=16,difficulty=80,player_watts=0,dt=DT):
    rng=random.Random(seed); riders=[]
    for i in range(n):
        k=i%3; form=rng.uniform(.94,1.06); riders.append(dict(id=i,kind=k,cp=CP[k]*form,wmax=WMAX[k]*form,pmax=PMAX[k]*form,w=WMAX[k]*form,fatigue=0.,d=0.,v=0.,power=0.,active=True))
    # All AI by default; optional controlled rider 0 to study response to a human.
    active=list(range(n)); line=500.; clock=0.; eliminations=[]; samples=[]; snapshots=[]
    while len(active)>2 and clock<2400:
        active.sort(key=lambda i:riders[i]['d'],reverse=True)
        middle=riders[active[len(active)//2]]['d']; head=riders[active[0]]['d']; danger=min(3,max(1,len(active)//4))
        old=[r['d'] for r in riders]; powers={}; drafts={}
        for rank,i in enumerate(active):
            r=riders[i]; ahead=[(riders[j]['d']-r['d'],j) for j in active if j!=i and .1<riders[j]['d']-r['d']<70]
            wheel=min(ahead,default=(70.,-1)); gap,j=wheel
            draft=clamp((12-gap)/10,0,1) if j>=0 and gap<12 else 0.
            drafts[i]=draft; sheltered=draft>.12
            risk=clamp(((rank+1)-(len(active)-danger))/danger,0,1)
            jury_remaining=max(0,line-head)
            remaining=max(0,line-r['d'])
            positioning=risk>0 and remaining>0 and jury_remaining<110
            imminent=clamp((110-jury_remaining)/85,0,1)*risk
            target=r['cp']*(.76 if sheltered else .92)
            aero=max(.31,1-.69*draft)
            if j>=0:
                wanted=max(0,riders[j]['v']+clamp((gap-3.2)*.28,-1,1.2))
                target=clamp(road(wanted,aero)/.975,0,r['cp']+min(130,r['w']/22))
            if not positioning and clock>=14 and r['d']-middle>8:
                target=min(target,road(max(5,riders[active[len(active)//2]]['v']-1),aero)/.975)
            if positioning:
                seconds=max(6,remaining/max(r['v'],7))
                kick=r['cp']+r['w']/(seconds+r['w']/max(1,r['pmax']-r['cp']))
                target=max(target,target+(kick*.99-target)*imminent)
                safe=riders[active[len(active)-danger-1]]
                survival=safe['v']+.8
                limit=(road(survival,aero)+80*max(r['v'],1)*(survival-r['v'])*.6)/.975
                target=min(target,max(0,limit))
            if r['w']/r['wmax']<.14 and rank+1<=max(2,len(active)-3): target=min(target,r['cp']*1.04)
            if clock<14 and r['v']<11 and r['d']<170:
                wt=clamp((14-clock)/7,0,1)*clamp((11-r['v'])/3,0,1)
                launch=min(450,max(350,r['cp']*1.65))
                target=max(target,(1-wt)*r['cp']*(.76 if sheltered else .91)+wt*launch)
            if player_watts>0 and i==0: target=player_watts
            powers[i]=phys(r,target*difficulty/80,dt) if not(player_watts>0 and i==0) else player_watts
        for i in active:
            r=riders[i]; v=r['v']; aero=max(.31,1-.69*drafts[i]); drive=powers[i]*.975/max(v,2.5)
            accel=(drive-.5*1.2*.334*v*v*aero-.004*80*9.81)/80
            r['v']=max(0,v+accel*dt); r['d']+=r['v']*dt; r['power']=powers[i]
        clock+=dt
        if int((clock-dt)*2)!=int(clock*2):
            samples.append((clock,statistics.mean(riders[i]['v']*3.6 for i in active),max(riders[i]['d'] for i in active)-min(riders[i]['d'] for i in active)))
        if head<line and max(riders[i]['d'] for i in active)>=line-250 and not snapshots or (snapshots and snapshots[-1]['line']!=line and max(riders[i]['d'] for i in active)>=line-250):
            snapshots.append(dict(line=line,at_250m=[i for i in active],speed_kmh=round(statistics.mean(riders[i]['v']*3.6 for i in active),2)))
        if min(riders[i]['d'] for i in active)>=line:
            crossings=sorted(active,key=lambda i:(clock-dt+dt*clamp((line-old[i])/max(riders[i]['d']-old[i],1e-9),0,1),i))
            loser=crossings[-1]; eliminations.append(dict(line=line,loser=loser,profile=riders[loser]['kind'],time=round(clock,1)))
            riders[loser]['active']=False; active.remove(loser); line+=500
    return dict(seed=seed,finished=len(active)==2,elapsed_s=round(clock,1),mean_speed_kmh=round(statistics.mean(x[1] for x in samples),2) if samples else 0,mean_span_m=round(statistics.mean(x[2] for x in samples),2) if samples else 0,eliminations=eliminations,finalists=active,reserve_pct=[round(100*r['w']/r['wmax'],1) for r in riders],snapshots=snapshots)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--races',type=int,default=100);ap.add_argument('--riders',type=int,default=16);ap.add_argument('--difficulty',type=float,default=80);ap.add_argument('--player-watts',type=float,default=0);ap.add_argument('--seed',type=int,default=17);ap.add_argument('--out',default='elimination_results');a=ap.parse_args()
    results=[run(a.seed+i,a.riders,a.difficulty,a.player_watts) for i in range(a.races)]
    out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
    (out/'races.json').write_text(json.dumps(results,indent=2))
    with (out/'summary.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['seed','finished','elapsed_s','mean_speed_kmh','mean_span_m']);w.writeheader();w.writerows({k:r[k] for k in w.fieldnames} for r in results)
    summary={'races':len(results),'finished':sum(r['finished'] for r in results),'mean_speed_kmh':round(statistics.mean(r['mean_speed_kmh'] for r in results),2),'mean_span_m':round(statistics.mean(r['mean_span_m'] for r in results),2)}
    (out/'aggregate.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
