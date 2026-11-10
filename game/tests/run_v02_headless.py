"""Run v0.2 regressions with isolated settings and strict Godot error detection.

Import the project first. Use --all for every standalone test, then run
bridge/tests with GODOT_BIN and GODOT_PROJECT set for the UDP fixtures.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BIN') or shutil.which('godot'))
    parser.add_argument('--all', action='store_true')
    parser.add_argument('--timeout', type=int, default=900)
    parser.add_argument('--output', type=Path)
    parser.add_argument('tests', nargs='*')
    args = parser.parse_args()
    if not args.godot:
        parser.error('Pass --godot /path/to/Godot')
    project = Path(__file__).resolve().parents[1]
    output = (args.output or project/'verification/v02/run').resolve()
    output.mkdir(parents=True, exist_ok=True)
    names = args.tests or [
        'test_v02_bugfixes', 'test_v02_capacity', 'test_v02_cadence',
        'test_points_race', 'test_points_notifications', 'test_hud',
        'test_pursuit', 'test_pursuit_levels', 'test_pursuit_flow',
        'test_team_pursuit', 'test_derny_training', 'test_piste_exercises',
        'test_free_training', 'test_ftp_ramp', 'test_workout_library',
        'test_training_signal_pause', 'test_keirin_flow', 'test_gameplay_headless']
    if args.all and not args.tests:
        names = [p.stem for p in sorted((project/'tests').glob('test_*.gd'))
                 if not p.stem.endswith('_udp')
                 and not re.search(r'args\[\d|get_cmdline_user_args\(\)\[', p.read_text(encoding='utf-8'))]
        names += ['res://'+p.name for p in sorted(project.glob('test_*.gd'))]
    results = []
    engine = subprocess.check_output([args.godot, '--version'], text=True).strip()
    for name in names:
        start = time.monotonic()
        log_name = name.removeprefix('res://').replace('/', '_')
        script = name if name.startswith('res://') else 'res://tests/'+name+'.gd'
        with tempfile.TemporaryDirectory(prefix='velodrome-v02-') as folder:
            env = dict(os.environ, APPDATA=folder, LOCALAPPDATA=folder)
            command = [args.godot, '--headless', '--path', str(project),
                       '--log-file', str(output/(log_name+'.engine.log')),
                       '--script', script]
            try:
                run = subprocess.run(command, env=env, capture_output=True, timeout=args.timeout,
                                     creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
                text = (run.stdout+run.stderr).decode('utf-8', errors='replace')
                code = run.returncode
            except subprocess.TimeoutExpired as exc:
                text = ((exc.stdout or b'')+(exc.stderr or b'')).decode('utf-8', errors='replace')
                code = 'timeout'
        (output/(log_name+'.log')).write_text(text, encoding='utf-8')
        errors = [line for line in text.splitlines()
                  if any(marker in line for marker in ('SCRIPT ERROR', 'ERROR:', 'Assertion failed'))]
        # These two local platform diagnostics also occur on unmodified v0.2.
        environment = [line for line in errors if 'root certificate store' in line
                       or (line == 'ERROR: Parameter "material" is null.'
                           and 'dummy/storage/material_storage.cpp' in text)]
        errors = [line for line in errors if line not in environment]
        result = dict(test=name, passed=code == 0 and not errors, exit_code=code,
                      seconds=round(time.monotonic()-start, 2), errors=errors,
                      environment=sorted(set(environment)))
        results.append(result)
        print(json.dumps(result), flush=True)
        (output/'summary.json').write_text(json.dumps(dict(engine=engine, tests=results), indent=2), encoding='utf-8')
    return 0 if all(result['passed'] for result in results) else 1


if __name__ == '__main__':
    raise SystemExit(main())
