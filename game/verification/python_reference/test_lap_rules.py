import unittest
from collections import Counter
from sim_f import run,LAP,road_power,integrate_speed

class TestLapRules(unittest.TestCase):
    def test_physics_no_arbitrary_speed_cap(self):
        self.assertGreater(integrate_speed(16,1700,.6,2),16)
    def test_lap_gain_wins_race(self):
        row,_,_,riders,_,_,_,_=run(seed=1049,count=8,laps=25,variant='L',final750=True,no_speed_cap=True,breakaway_v=True,break_follow=True,real_laps=True)
        self.assertGreater(row['lap_gains'],0)
        self.assertTrue(row['lap_gain_winner'])
        winner=next(x for x in riders if x['id']==row['finish_winner_id'])
        self.assertEqual(winner['lap_credits'],1)
    def test_no_multiple_awards_same_rider(self):
        for seed in (1049,1065,1193):
            row,_,_,riders,_,_,_,_=run(seed=seed,count=8 if seed%2 else 12,laps=25,variant='L',final750=True,no_speed_cap=True,breakaway_v=True,break_follow=True,real_laps=True)
            ids=[x['id'] for x in row['lap_gain_events']]
            self.assertEqual(len(ids),len(set(ids)))
    def test_rider_can_draft_after_lap_gain(self):
        row,_,_,riders,_,_,_,_=run(seed=1049,count=8,laps=25,variant='L',final750=True,no_speed_cap=True,breakaway_v=True,break_follow=True,real_laps=True)
        self.assertTrue(any(x['lap_credits'] and x['lap_draft_s']>0 for x in riders))
if __name__=='__main__':unittest.main()
