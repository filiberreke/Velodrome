"""Summarize completed, seed-matched race measurements in Markdown."""
import argparse
from collections import Counter
import json
import math
from pathlib import Path
from statistics import mean, median


def read(path):
    rows = [json.loads(line) for line in path.read_text().splitlines()]
    return {(row['count'], row['policy'], row['seed']): row for row in rows if row['complete']}


def fmt(value, digits=2):
    return '—' if value is None else f'{value:.{digits}f}'


def blocks(rows, rider=None):
    return [block for row in rows for block in row['blocks'] if rider is None or block[0] == rider]


def stats(rows):
    durations = sorted(block[1] for block in blocks(rows))
    player = blocks(rows, 0)
    escaped = [block[1] for block in player if block[2]]
    return [len(durations), fmt(mean(durations) if durations else None),
            fmt(median(durations) if durations else None),
            fmt(durations[math.ceil(0.95 * len(durations)) - 1] if durations else None),
            fmt(max(durations, default=None)),
            *(sum(d > limit for d in durations) for limit in [5, 10, 30, 60]),
            sum(row['eliminated_blocked'] for row in rows),
            fmt(sum(row['exits'] for row in rows) / sum(row['race_laps'] for row in rows)),
            len(player), fmt(mean(escaped) if escaped else None),
            fmt(100 * len(escaped) / len(player) if player else None, 1)]


def race_stats(rows):
    seconds = sum(row['rider_seconds'] for row in rows)
    delivered = sum(row['delivered_j'] for row in rows)
    penalty = sum(row['penalty_j'] for row in rows)
    reserve = [w for row in rows for w in row['wprime'][1:]]
    return [fmt(mean(row['duration'] for row in rows), 1), fmt(3.6 * sum(row['speed_integral'] for row in rows) / seconds),
            fmt(delivered / seconds), fmt((delivered - penalty) / seconds), fmt(penalty, 1), fmt(mean(reserve), 1),
            fmt(mean(row['runtime'] for row in rows), 1), sum(row['overlap_samples'] for row in rows),
            sum(row['boundary_samples'] for row in rows)]


def push_stats(rows):
    events = [event for row in rows for event in row.get('pushes', [])]
    rejected = Counter(event['rejection'] for event in events if event['rejection'])
    successes = [event for event in events if not event['rejection']]
    lengths = Counter(len(event['displaced']) for event in successes)
    humans = sum(event['rider'] == 0 for event in successes)
    near_sprint = [event for event in successes if 0 <= event['sprint_m'] <= 115]
    passive = sum(0 in event['displaced'] for event in successes)
    cascades = [length for length, n in lengths.items() for _ in range(n) if length > 1]
    return [len(events), len(successes), sum(rejected.values()), len(successes) - humans, humans, passive,
            len(near_sprint), sum(event['rider'] != 0 and event not in near_sprint for event in successes),
            len(cascades), fmt(mean(cascades) if cascades else None), max(cascades, default=0),
            ', '.join(f'{length}×{n}' for length, n in sorted(lengths.items())) or '—',
            rejected['edge'], rejected['busy'],
            fmt(len(successes) / len(rows)), fmt(len(successes) / sum(row['count'] for row in rows))]


def table(headers, rows):
    print('| ' + ' | '.join(headers) + ' |')
    print('| ' + ' | '.join('---' for _ in headers) + ' |')
    for row in rows:
        print('| ' + ' | '.join(map(str, row)) + ' |')
    print()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('baseline', type=Path)
    parser.add_argument('feature', type=Path)
    args = parser.parse_args()
    baseline, feature = read(args.baseline), read(args.feature)
    keys = sorted(baseline.keys() & feature.keys())
    scenarios = list(dict.fromkeys(key[:2] for key in keys))
    grouped = []
    for count, policy in scenarios:
        group = [key for key in keys if key[:2] == (count, policy)]
        grouped.append((count, policy, [baseline[key] for key in group], [feature[key] for key in group]))
    print(f'{len(baseline)} basiswedstrijden en {len(feature)} featurewedstrijden voltooid. '
          f'{len(keys)} gematchte paren in de tabellen.\n')
    print('### Blokkeringen en uitwijken\n')
    table(['Renners', 'Besturing 0', 'Versie', 'Races', 'Events', 'Gem. s', 'Mediaan s', 'P95 s',
           'Max. s', '>5 s', '>10 s', '>30 s', '>60 s', 'Speler afgevallen tijdens blok',
           'Uitwijken/ronde', 'Spelerblokken', 'Speler bevrijd gem. s', 'Speler bevrijd %'],
          [(count, policy, version, len(rows), *stats(rows)) for count, policy, b, f in grouped
           for version, rows in [('basis', b), ('duwen', f)]])
    print('### Duwen en cascades\n')
    table(['Renners', 'Besturing 0', 'Pogingen', 'Geslaagd', 'Geweigerd', 'AI', 'Speler',
           'Speler passief', 'Binnen 115 m', 'AI buiten venster', 'Cascades', 'Gem. lengte',
           'Max. lengte', 'Passieven × aantal', 'Rand', 'Conflict', 'Duwen/race', 'Duwen/renner'],
          [(count, policy, *push_stats(f)) for count, policy, _, f in grouped])
    print('### Energie, baanposities en rekentijd\n')
    table(['Renners', 'Besturing 0', 'Versie', 'Duur s', 'km/u', 'Geleverd W', 'Aandrijving W',
           'Duwkost J totaal', 'AI W′ bij finish J', 'Rekentijd s', 'Overlappende paren × ticks',
           'Buitenrand × ticks'],
          [(count, policy, version, *race_stats(rows)) for count, policy, b, f in grouped
           for version, rows in [('basis', b), ('duwen', f)]])
    print(f"Identieke afvallingsvolgorde in "
          f"{sum(baseline[key]['elimination_order'] == feature[key]['elimination_order'] for key in keys)} "
          f"van {len(keys)} paren. De volgorde per wedstrijd staat in de JSONL-bestanden.")


if __name__ == '__main__':
    main()
