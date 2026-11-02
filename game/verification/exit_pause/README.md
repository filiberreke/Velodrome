# Exit icon and race pause validation

Tested with Godot 4.7.2 on Windows, against main at f6103b4.

Passed:
- test_exit_pause.gd: menu/settings/result exit visibility; real viewport Escape input including focused pause buttons; frozen clock, distance and countdown; keyboard/trainer steering guards; leave confirmation/cancellation; return to gallery; trainer release and delayed resume; pending ERG acquisition release.
- test_pursuit_flow.gd, test_results_podium.gd, test_gameplay_headless.gd
- test_trainer_control.gd, test_bridge_steering.gd
- test_solo_time_trial_hud.gd (66 checks), test_points_race.gd
- test_elimination_gameplay.gd, test_team_pursuit.gd

Visual check: rendered menu and pause screenshots at 1280x720 (1920x1080 logical canvas). Exit sits beside Settings without overlap; pause controls are centered and readable.

Existing failures reproduced against the unchanged main.gd from f6103b4:
- test_menu.gd: 7 failures, starting with its assumption that time trial is unimplemented.
- test_startlist_flow.gd: 2 failures, both expecting time trial records to be a future category.
- test_bridge_navigation.gd: 1 failure, "Bridge A can start configured race".

The team bridge integration script requires telemetry/command ports and an external bridge process. It was not validated end to end; a direct invocation without those arguments was stopped. No physical trainer was available. Trainer protocol checks above use local test doubles.

For a fresh checkout, follow the existing Windows demo CI import procedure: temporarily isolate Blender source files (keep exported GLBs), then import assets before running scripts. The first import can report preload errors before the texture cache is built. Local Windows certificate-store warnings and existing headless material warnings were also observed.

Manual device follow-up: pause/resume during a live SIM race and an ERG team pursuit, confirm resistance is released during pause and restored only after resume; leave the event and exit from the gallery.
