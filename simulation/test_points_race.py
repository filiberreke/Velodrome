"""Regression checks for the points-race reference adapter."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from points_race import Jury, simulate_points, FINAL, INTERMEDIATE


class PointsRaceChecks(unittest.TestCase):
    def test_rewards(self):
        self.assertEqual(INTERMEDIATE, (5, 3, 2, 1))
        self.assertEqual(FINAL, (10, 6, 4, 2))

    def test_test_distance(self):
        result = simulate_points(laps=10, riders=16, seed=42)
        self.assertTrue(result["completed"])
        self.assertEqual(len(result["points"]), 16)
        self.assertGreater(result["elapsed"], 0)

    def test_repeatable(self):
        self.assertEqual(simulate_points(laps=10, riders=16, seed=11), simulate_points(laps=10, riders=16, seed=11))

    def test_field_sizes(self):
        for riders in (12, 16):
            with self.subTest(riders=riders):
                result = simulate_points(laps=10, riders=riders, seed=3)
                self.assertTrue(result["completed"])
                self.assertEqual(len(result["types"]), riders)
                self.assertEqual(len(result["standings"]), riders)

    def test_clock_by_group_not_fastest(self):
        j = Jury(5, laps=10)
        j.update([2500, 2250, 2251, 2252, 2253])
        self.assertEqual(j.reference_laps, 9)

    def test_no_award_for_group_switch(self):
        j = Jury(5)
        j.update([0, 0, 0, 0, 0])
        j.update([270, 270, 270, 0, 0])
        self.assertEqual(j.lap_balance, [0]*5)

    def test_no_double_count_on_stationary_step(self):
        j = Jury(5)
        j.update([0]*5)
        j.update([260, 0, 0, 0, 0])
        first = j.lap_balance[:]
        j.update([260, 0, 0, 0, 0])
        self.assertEqual(j.lap_balance, first)


if __name__ == "__main__":
    unittest.main()
