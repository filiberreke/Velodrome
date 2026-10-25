#!/usr/bin/env python3
"""Research-inspired game prototype, NOT a validated physiology or W'bal predictor."""
import csv, math, random, statistics, json, argparse
from pathlib import Path

PARS={'tt':(270.86,24120.4,856.79),'sprinter':(235.00,30638.,1661.88),'attacker':(250.00,32658.4,1149.1)}
# ANCHORS are historical input measurements, not the newly recalibrated profile.
# The revised attacker CP is intentionally an exploratory gameplay balance change.
ANCHORS={'tt':[(5,800),(30,600),(120,420),(300,350),(600,310),(1200,285)],'sprinter':[(5,1350),(30,850),(120,390),(300,285),(600,245),(1200,220)],'attacker':[(5,1050),(30,700),(120,450),(300,320),(600,275),(1200,250)]}

def pcurve(t,cp,w,pmax):return cp+w/(max(t,0)+w/(pmax-cp))

def speed(p, draft=False):
    # Identical track resistance for all profiles. Simplified constant CdA, rolling drag.
    # Effective shelter lowers required power for equal speed (not a speed multiplier).
    eff=.82 if draft else 1.
    return 11*(max(1.,p)/300/eff)**(1/3)

class Phys:
    def __init__(self,role,form=1.,fatigue_coeff=.10):
        c,w,m=PARS[role];self.role=role;self.cp=c*form;self.wmax=w*form;self.pmax=m*form
        self.w=self.wmax;self.fatigue=0.;self.fatigue_coeff=fatigue_coeff;self.work_above=0.;self.recovered=0.;self.t=0.
    def step(self,demand,dt=1.,draft=False):
        # W' is drained linearly by work above CP; nonlinear recovery below CP.
        # Fatigue is an exploratory *additional* slow-state coupling, not asserted physiology.
        cp_now=self.cp*(1-self.fatigue_coeff*self.fatigue)
        instantaneous_ceiling=self.pmax*(1-.25*self.fatigue)
        demand=min(demand,instantaneous_ceiling)
        if demand>cp_now:
            use=min(self.w,(demand-cp_now)*dt)
            actual=cp_now+use/dt
            self.w-=use;self.work_above+=use
            self.fatigue=min(1.,self.fatigue+use/self.wmax*.10)
        else:
            actual=demand
            # recovery time constant is context dependent, intentionally conservative
            deficit=max(0.,self.wmax-self.w)
            recovery=deficit*(1-math.exp(-dt/(180.+600.*(actual/max(cp_now,1))**3)))
            self.w+=recovery;self.recovered+=recovery
            self.fatigue=max(0.,self.fatigue-dt/1800.*max(0,1-actual/max(cp_now,1)))
        self.t+=dt
        return actual

def pursuit(role,distance=3000.,form=1.,fatigue_coeff=.10):
    # Flat pace: choose the highest sustainable wattage which does not demand more W' than available by the finish.
    # Separate finite-peak power-duration curve restricts the fresh effort; W' is not added twice.
    cp,w,pmax=[v*form for v in PARS[role]]
    lo,hi=cp,700.
    def duration(power):return distance/speed(power)
    for _ in range(65):
        mid=(lo+hi)/2; dur=duration(mid)
        allowable=min(pcurve(dur,cp,w,pmax),cp+w/dur)
        if mid<=allowable:lo=mid
        else:hi=mid
    pace=lo;phy=Phys(role,form,fatigue_coeff)
    dist=0.;elapsed=0.;actuals=[]
    while dist<distance and elapsed<1000:
        power=phy.step(pace);v=speed(power)
        dstep=min(1.,(distance-dist)/v)
        dist+=v*dstep;elapsed+=dstep;actuals.append(power)
    return dict(role=role,pace_target_w=round(pace,2),time_s=round(elapsed,2),final_w_pct=round(100*phy.w/phy.wmax,2),final_fatigue_pct=round(100*phy.fatigue,2),mean_actual_w=round(statistics.mean(actuals),2))

def intervals(role,kind,form=1.,fatigue_coeff=.10):
    ph=Phys(role,form,fatigue_coeff);rows=[];d=0.
    # Five 12s attacks, with 90s in the wheel; vs one reckless 45s move.
    if kind=='short':phases=[('attack',12,.67),('wheel',90,.66)]*5
    elif kind=='reckless':phases=[('attack',45,.75),('wheel',120,.80)]
    else:phases=[('cruise',300,.95)]
    for label,secs,factor in phases:
        start_w=ph.w;start_f=ph.fatigue;power=[]
        for _ in range(secs):
            target=ph.cp+factor*(ph.pmax-ph.cp) if label=='attack' else factor*ph.cp
            actual=ph.step(target);d+=speed(actual,label=='wheel');power.append(actual)
        rows.append(dict(role=role,scenario=kind,phase=label,seconds=secs,avg_w=round(statistics.mean(power),1),w_before_pct=round(start_w/ph.wmax*100,1),w_after_pct=round(ph.w/ph.wmax*100,1),fatigue_after_pct=round(ph.fatigue*100,1),distance_m=round(d,1)))
    return rows

def drop_test(role,attack_s,form=1.,fatigue_coeff=.10):
    ph=Phys(role,form,fatigue_coeff);distance_gap=0.;peak_gap=0.;dropped_seconds=0
    # Opponent group 11.2 m/s; 18% shelter once the wheel is within 7m.
    # Very high attack target: repeated >CP attempts exhaust W' rapidly.
    for _ in range(attack_s):ph.step(ph.cp+.72*(ph.pmax-ph.cp))
    reserve_at_end=ph.w/ph.wmax*100
    for _ in range(120):
        sheltered=distance_gap<7
        follow_target=300 if sheltered else 370
        actual=ph.step(follow_target)
        distance_gap=max(0.,distance_gap+11.2-speed(actual,sheltered))
        peak_gap=max(peak_gap,distance_gap)
        if distance_gap>20:dropped_seconds+=1
    return dict(role=role,attack_s=attack_s,reserve_post_attack_pct=round(reserve_at_end,1),gap_after_120s_m=round(distance_gap,1),max_gap_m=round(peak_gap,1),seconds_over_20m=round(dropped_seconds,0),dropped=dropped_seconds>=20)

def write(path,rows):
    with open(path,'w',newline='') as f:
        wr=csv.DictWriter(f,fieldnames=rows[0]);wr.writeheader();wr.writerows(rows)

def main():
    a=argparse.ArgumentParser();a.add_argument('--out',default='results');a.add_argument('--events',type=int,default=500);a.add_argument('--seed',type=int,default=20261022);args=a.parse_args()
    out=Path(args.out);out.mkdir(exist_ok=True,parents=True)
    curves=[dict(role=role,seconds=t,anchor_w=p,model_w=round(pcurve(t,*PARS[role]),1)) for role,points in ANCHORS.items() for t,p in points]
    write(out/'curve_check.csv',curves)
    trials=[];wins=[];rng=random.Random(args.seed)
    for event in range(args.events):
        pack=[]
        for role in PARS:
            for i in range(3):
                form=rng.uniform(.95,1.05)
                r=pursuit(role,form=form);r.update(event=event,rider=f'{role}_{i}',form=round(form,4));pack.append(r)
        pack.sort(key=lambda x:x['time_s']);wins.append(dict(event=event,winner_role=pack[0]['role'],winning_s=pack[0]['time_s']))
        trials+=pack
    write(out/'pursuit_results.csv',trials);write(out/'pursuit_winners.csv',wins)
    intervals_rows=[r for role in PARS for kind in ['short','reckless'] for r in intervals(role,kind)]
    write(out/'intervals.csv',intervals_rows)
    drop_rows=[drop_test(role,secs) for role in PARS for secs in [12,25,45]]
    write(out/'drop_tests.csv',drop_rows)
    summary=dict(pursuit_wins={role:sum(w['winner_role']==role for w in wins) for role in PARS},mean_pursuit_s={role:round(statistics.mean(r['time_s'] for r in trials if r['role']==role),1) for role in PARS},pursuit_finish_W_pct={role:round(statistics.mean(r['final_w_pct'] for r in trials if r['role']==role),1) for role in PARS},drop_tests=drop_rows)
    (out/'summary.json').write_text(json.dumps(summary,indent=2));print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
