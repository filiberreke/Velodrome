"""Reproducible 40-lap / 16-AI tempo-race baseline batch on the latest scratch physics."""
import argparse
import csv
import json
import statistics
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from energy_core import PARS
from tempo_engine import run


def summarize(results):
    roles = list(PARS)
    summary = dict(races=len(results), laps=40, field=16, sprint_laps=list(range(5,41)),
                   winner_types=dict(Counter(r['winner_role'] for r in results)))
    summary['by_type'] = {}
    for role in roles:
        riders = [x for r in results for x in r['riders'] if x['role'] == role]
        energy = [x for r in results for x in r['energy35'] if x['role'] == role]
        summary['by_type'][role] = dict(
            rider_observations=len(riders), base_cp_w=PARS[role][0],
            gains=sum(x['gains'] for x in riders), losses=sum(x['losses'] for x in riders),
            attacks=sum(x['attacks'] for x in riders),
            mean_sprint_effort_s=statistics.mean(2*x['sprint_effort_steps'] for x in riders),
            mean_chase_s=statistics.mean(x['chase_s'] for x in riders),
            mean_w35_j=statistics.mean(x['w_j'] for x in energy),
            mean_w35_pct=statistics.mean(x['w_pct'] for x in energy),
            min_w35_pct=min(x['w_pct'] for x in energy),
            max_w35_pct=max(x['w_pct'] for x in energy))
    summary['sprint_winner_types'] = {}
    for lap in summary['sprint_laps']:
        winners = []
        for r in results:
            ident = next(s['order'][0] for s in r['sprints'] if s['lap'] == lap)
            winners.append(next(x['role'] for x in r['riders'] if x['id'] == ident))
        summary['sprint_winner_types'][str(lap)] = dict(Counter(winners))
    summary['rider_laps'] = [dict(id=ident, role=next(x['role'] for x in results[0]['riders'] if x['id']==ident),
        gains=sum(x['gains'] for r in results for x in r['riders'] if x['id']==ident),
        losses=sum(x['losses'] for r in results for x in r['riders'] if x['id']==ident))
        for ident in range(1,17)]
    return summary


def write_csv(path, rows):
    if not rows:
        path.write_text('', encoding='utf-8')
        return
    with path.open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--races', type=int, default=100)
    parser.add_argument('--seed', type=int, default=1001)
    parser.add_argument('--workers', type=int, default=1)
    parser.add_argument('--out', type=Path, default=Path('results_tempo_100'))
    args = parser.parse_args()
    if args.races < 1 or args.workers < 1:
        parser.error('races and workers must be positive')
    seeds = range(args.seed, args.seed+args.races)
    if args.workers == 1:
        results = [run(seed) for seed in seeds]
    else:
        with ProcessPoolExecutor(args.workers) as pool:
            results = list(pool.map(run, seeds))
    args.out.mkdir(parents=True, exist_ok=True)
    summary = summarize(results)
    (args.out/'summary.json').write_text(json.dumps(summary, indent=2)+'\n', encoding='utf-8')
    (args.out/'races.json').write_text(json.dumps(results, separators=(',', ':'))+'\n', encoding='utf-8')
    for key in ('riders', 'energy35', 'lap_events'):
        write_csv(args.out/(key+'.csv'), [dict(seed=r['seed'], **x) for r in results for x in r[key]])
    write_csv(args.out/'sprints.csv', [dict(seed=r['seed'], lap=s['lap'], rank=i+1,
        id=ident, time_s=s['crossing_times'][i], points=s['awards'][i])
        for r in results for s in r['sprints'] for i, ident in enumerate(s['order'])])
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
