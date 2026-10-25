import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'simulator'))
from simulate import sprint_laps,score,simulate,validate,speed_step,tt_power

class SimulationChecks(unittest.TestCase):
    def test_sprint_calendar(self):
        self.assertEqual(sprint_laps(15),[5,10,15]); self.assertEqual(sprint_laps(25),[5,10,15,20,25]); self.assertEqual(len(sprint_laps(50)),10)
    def test_points(self):
        p=[0,0,0,0]; score(p,[2,1,0,3],False); score(p,[3,1,0,2],True)
        self.assertEqual(p,[3,6,4,6])
    def test_power_curve(self):
        self.assertEqual(round(tt_power(30)),600); self.assertEqual(round(tt_power(300)),350)
    def test_speed_bound(self):
        self.assertLessEqual(speed_step(25,4000,.5),26)
        self.assertGreaterEqual(speed_step(0,0,.5),0)
    def test_sprint_and_laps(self):
        for laps in (15,25,50):
            for riders in (6,8,12):
                for mode in ('scratch','points'):
                    with self.subTest(laps=laps,riders=riders,mode=mode):
                        r=simulate(laps,riders,80,42,mode)
                        validate(r)
    def test_repeatability(self):
        a=simulate(15,8,80,101,'points'); b=simulate(15,8,80,101,'points')
        self.assertEqual(a['finish'],b['finish']); self.assertEqual(a['points'],b['points'])

if __name__=='__main__': unittest.main()
