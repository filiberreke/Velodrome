import unittest
from types import SimpleNamespace
from points_jury import Jury
from points_engine import run
from sim_f import Rider, integrate_speed
from energy_core import Phys


def rider(ident, distance=0):
    return SimpleNamespace(id=ident, role='tt', d=distance, store=100., store_max=100.,
                           phys=SimpleNamespace(cp=270., fatigue=0.), finished_at=None)


class JuryTests(unittest.TestCase):
    def test_interpolated_sprint_and_lapped_rider(self):
        riders = [rider(1, 2502), rider(2, 2251), rider(3, 2501), rider(4, 2500.5)]
        jury = Jury(riders)
        before = {1: (2498,100,0), 2: (2248,100,0), 3: (2497,100,0), 4: (2497,100,0)}
        jury.observe(10, 2, before, riders)
        self.assertEqual(jury.sprints[0]['order'], [1,2,3,4])
        self.assertEqual(jury.sprints[0]['awards'], [5,3,2,1])
        self.assertEqual(jury.sprints[0]['crossing_times'][0], 11)
        scores = jury.points.copy()
        jury.observe(12, 2, {r.id: (r.d,100,0) for r in riders}, riders)
        self.assertEqual(jury.points, scores)

    def test_lapped_crossing_before_sprint_opens_is_excluded(self):
        riders = [rider(1,2502), rider(2,2254), rider(3,2501)]
        jury = Jury(riders)
        jury.observe(10, 2, {1:(2498,100,0),2:(2249,100,0),3:(2497,100,0)}, riders)
        self.assertNotIn(2, jury.sprints[0]['order'])

    def test_repeated_lap_gains_and_loss_recovery(self):
        riders = [rider(i, 1000+2*i) for i in range(1,6)]
        jury = Jury(riders)
        def judge(distance):
            riders[-1].d = distance
            jury.judge_laps(10, riders, {r.id:r.d for r in riders})
        judge(1252)
        self.assertEqual(jury.gains[5], 1)
        judge(1252)
        self.assertEqual(jury.gains[5], 1)
        judge(1502)
        self.assertEqual(jury.gains[5], 2)
        judge(1250)
        self.assertEqual(jury.losses[5], 1)
        self.assertEqual(jury.points[5], 20)

    def test_bunch_wraps_start_line(self):
        riders = [rider(1,1246),rider(2,1249),rider(3,1252),rider(4,1496)]
        jury=Jury(riders)
        jury.judge_laps(10,riders,{r.id:r.d for r in riders})
        self.assertEqual(jury.gains[4],1)

    def test_dispersed_field_has_no_invented_main_bunch(self):
        riders=[rider(1,1000),rider(2,1060),rider(3,1120),rider(4,1430)]
        jury=Jury(riders)
        jury.judge_laps(10,riders,{r.id:r.d for r in riders})
        self.assertEqual(jury.lap_events,[])

    def test_final_is_common_clock_and_double_points(self):
        riders=[rider(1,10002),rider(2,9503),rider(3,9752)]
        jury=Jury(riders)
        before={1:(9998,100,0),2:(9499,100,0),3:(9748,100,0)}
        jury.observe(20,2,before,riders)
        self.assertEqual(jury.finish_time,21)
        # Rider 2 crossed before the leader, so must cross the next physical line.
        self.assertEqual(jury.sprints[-1]['order'],[1,3])
        self.assertEqual(jury.sprints[-1]['awards'],[10,6])
        old={r.id:(r.d,100,0) for r in riders}
        riders[1].d=9752
        jury.observe(22,30,old,riders)
        self.assertEqual(jury.sprints[-1]['order'],[1,3,2])
        self.assertEqual(jury.sprints[-1]['awards'],[10,6,4])

    def test_lap35_same_clock_interpolation(self):
        riders=[rider(1,8752),rider(2,8500)]
        riders[0].store=80; riders[1].store=60
        jury=Jury(riders)
        jury.observe(20,2,{1:(8748,100,0),2:(8496,80,0)},riders)
        self.assertEqual([x['w_j'] for x in jury.energy35],[90,70])
        self.assertEqual({x['time_s'] for x in jury.energy35},{21})


class IntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.race=run(1001)

    def test_full_race_invariants(self):
        r=self.race
        self.assertEqual(len(r['riders']),16)
        self.assertEqual([s['lap'] for s in r['sprints']],[10,20,30,40])
        for sprint in r['sprints']:
            self.assertEqual(len(set(sprint['order'])),16)
            self.assertEqual(sprint['crossing_times'],sorted(sprint['crossing_times']))
        self.assertEqual(len(r['energy35']),16)
        self.assertEqual(len({x['time_s'] for x in r['energy35']}),1)
        self.assertTrue(all(0<=x['w_pct']<=100 for x in r['energy35']))
        self.assertEqual(sum(x['points'] for x in r['riders']),55+20*sum(x['net_laps'] for x in r['riders']))
        self.assertTrue(all(x['time_s']<=r['finish_time_s'] for x in r['lap_events']))
        order=sorted(r['riders'],key=lambda x:(-x['points'],x['final_place']))
        self.assertEqual([x['id'] for x in order],r['standings'])

    def test_seed_reproducibility(self):
        self.assertEqual(self.race,run(1001))

    def test_physics_are_shared_and_uncapped(self):
        self.assertIs(Rider.step_power.__globals__['Phys'],Phys)
        self.assertGreater(integrate_speed(16,1700,.6,2),16)

    def test_time_trialists_actively_try(self):
        tt=[x for x in self.race['riders'] if x['role']=='tt']
        self.assertGreater(sum(x['attacks'] for x in tt),0)
        self.assertTrue(all(x['sprint_effort_steps']>0 for x in tt))


if __name__=='__main__':
    unittest.main()
