"""Points experiment and TUSSENSPRINT; physics remain in sim_f/energy_core.

Baseline demand is the current game/points_ai.gd repeated sprint demand.
The jury mirrors the game's common-clock crossing convention, including its
known lack of a bell-frozen head of race (reported by the audit, not hidden).
"""
import math
import statistics
from collections import Counter
from sim_f import LAP, pcurve, clamp, integrate_speed


def place_probabilities(own_eta, other_etas, uncertainty=1.3):
    """Independent logistic ETA uncertainty; heuristic, not calibrated odds."""
    distribution = [1.0]
    for eta in other_etas:
        p = 1 / (1 + math.exp(clamp((eta-own_eta)/uncertainty, -40, 40)))
        updated = [0.] * (len(distribution)+1)
        for n, chance in enumerate(distribution):
            updated[n] += chance*(1-p)
            updated[n+1] += chance*p
        distribution = updated
    return (distribution+[0.]*4)[:4]


def sprint_power(r, distance):
    seconds=max(5., distance/max(r.v,5.))
    effort=pcurve(seconds,r.phys.cp,r.phys.wmax,r.phys.pmax)
    effort *= {'tt':.75,'attacker':.87,'sprinter':.99}[r.role]
    return min(effort,r.phys.cp+.88*r.store/max(6.,seconds))


class Experiment:
    def __init__(self,riders,laps,variant):
        if variant not in ('A','B') or laps != 40:
            raise ValueError('experiment requires A/B and 40 laps')
        self.tactical=variant=='B'; self.variant=variant; self.laps=laps
        self.schedule=[10,20,30,40]
        self.points={r.id:0 for r in riders}
        self.net=dict.fromkeys(self.points,0)
        self.gains=dict.fromkeys(self.points,0); self.losses=dict.fromkeys(self.points,0)
        self.sprints=[]; self.lap_events=[]; self.energy=[]; self.energy35=[]; self.energy_crossing=[]
        self.finish_time=None; self.main_ids=set(); self.bells={}
        self.decisions=[]; self.counts=Counter(); self.active=set()
        self.exhaustion={r.id:dict(first_low_time_s=None,low_before35_s=0.,empty_before35_s=0.) for r in riders}
        self.initial=[dict(id=r.id,role=r.role,cp_w=r.phys.cp,wmax_j=r.store_max,
                           pmax_w=r.phys.pmax,d_m=r.d,lane=r.lane) for r in riders]

    @property
    def next_lap(self):
        return next((n for n in self.schedule if not any(s['lap']==n and len(s['order'])==len(self.points) for s in self.sprints)),None)

    @property
    def done(self):
        return bool(self.sprints and self.sprints[-1]['lap']==40 and len(self.sprints[-1]['order'])==len(self.points))

    def begin_step(self,riders):
        # All estimates see the same state, independent of loop iteration order.
        self.state={r.id:(r.d,r.v,r.store,r.phys.fatigue) for r in riders}
        self.head=max(d-self.net[i]*LAP for i,(d,v,w,f) in self.state.items())

    def baseline(self,r,target):
        remaining=(self.next_lap or 0)*LAP-self.head
        own=(-r.d)%LAP
        onset={'tt':235.,'attacker':200.,'sprinter':195.}[r.role]
        r.sprint_started=False
        if self.finish_time is None and self.next_lap and 0<remaining<=LAP and 0<own<=onset and r.store/r.store_max>.055:
            r.sprint_started=True
            self.counts[(r.id,'sprint_steps')]+=1
            return max(target,sprint_power(r,own))
        return target

    def demand(self,r,target,riders,time):
        if not self.tactical or self.next_lap==40:
            return self.baseline(r,target)
        r.sprint_started=False
        lap=self.next_lap
        if lap is None or self.finish_time is not None or not 0<lap*LAP-self.head<=LAP:
            self.active.discard(r.id)
            return target
        # Estimate the first physical line AFTER the race head opens the sprint.
        opening=(lap*LAP-self.head)/max(5.,max(v for d,v,w,f in self.state.values()))
        etas={}
        for other in riders:
            d,v,w,f=self.state[other.id]
            distance=(-d)%LAP
            if distance/max(v,5.) < opening-1.0:
                distance+=LAP
            seconds=max(5.,distance/max(v,5.))
            budget=other.phys.cp+.65*w/seconds
            cap=pcurve(seconds,other.phys.cp,other.store_max,other.phys.pmax)
            power=min(cap,budget)
            # Two-second preview uses the SAME speed integration, with assumed
            # aero factor .85; only a tactical forecast, never a physics update.
            projected=integrate_speed(v,power,.85,2.)
            etas[other.id]=distance/max(5.,.45*v+.55*projected)
        probs=place_probabilities(etas[r.id],[eta for i,eta in etas.items() if i!=r.id])
        expected=sum(p*award for p,award in zip(probs,(5,3,2,1)))
        chance=sum(probs)
        future=sum(n>lap for n in self.schedule)
        remaining_fraction=clamp((self.laps*LAP-self.head)/(self.laps*LAP),0.,1.)
        score_gap=max(self.points.values())-self.points[r.id]
        # Keep a larger reserve early and with more sprints ahead. A credible
        # scoring chance or a late need to close a small points gap releases some.
        opportunity=clamp(expected/5.,0.,1.)
        urgency=.06 if 0<score_gap<=5 and lap>=30 else 0.
        reserve_fraction=clamp(.18+.24*remaining_fraction+.035*future-.12*opportunity-urgency,.15,.55)
        reserve=r.store_max*reserve_fraction
        seconds=max(5.,etas[r.id])
        available=max(0.,r.store-reserve)
        requested=min(sprint_power(r,(-r.d)%LAP),r.phys.cp+available/seconds)
        viable=chance>=.23 and expected>=.45 and available>=500.
        was_active=r.id in self.active
        action='sprint' if viable else ('abort' if was_active else 'skip')
        if viable:
            self.active.add(r.id); r.sprint_started=True
            result=max(target,requested)
            # Do not let wheel matching spend more than this sprint's budget.
            result=min(result,r.phys.cp+available/seconds)
            self.counts[(r.id,'sprint_steps')]+=1
        else:
            self.active.discard(r.id)
            result=min(target,r.phys.cp*.90) if was_active else target
        self.counts[(r.id,action)]+=1
        self.decisions.append(dict(time_s=time,id=r.id,role=r.role,lap=lap,action=action,
            p5=probs[0],p3=probs[1],p2=probs[2],p1=probs[3],expected_points=expected,
            reserve_j=reserve,w_j=r.store,target_w=result))
        return result

    def judge_laps(self,time,riders,distances):
        ordered=sorted(riders,key=lambda r:distances[r.id]%LAP)
        gaps=[(distances[ordered[(i+1)%len(ordered)].id]-distances[r.id])%LAP for i,r in enumerate(ordered)]
        cut=max(range(len(gaps)),key=gaps.__getitem__)
        ordered=ordered[cut+1:]+ordered[:cut+1]
        groups=[]
        for r in ordered:
            if not groups or (distances[r.id]-distances[groups[-1][-1].id])%LAP>12:
                groups.append([r])
            else: groups[-1].append(r)
        group=max(groups,key=lambda g:(len(g),len({r.id for r in g}&self.main_ids),-min(r.id for r in g)))
        if len(group)<3: return
        adjusted={r.id:distances[r.id]-self.net[r.id]*LAP for r in riders}
        anchor=statistics.median(adjusted[r.id] for r in group)
        aligned=[adjusted[r.id]-round((adjusted[r.id]-anchor)/LAP)*LAP for r in group]
        tail,front=min(aligned),max(aligned)
        if front-tail>LAP/2: return
        self.main_ids={r.id for r in group}
        decisions=[]
        for r in riders:
            if adjusted[r.id]-tail>=LAP-1e-8: decisions.append((r,1))
            elif front-adjusted[r.id]>=LAP-1e-8: decisions.append((r,-1))
        for r,delta in decisions:
            self.net[r.id]+=delta; self.points[r.id]+=20*delta
            (self.gains if delta>0 else self.losses)[r.id]+=1
            self.lap_events.append(dict(time_s=time,id=r.id,role=r.role,delta=delta,points=20*delta))

    def snapshot(self,before,riders,fraction,time,lap):
        rows=[]
        for r in riders:
            old_d,old_w,old_f=before[r.id]
            w=old_w+fraction*(r.store-old_w)
            rows.append(dict(lap=lap,time_s=time,id=r.id,role=r.role,w_j=w,w_pct=100*w/r.store_max,
                             distance_m=old_d+fraction*(r.d-old_d)))
        return rows

    def observe(self,time,dt,before,riders):
        crossings=[]
        for r in riders:
            if r.finished_at is not None: continue
            old=before[r.id][0]
            assert r.d>=old
            for lap in range(max(1,math.floor(old/LAP)+1),math.floor(r.d/LAP)+1):
                fraction=(lap*LAP-old)/max(r.d-old,1e-12)
                crossings.append((time+dt*fraction,r.id,lap))
        crossings.sort()
        by_id={r.id:r for r in riders}
        # Judge at each line passage before scoring, matching Godot sequencing.
        for crossing,ident,physical_lap in crossings:
            fraction=(crossing-time)/dt
            distances={r.id:before[r.id][0]+fraction*(r.d-before[r.id][0]) for r in riders}
            if self.finish_time is None: self.judge_laps(crossing,riders,distances)
            race_lap=physical_lap-self.net[ident]
            if race_lap+1 in self.schedule and race_lap+1 not in self.bells:
                self.bells[race_lap+1]=dict(time_s=crossing,head=ident,net=dict(self.net))
            if race_lap==35 and not self.energy35:
                self.energy35=self.snapshot(before,riders,fraction,crossing,35)
            if race_lap in self.schedule and not any(s['lap']==race_lap for s in self.sprints):
                self.sprints.append(dict(lap=race_lap,time_s=crossing,order=[],crossing_times=[],awards=[],ties=0))
                self.energy.extend(self.snapshot(before,riders,fraction,crossing,race_lap))
                if race_lap==40: self.finish_time=crossing
            for sprint in self.sprints:
                if crossing<sprint['time_s'] or ident in sprint['order']: continue
                rewards=(10,6,4,2) if sprint['lap']==40 else (5,3,2,1)
                rank=len(sprint['order'])
                # Match shared placings for exact line-time ties (UCI 3.2.118).
                if rank and abs(crossing-sprint['crossing_times'][-1])<1e-9:
                    rank=next(i for i,t in enumerate(sprint['crossing_times']) if abs(t-crossing)<1e-9)
                    sprint['ties']+=1
                award=rewards[rank] if rank<4 else 0
                sprint['order'].append(ident); sprint['crossing_times'].append(crossing); sprint['awards'].append(award)
                self.points[ident]+=award
                own=self.snapshot(before,[by_id[ident]],fraction,crossing,sprint['lap'])[0]
                self.energy_crossing.append(own)
                if sprint['lap']==40: by_id[ident].finished_at=crossing
        if self.finish_time is None:
            self.judge_laps(time+dt,riders,{r.id:r.d for r in riders})
        for r in riders:
            ex=self.exhaustion[r.id]
            # Operational exhaustion thresholds, not clinical claims.
            if not self.energy35 and r.store/r.store_max<=.05:
                ex['low_before35_s']+=dt
                if ex['first_low_time_s'] is None: ex['first_low_time_s']=time+dt
            if not self.energy35 and r.store<=1.: ex['empty_before35_s']+=dt

    def result(self,seed,riders):
        assert self.done and len(self.energy35)==len(riders)
        final=self.sprints[-1]['order']
        standings=sorted(self.points,key=lambda i:(-self.points[i],final.index(i)))
        rows=[]
        for r in riders:
            sprint_points=sum(s['awards'][s['order'].index(r.id)] for s in self.sprints)
            rows.append(dict(id=r.id,role=r.role,points=self.points[r.id],sprint_points=sprint_points,
                sprint_wins=sum(s['order'][0]==r.id for s in self.sprints),gains=self.gains[r.id],losses=self.losses[r.id],
                final_place=final.index(r.id)+1,cp_w=r.phys.cp,wmax_j=r.store_max,pmax_w=r.phys.pmax,
                attacks=r.attacks,sprint_steps=self.counts[(r.id,'sprint_steps')],aborts=self.counts[(r.id,'abort')],
                skips=self.counts[(r.id,'skip')],**self.exhaustion[r.id]))
        expected=sum(sum(s['awards']) for s in self.sprints)+20*sum(self.net.values())
        assert sum(self.points.values())==expected
        assert all(e['time_s']<=self.finish_time for e in self.lap_events)
        return dict(seed=seed,variant=self.variant,winner_id=standings[0],winner_role=next(r.role for r in riders if r.id==standings[0]),
                    initial=self.initial,riders=rows,standings=standings,sprints=self.sprints,energy=self.energy,
                    energy35=self.energy35,energy_crossing=self.energy_crossing,lap_events=self.lap_events,decisions=self.decisions,
                    finish_time_s=self.finish_time,bells=self.bells)
