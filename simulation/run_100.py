"""Run 100 deterministic 40-lap points races and export a CSV summary."""
import argparse
import csv
from collections import Counter
from pathlib import Path
from points_race import simulate_points

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--races", type=int, default=100)
    parser.add_argument("--laps", type=int, default=40)
    parser.add_argument("--riders", type=int, default=16)
    parser.add_argument("--include-player", action="store_true", help="Include fixed-power player for comparison")
    parser.add_argument("--out", default="simulation/results_40laps_100_16_ai.csv")
    args = parser.parse_args()
    output = Path(args.out)
    output.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for seed in range(args.races):
        race = simulate_points(laps=args.laps, riders=args.riders, seed=seed, include_player=args.include_player)
        winner = race["types"][race["standings"][0]]
        gains = sum(event[0] == "gain" for event in race["events"])
        losses = sum(event[0] == "loss" for event in race["events"])
        sprints = sum(event[0] == "sprint" for event in race["events"])
        rows.append([seed, race["completed"], round(race["elapsed"], 2),
                     winner, gains, losses, sprints,
                     ";".join(map(str, race["lap_balance"])),
                     ";".join(map(str, race["points"]))])
    with output.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["seed", "completed", "duration_s", "winner_type",
                         "gains", "losses", "sprints", "lap_balances", "points"])
        writer.writerows(rows)
    wins = Counter(row[3] for row in rows)
    print("Completed:", sum(row[1] for row in rows), "/", len(rows))
    print("Wins:", dict(wins))
    print("Lap gains:", sum(row[4] for row in rows))
    print("Lap losses:", sum(row[5] for row in rows))
    print("Saved:", output)

if __name__ == "__main__":
    main()
