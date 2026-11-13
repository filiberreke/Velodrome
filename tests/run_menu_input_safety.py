"""Run menu input and navigation regressions without touching player settings.

Set GODOT_BIN to a Godot 4.7 executable and run this file with Python.
Logs and a JSON summary are written to --output (default: .test-user/menu-input).
Godot script errors fail the run even when the engine exits with code zero.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SUITES = [
    "test_menu_input_safety", "test_menu_navigation", "test_menu_cleanup",
    "test_keyboard_mapping", "test_menu", "test_menu_theme", "test_v02_menu",
    "test_workout_filters", "test_workout_editor_ui", "test_controller_settings",
    "test_exit_pause", "test_result_navigation", "test_ride_pursuit_navigation",
    "test_ride_mapping_routing", "test_bridge_devices", "test_player_appearance",
    "test_v02_bugs", "test_elimination_positioning", "test_keirin_player_traffic",
    "test_strava_metadata",
]
# These engine/environment diagnostics also occur on unchanged main. Never
# suppress SCRIPT ERROR, assertions, missing resources, or parse failures.
KNOWN_ENGINE_DIAGNOSTICS = (
    "Failed to read the root certificate store",
    "UVs are required to generate tangents",
    'Parameter "material" is null',
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / ".test-user/menu-input")
    parser.add_argument("--suite", action="append", choices=SUITES)
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    engine = os.environ.get("GODOT_BIN", "godot")
    results = []
    with tempfile.TemporaryDirectory(prefix="velodrome-menu-input-") as folder:
        work = Path(folder)
        project = work / "game"
        # Runtime GLB assets are authoritative for these tests. Excluding Blender
        # sources avoids requiring an editor-specific Blender installation.
        shutil.copytree(ROOT / "game", project, ignore=shutil.ignore_patterns(
            ".godot", "*.blend", "*.blend.import", "*.csv", "*.csv.import", "override.cfg"))

        def run(name, arguments, timeout=300):
            env = dict(os.environ, APPDATA=str(work / name / "appdata"),
                       LOCALAPPDATA=str(work / name / "local"))
            for key in ("APPDATA", "LOCALAPPDATA"):
                Path(env[key]).mkdir(parents=True, exist_ok=True)
            log = output / (name + ".log")
            command = [engine, "--headless", "--path", str(project),
                       "--log-file", str(log), *arguments]
            try:
                process = subprocess.run(command, env=env, capture_output=True, timeout=timeout)
                code = process.returncode
                captured = (process.stdout + process.stderr).decode(errors="replace")
            except subprocess.TimeoutExpired as exc:
                code = "timeout"
                captured = ((exc.stdout or b"") + (exc.stderr or b"")).decode(errors="replace")
            text = log.read_text(encoding="utf-8", errors="replace") if log.exists() else captured
            errors = [line for line in text.splitlines()
                      if "SCRIPT ERROR" in line or ("ERROR:" in line and not any(
                          known in line for known in KNOWN_ENGINE_DIAGNOSTICS))]
            marker = name == "import" or any(token in text for token in (
                "failures=0", "_OK", ": PASS"))
            result = {"suite": name, "passed": code == 0 and not errors and marker,
                      "exit": code, "errors": errors}
            if name == "test_menu_input_safety":
                result["summary"] = [line for line in text.splitlines() if line.startswith("MENU_INPUT_SAFETY")]
            results.append(result)
            (output / "summary.json").write_text(json.dumps(results, indent=2), encoding="utf-8")
            print(json.dumps(result), flush=True)
            return result["passed"]

        if not run("import", ["--editor", "--import", "--quit"]):
            return 1
        for suite in args.suite or SUITES:
            run(suite, ["--fixed-fps", "240", "--script", "res://tests/" + suite + ".gd"], timeout=900)
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
