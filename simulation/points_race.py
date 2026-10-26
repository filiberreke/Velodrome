"""Points-race reference integration using the existing Godot reference physics.

Standalone analysis only: not connected to main.gd. All distances are unwrapped.
"""
import math
import random
from dataclasses import dataclass, field
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "game" / "simulator"))
from simulate import LAP, speed_step, tt_power, sprinter_cruise

INTERMEDIATE = (5, 3, 2, 1)
FINAL = (10, 6, 4, 2)


@dataclass
class Jury:
    riders: int
    laps: int = 10
    interval: int = 10
    gap: float = 14.0
    distances: list = field(default_factory=list)
    lap_balance: list = field(default_factory=list)
    sprint_points: list = field(default_factory=list)
    awards: list = field(default_factory=list)
    events: list = field(default_factory=list)
    peloton: tuple = ()
    anchor: float = 0.0
    reference_laps: int = 0
    sprint_done: set = field(default_factory=set)

    def __post_init__(self):
        self.distances = [0.0] * self.riders
        self.lap_balance = [0] * self.riders
        self.sprint_points = [0] * self.riders
        self.awards = [0] * self.riders

    def _group(self, positions):
        # Cluster on physical unwrapped distance, with hysteresis toward old peloton.
        ids = sorted(range(self.riders), key=lambda i: positions[i])
        groups = []
        for i in ids:
            if not groups or positions[i] - positions[groups[-1][-1]] > self.gap:
                groups.append([i])
            else:
                groups[-1].append(i)
        return max(groups, key=lambda g: (len(g), len(set(g) & set(self.peloton)), -abs(sum(positions[i] for i in g)/len(g)-self.anchor)))

    def update(self, positions):
        if len(positions) != self.riders or any(x < 0 for x in positions):
            raise ValueError("Expected positive unwrapped distances for every rider")
        if any(a < b for a, b in zip(positions, self.distances)):
            raise ValueError("Distances must not decrease")
        old = self.distances[:]
        old_anchor = self.anchor
        self.distances = list(positions)
        group = self._group(positions)
        self.peloton = tuple(group)
        # The peloton's clock belongs to its reference riders, not fastest individual.
        self.anchor = sum(positions[i] for i in group) / len(group)
        self.reference_laps = min(self.laps, math.floor(self.anchor / LAP))
        # Count physical overtakes of an entire lap, relative to previous anchor.
        # Require approaching/entering the appropriate edge of the peloton.
        front = max(positions[i] for i in group)
        back = min(positions[i] for i in group)
        for i in range(self.riders):
            if i in group:
                continue
            prev = (old[i] - old_anchor) / LAP
            now = (positions[i] - self.anchor) / LAP
            # Crossing integer lap lead thresholds represents catching the back of pack.
            new_balance = math.floor((positions[i] - back) / LAP) if positions[i] >= back else -math.ceil((front - positions[i]) / LAP)
            # Avoid inventing lap events when group identity changes: only crossing
            # threshold in continuous unwrapped relative distance can award.
            if now > prev:
                for k in range(self.lap_balance[i] + 1, new_balance + 1):
                    if k > 0 and prev < k <= now + self.gap/LAP:
                        self.lap_balance[i] += 1
                        self.events.append(("gain", i, self.lap_balance[i]))
            elif now < prev:
                for k in range(self.lap_balance[i], new_balance, -1):
                    if k <= 0 and now - self.gap/LAP <= k-1 < prev:
                        self.lap_balance[i] -= 1
                        self.events.append(("loss", i, self.lap_balance[i]))
        # Future work: official peloton membership must be locked during fragmentation.
        for lap in range(self.interval, self.laps + 1, self.interval):
            if lap <= self.reference_laps and lap not in self.sprint_done:
                # Rank crossings of the physical finish line at the peloton clock.
                # Snapshot proxy; full crossing-time tracking follows in gameplay integration.
                rank = sorted(range(self.riders), key=lambda i: (-positions[i], i))
                rewards = FINAL if lap == self.laps else INTERMEDIATE
                for i, pts in zip(rank[:4], rewards):
                    self.sprint_points[i] += pts
                self.sprint_done.add(lap)
                self.events.append(("sprint", lap, rank[:4]))
        return {"front": front % LAP, "back": back % LAP,
                "front_unwrapped": front, "back_unwrapped": back,
                "peloton": list(group), "lap": self.reference_laps}

    def total(self, i):
        return self.sprint_points[i] + 20 * self.lap_balance[i]


def simulate_points(laps=10, riders=8, seed=42, dt=0.25, difficulty=80):
    if laps < 10 or riders < 4:
        raise ValueError("Need at least 10 laps and 4 riders")
    rng = random.Random(seed)
    types = ["player"] + ["sprinter", "attacker", "time_trialist"] * ((riders + 1)//3)
    types = types[:riders]
    forms = [1.0] + [rng.uniform(.95, 1.05) for _ in range(riders-1)]
    speeds = [0.0]*riders
    positions = [0.0]*riders
    reserve = [18000.0 if t == "sprinter" else 30000.0 if t == "attacker" else 11500.0 for t in types]
    jury = Jury(riders, laps)
    t = 0.0
    while jury.reference_laps < laps and t < laps * 120:
        for i, kind in enumerate(types):
            if kind == "player":
                power = 305 * difficulty/80
            elif kind == "time_trialist":
                power = tt_power(laps*30)*difficulty/100*forms[i]
            elif kind == "sprinter":
                sustain = sprinter_cruise(laps)*forms[i]
                # Use the peloton clock, not each rider's own final lap.
                to_sprint = (jury.anchor % (10*LAP)) > 9.7*LAP
                target = 860*forms[i] if to_sprint else sustain
                extra = min(max(0, target-sustain), reserve[i]/dt)
                reserve[i] -= extra*dt
                power = min((sustain+extra)*difficulty/80, 960*forms[i])
            else:
                sustain = 220*forms[i]
                # Deterministic short attacks, preserving the existing energy reservoir.
                attacking = (int(t//42)+i) % 4 == 0
                extra = min((390 if attacking else 0), reserve[i]/dt)
                reserve[i] -= extra*dt
                power = (sustain+extra)*difficulty/80
            ahead = [positions[j]-positions[i] for j in range(riders)
                     if i != j and 1.2 < positions[j]-positions[i] < 12]
            speeds[i] = speed_step(speeds[i], power, dt, .4 if ahead else 0)
            positions[i] += speeds[i]*dt
        jury.update(positions)
        t += dt
    return {"elapsed": t, "completed": jury.reference_laps >= laps,
            "points": [jury.total(i) for i in range(riders)],
            "lap_balance": jury.lap_balance, "sprint_points": jury.sprint_points,
            "standings": sorted(range(riders), key=lambda i: (-jury.total(i), -positions[i])),
            "events": jury.events, "peloton": jury.peloton, "positions": positions,
            "types": types}
