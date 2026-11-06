"""Run Phase 3 and Phase 2 regression tests in an isolated Godot project.

Set GODOT_BIN to a Godot 4.7 executable, then run python tests/run_ride_mapping.py.
Only stdlib is needed. No user settings or active game's UDP port are touched.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SUITES = ["test_ride_mapping", "test_ride_mapping_routing", "test_controller_settings",
          "test_ride_phase2", "test_ride_pursuit_navigation", "test_analog_steering",
          "test_bridge_navigation"]


def main():
    engine = os.environ.get("GODOT_BIN", "godot")
    results = []
    with tempfile.TemporaryDirectory(prefix="velodrome-ride-mapping-") as folder:
        work = Path(folder)
        project = work / "game"
        # Source .blend imports require a separately configured Blender; CSV
        # race-result files trigger translation import. Neither is used by these
        # tests. Runtime .glb, textures, scripts and scenes are copied unchanged.
        shutil.copytree(ROOT / "game", project, ignore=shutil.ignore_patterns(
            ".godot", "*.blend", "*.blend.import", "*.csv", "*.csv.import"))

        def run(name, command, environment):
            try:
                result = subprocess.run(command, cwd=ROOT, env=environment,
                                        capture_output=True, timeout=240)
                output = (result.stdout + result.stderr).decode(errors="replace")
                code = result.returncode
            except subprocess.TimeoutExpired as exc:
                output = ((exc.stdout or b"") + (exc.stderr or b"")).decode(errors="replace")
                code = "timeout"
            # Known engine/environment warnings also occur on unmodified main.
            errors = [line for line in output.splitlines()
                      if ("SCRIPT ERROR" in line or "ERROR:" in line)
                      and "root certificate store" not in line
                      and "UVs are required to generate tangents" not in line
                      and 'Parameter "material" is null' not in line]
            passed = code == 0 and not errors
            if name in SUITES: passed = passed and ("_OK" in output or "failures=0" in output)
            if name == "bridge": passed = passed and "OK" in output.splitlines() and "skipped=" not in output
            results.append({"suite": name, "passed": passed, "exit": code, "errors": errors})
            print(json.dumps(results[-1]), flush=True)
            if not passed: print(output[-15000:], flush=True)
            return passed

        env = dict(os.environ, APPDATA=str(work / "import_user"), LOCALAPPDATA=str(work / "import_local"))
        if not run("import", [engine, "--headless", "--editor", "--import", "--path", str(project)], env):
            return 1
        for suite in SUITES:
            env = dict(os.environ, APPDATA=str(work / suite / "appdata"),
                       LOCALAPPDATA=str(work / suite / "local"))
            run(suite, [engine, "--headless", "--path", str(project),
                        "--script", "res://tests/" + suite + ".gd"], env)
        env = dict(os.environ, GODOT_BIN=engine, GODOT_PROJECT=str(project),
                   APPDATA=str(work / "udp_user"), LOCALAPPDATA=str(work / "udp_local"))
        run("bridge", [os.sys.executable, "-m", "unittest", "discover", "-s", "bridge/tests", "-v"], env)
    return 0 if all(result["passed"] for result in results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
