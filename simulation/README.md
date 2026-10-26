# Points race simulation (prototype)

This is a standalone extension of the existing reference simulator in `game/simulator/simulate.py`. It imports the **same** `speed_step`, `tt_power`, and `sprinter_cruise` functions; it does **not** modify the playable Godot game or the scratch simulation.

Run from repository root:

```bash
python -m unittest discover -s simulation -p 'test_*.py'
python -c "from simulation.points_race import simulate_points; print(simulate_points(laps=10, seed=42))"
```

Configuration: 250 m track; 10-lap short test; 10-lap sprint interval; intermediate 5/3/2/1, final 10/6/4/2; +20/-20 per official lap gained/lost. The race clock is the detected peloton's lap counter. Physical positions are unwrapped, so a rider can travel an extra lap while the peloton runs the same official course length.

**Important limitations, not production-ready:** peloton selection currently uses compact distance clusters rather than a locked race-jury identity; the sprint order is a distance snapshot, not sub-frame finish-line crossing order; AI attack choices are deterministic prototype rules, not the full tactical AI; the visual front/back curtains are exposed as coordinates, not rendered. Lap gain/loss events require crossing relative lap thresholds with unchanged peloton membership; group splits require more rigorous referee handling. These issues must be solved before wiring the mode into Godot gameplay. Existing scratch code stays unchanged.
