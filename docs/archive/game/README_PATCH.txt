VELODROME 250 - INTEGRATION CHECKPOINT (partial patch)
Source: velodrome_export.zip, supplied Oct 22 2026.
Contains: main.gd (based strictly on upload), scratch_lap_rules.gd,
          test_scratch_lap_rules.gd.

IMPORTANT - NOT YET A COMPLETE PORT OF PYTHON SIMULATOR X.
The uploaded main.gd uses older, different AI power and tactical rules.
This patch implements a defensible Godot starting point for circular drafting,
physical lap rejoining at <2m behind main bunch, and lap-priority scratch results.
AI states, CP/Wprime physiology, breakaway collaboration and 750m sprint logic
from the Python simulator have NOT been ported into Godot yet.
Do not interpret the 1,000 Python tests as tests of this Godot code.

Files changed: main.gd
Files added: scratch_lap_rules.gd, test_scratch_lap_rules.gd
No assets, user configs, bridge scripts, or Strava files included.
No full Godot engine binary was available in this execution environment.
Run the included GDScript headless test from an assembled original Godot
project and test editor load before gameplay.

Lap gain rules are intentionally stricter than the earlier Python X 18m zone;
after full peloton-rear contact (<2m) a race lap credit is awarded once.
Track positions use modulo 250m for drafting and raw travelled distance
for event progression and display. Racer ranking credits lap gains first.
