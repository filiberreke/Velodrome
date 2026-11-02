"""Independent points-race jury. Distances are unwrapped 250 m progress."""
import math
import statistics
from collections import Counter
from sim_f import LAP, pcurve


class Jury:
    def __init__(self, riders, laps=40, sprint_every=10):
        if laps < 1 or sprint_every < 1 or laps % sprint_every:
            raise ValueError('laps must be a positive multiple of sprint_every')
        self.laps = laps
        self.schedule = list(range(sprint_every, laps+1, sprint_every))
        self.points = {r.id: 0 for r in riders}
        self.net = dict.fromkeys(self.points, 0)
        self.gains = dict.fromkeys(self.points, 0)
        self.losses = dict.fromkeys(self.points, 0)
        self.sprints = []
        self.lap_events = []
        self.energy35 = []
        self.last_sprint_time = None
        self.finish_time = None
        self.main_ids = set()
        self.sprint_efforts = Counter()

    @property
    def next_sprint_lap(self):
        return next((lap for lap in self.schedule
                     if not any(s['lap'] == lap and len(s['order']) == len(self.points)
                                for s in self.sprints)), None)

    @property
    def done(self):
        return bool(self.sprints and self.sprints[-1]['lap'] == self.laps
                    and len(self.sprints[-1]['order']) == len(self.points))

    def sprint_demand(self, r, target, lead):
        lap = self.next_sprint_lap
        r.sprint_started = False
        if lap is None or self.finish_time is not None:
            return target
        remaining = lap*LAP-lead
        # Use the next physical line for lapped riders too. All roles can try.
        own_remaining = (-r.d) % LAP
        onset = {'tt': 235., 'attacker': 200., 'sprinter': 195.}[r.role]
        if 0 < remaining <= LAP and 0 < own_remaining <= onset and r.store/r.store_max > .055:
            seconds = max(5., own_remaining/max(r.v, 5.))
            cap = pcurve(seconds, r.phys.cp, r.phys.wmax, r.phys.pmax)
            budget = r.phys.cp + .88*r.store/max(6., seconds)
            target = max(target, min(cap*{'tt': .75, 'attacker': .87, 'sprinter': .99}[r.role], budget))
            r.sprint_started = True
            self.sprint_efforts[r.id] += 1
        return target

    def judge_laps(self, time, riders, distances):
        """Catch the rear / be caught by the front of the largest physical bunch.

        A bunch is a circular chain with <=12 m gaps, >=3 riders and <=125 m
        span. Ambiguous dispersed fields receive no automatic lap award.
        Net lap credits normalize progress but never move a rider physically.
        """
        ordered = sorted(riders, key=lambda r: distances[r.id] % LAP)
        gaps = [((distances[ordered[(i+1) % len(ordered)].id] - distances[r.id]) % LAP)
                for i, r in enumerate(ordered)]
        cut = max(range(len(gaps)), key=gaps.__getitem__)
        ordered = ordered[cut+1:] + ordered[:cut+1]
        groups = []
        for r in ordered:
            if not groups or (distances[r.id]-distances[groups[-1][-1].id]) % LAP > 12:
                groups.append([r])
            else:
                groups[-1].append(r)
        group = max(groups, key=lambda g: (len(g), len({r.id for r in g} & self.main_ids), -min(r.id for r in g)))
        if len(group) < 3:
            return
        adjusted = {r.id: distances[r.id]-self.net[r.id]*LAP for r in riders}
        anchor = statistics.median(adjusted[r.id] for r in group)
        aligned = [adjusted[r.id]-round((adjusted[r.id]-anchor)/LAP)*LAP for r in group]
        tail, front = min(aligned), max(aligned)
        if front-tail > LAP/2:
            return
        self.main_ids = {r.id for r in group}
        # Use one immutable reference for simultaneous catches.
        decisions = []
        for r in riders:
            if adjusted[r.id]-tail >= LAP-1e-8:
                decisions.append((r, 1))
            elif front-adjusted[r.id] >= LAP-1e-8:
                decisions.append((r, -1))
        for r, delta in decisions:
            self.net[r.id] += delta
            self.points[r.id] += 20*delta
            (self.gains if delta > 0 else self.losses)[r.id] += 1
            self.lap_events.append(dict(time_s=time, id=r.id, role=r.role,
                                        delta=delta, points=20*delta,
                                        main_bunch=sorted(self.main_ids)))

    def observe(self, time, dt, before, riders):
        crossings = []
        for r in riders:
            old = before[r.id][0]
            if r.d < old:
                raise AssertionError('backwards progress')
            for lap in range(max(1, math.floor(old/LAP)+1), math.floor(r.d/LAP)+1):
                fraction = (lap*LAP-old)/max(r.d-old, 1e-12)
                crossings.append((time+dt*fraction, r.id, lap))
        crossings.sort()
        # Determine the exact common finish cutoff before judging this timestep.
        finish = next((t for t, _, lap in crossings if lap == self.laps), None)
        if self.finish_time is None and finish is not None:
            self.finish_time = finish
        cutoff = min(time+dt, self.finish_time) if self.finish_time is not None else time+dt
        if cutoff > time:
            fraction = (cutoff-time)/dt
            distances = {r.id: before[r.id][0]+fraction*(r.d-before[r.id][0]) for r in riders}
            self.judge_laps(cutoff, riders, distances)
        by_id = {r.id: r for r in riders}
        for crossing, ident, lap in crossings:
            if lap == 35 and not self.energy35:
                # Only the leader's lap 35 opens this common snapshot.
                fraction = (crossing-time)/dt
                for r in riders:
                    old_d, old_w, old_f = before[r.id]
                    w = old_w+fraction*(r.store-old_w)
                    self.energy35.append(dict(id=r.id, role=r.role, time_s=crossing,
                        distance_m=old_d+fraction*(r.d-old_d), cp_w=r.phys.cp,
                        w_j=w, w_pct=100*w/r.store_max,
                        fatigue_pct=100*(old_f+fraction*(r.phys.fatigue-old_f))))
            if lap in self.schedule and not any(s['lap'] == lap for s in self.sprints):
                self.sprints.append(dict(lap=lap, time_s=crossing, order=[], crossing_times=[], awards=[]))
                self.last_sprint_time = crossing
            for sprint in self.sprints:
                if crossing < sprint['time_s'] or ident in sprint['order']:
                    continue
                rank = len(sprint['order'])
                rewards = (10, 6, 4, 2) if sprint['lap'] == self.laps else (5, 3, 2, 1)
                award = rewards[rank] if rank < 4 else 0
                sprint['order'].append(ident)
                sprint['crossing_times'].append(crossing)
                sprint['awards'].append(award)
                self.points[ident] += award
                if sprint['lap'] == self.laps:
                    by_id[ident].finished_at = crossing

    def result(self, seed, riders, attacks):
        if not self.done or len(self.energy35) != len(riders):
            raise RuntimeError('incomplete points race or missing lap-35 snapshot')
        final = self.sprints[-1]['order']
        standings = sorted(self.points, key=lambda ident: (-self.points[ident], final.index(ident)))
        rows = [dict(id=r.id, role=r.role, cp_w=r.phys.cp, points=self.points[r.id],
                     gains=self.gains[r.id], losses=self.losses[r.id], net_laps=self.net[r.id],
                     final_place=final.index(r.id)+1, attacks=r.attacks,
                     sprint_effort_steps=self.sprint_efforts[r.id], chase_s=r.chase_seconds,
                     work_above_cp_j=r.phys.work_above) for r in riders]
        expected = (len(self.schedule)-1)*11+22+20*sum(self.net.values())
        assert sum(self.points.values()) == expected
        return dict(seed=seed, laps=self.laps, field=len(riders), standings=standings,
                    winner_role=next(r.role for r in riders if r.id == standings[0]),
                    riders=rows, sprints=self.sprints, lap_events=self.lap_events,
                    energy35=self.energy35, attacks=attacks, finish_time_s=self.finish_time)
