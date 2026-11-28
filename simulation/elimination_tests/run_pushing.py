"""Run paired native Godot race measurements against either worktree."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import tempfile
from threading import Lock, Timer

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / 'game/tests/measure_elimination_pushing.gd'
POLICIES = {'autonomous', 'steering'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('worktree', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--jobs', type=int, default=4)
    parser.add_argument('--seed-start', type=int, default=17)
    parser.add_argument('--seeds', type=int, default=15)
    parser.add_argument('--counts', type=int, nargs='+', choices=[8, 16, 24], default=[8, 16, 24])
    parser.add_argument('--timeout', type=float, default=900, help='wall seconds allowed per pair of races')
    args = parser.parse_args()
    if args.jobs < 1 or args.seeds < 1 or args.timeout <= 0:
        parser.error('jobs, seeds and timeout must be positive')
    worktree = args.worktree.resolve()
    script = worktree / 'game/tests' / SCRIPT.name
    harness = SCRIPT.read_bytes()
    if not script.exists():
        script.write_bytes(harness)
    elif script.read_bytes() != harness:
        parser.error(f'Update the measurement harness in {script} before comparing revisions')
    revision = subprocess.check_output(['git', '-C', worktree, 'rev-parse', 'HEAD'], text=True).strip()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    previous = [json.loads(line) for line in args.output.read_text().splitlines()] if args.output.exists() else []
    if any(row['checkout'] != revision for row in previous):
        parser.error('Existing output belongs to a different commit')
    completed = {(row['seed'], row['count'], row['policy']) for row in previous if row['complete']}
    jobs = [(seed, count) for seed in range(args.seed_start, args.seed_start + args.seeds)
            for count in dict.fromkeys(args.counts)
            if any((seed, count, policy) not in completed for policy in POLICIES)]
    lock = Lock()

    def run(seed, count):
        with tempfile.TemporaryDirectory(prefix='velodrome-race-') as run_dir:
            env = {**os.environ, 'XDG_DATA_HOME': run_dir}
            command = [args.godot, '--headless', '--path', str(worktree / 'game'), '-s',
                       f'res://tests/{SCRIPT.name}', '--', f'--seed={seed}', f'--count={count}']
            with subprocess.Popen(command, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as process:
                deadline = Timer(args.timeout, process.kill)
                deadline.daemon = True
                deadline.start()
                try:
                    policies = set()
                    errors = []
                    for line in process.stdout:
                        if 'SCRIPT ERROR' in line:
                            errors.append(line)
                        if not line.startswith('PUSH_RACE '):
                            continue
                        row = json.loads(line.removeprefix('PUSH_RACE '))
                        policies.add(row['policy'])
                        if (seed, count, row['policy']) in completed:
                            continue
                        with lock, args.output.open('a') as output:
                            output.write(json.dumps({'checkout': revision, **row}, separators=(',', ':')) + '\n')
                            print(f"{seed=} {count=} {row['policy']} complete={row['complete']}", flush=True)
                    if process.wait() or errors or policies != POLICIES:
                        raise RuntimeError(f'{seed=} {count=} {policies=} {errors=}')
                finally:
                    deadline.cancel()

    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = [pool.submit(run, seed, count) for seed, count in jobs]
        for result in results:
            result.result()


if __name__ == '__main__':
    main()
