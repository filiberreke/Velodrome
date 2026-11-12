# Native keirin

Keirin is now playable through the existing menu/start-list/intro/start-gate flow.
It has six riders and six laps: three paced laps and three free laps. Drawn
positions form two columns behind the existing derny GLB. The paced stage is
assisted/prescribed, as in the standalone prototype; it does not prove that each
rider could independently reproduce that formation under unassisted physics.

The motorbike gradually accelerates from 25 km/h. Its release speed is 45 km/h
at 70%, 50 km/h at 100%, with interpolation between those settings. The pilot
looks back once per completed paced lap, never raises a hand in the keirin,
then rolls into the inside zone. The separate derny-training behaviour is preserved.

The free race uses main.gd's real force balance, path metrics, banking and drafting,
and the existing CP/W-prime/fatigue/profile configuration. The Python experiment's
illustrative 900+ W CP values are deliberately not imported. The real player keeps
their trainer/PC power; only the headless test's explicit `all_ai` flag substitutes
an AI for the player. Zero power in the free phase is not assisted.

Each AI rider launches on their own remaining distance and available reserve.
Following a wheel before that launch still asks for the power needed to close
the gap, within the same physiological limits. A blocked sprinter follows until
the complete passing corridor is free. Two racing corridors are available to
the player and AI; changing lanes is gradual and checks approaching traffic.

Finish times and race distances freeze on crossing. Display positions continue
separately: coast, brake gradually, yield while descending into the grey inner
zone, take the real gate halfway along the opposite straight, and ride to the
country's existing cabin. Unassigned countries use the established parking
spaces beyond the box row; a rider is never sent to another country's cabin.
Close-pack collision and exit-route interaction remain a game approximation,
not a validated real-world racing/traffic model.

## Reproduce

With Godot 4.7+ and the project's imported resources:

```text
python game/tests/run_keirin_headless.py --godot /path/to/Godot
python game/tests/run_keirin_headless.py --godot /path/to/Godot --quick test_keirin
```

`test_keirin` runs seeds 42–141 at 70% and 100%, four native sprinters and two
native attackers. It checks fixed-step/frame-rate consistency, paced spacing,
monotonic motorbike acceleration, release speed, animation requests, physiological
bounds, every finish, immutable results and every box arrival. The two extra
seed-17 runs compare frame sizes of 0.1 s and 1/60 s.

`test_keirin_flow` exercises the real menu, opponent selection, mode switch from
points, imported animation, normal release, player controls, zero human power,
mixed-profile opponents, results and restart. Other defaults check derny training,
scratch, points, shared traffic and the newly backported elimination implementation.

Generated logs, JSON and CSV go in ignored `run/`. The checked-in batch data
and validation summary record the verified implementation. The native batch
includes v0.2 `f4329b7` (the other agent's elimination changes); the subsequent
bridge fix `bdd5f7e` is also incorporated and its UDP fixture, training and keirin
menu flow were rechecked. That bridge change does not alter the keirin controller.

The batch's `overtakes_last_lap` is a sampled longitudinal order crossing while
both riders race and at least one is beyond 1250 m. It is a diagnostic, not the
stricter confirmed/sustained passing metric from the earlier Python report.
`acceleration_last_lap` means at least one positive sampled speed increment;
it is not a count of deliberate tactical attacks.

The verified 200-race batch has 1200/1200 finishes and box arrivals. At 70%,
sprinters win 61 races and attackers 39; at 100%, 59 and 41. Sampled final-lap
order changes occur in 40 and 36 races respectively. These native outcomes are
not a reproduction of the Python prototype's winner percentages: the real
power values, banking, path length, drafting and passing decisions are different.

## Existing baseline test issues

`test_startlist_flow` has two obsolete assertions expecting time-trial records
to be a future feature. They also fail in the untouched v0.2 baseline; the keirin
change does not alter those records. That existing test is retained and the
baseline comparison is recorded in validation.json.

The headless dummy renderer logs null-material messages when a menu is freed;
these were reproduced in the baseline. Windows also reports an unavailable root
certificate store. The runner preserves these messages as environment notes.
Script errors and failed assertions still fail the run. An editor import may
also report a missing local Blender configuration for unused source assets;
the shipped GLB and textures are separately loaded by the gameplay tests.
