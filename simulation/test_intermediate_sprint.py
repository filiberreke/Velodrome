import ast
import inspect
import random
import unittest
from types import SimpleNamespace
from energy_core import Phys,PARS
from sim_f import Rider, integrate_speed
from intermediate_sprint import Experiment,place_probabilities
from run_intermediate_ab import race,audit,configure


def dummy(i,d=0):
    r=Rider(i,'tt',random.Random(i)); r.d=d
    return r


class JuryTests(unittest.TestCase):
    def test_line_order_lapped_rider_and_no_double_award(self):
        riders=[dummy(1,2502),dummy(2,2251),dummy(3,2501),dummy(4,2500.5)]
        jury=Experiment(riders,40,'A')
        before={1:(2498,100,0),2:(2248,100,0),3:(2497,100,0),4:(2497,100,0)}
        jury.observe(10,2,before,riders)
        self.assertEqual(jury.sprints[0]['order'],[1,2,3,4])
        self.assertEqual(jury.sprints[0]['awards'],[5,3,2,1])
        points=jury.points.copy()
        jury.observe(12,2,{r.id:(r.d,r.store,0) for r in riders},riders)
        self.assertEqual(points,jury.points)

    def test_ties_share_points_and_skip_next_place(self):
        riders=[dummy(1,2502),dummy(2,2502),dummy(3,2501),dummy(4,2500.5)]
        jury=Experiment(riders,40,'A')
        jury.observe(10,2,{1:(2498,100,0),2:(2498,100,0),3:(2497,100,0),4:(2497,100,0)},riders)
        self.assertEqual(jury.sprints[0]['awards'],[5,5,2,1])

    def test_lap_repeats_wraparound_and_disperse(self):
        riders=[dummy(1,1246),dummy(2,1249),dummy(3,1252),dummy(4,1496)]
        jury=Experiment(riders,40,'A')
        def judge(): jury.judge_laps(10,riders,{r.id:r.d for r in riders})
        judge(); judge()
        self.assertEqual(jury.gains[4],1)
        riders[-1].d+=250;judge()
        self.assertEqual(jury.gains[4],2)
        riders[-1].d-=250;judge()
        self.assertEqual(jury.losses[4],1)
        dispersed=[dummy(1,1000),dummy(2,1060),dummy(3,1120),dummy(4,1430)]
        jury=Experiment(dispersed,40,'A')
        jury.judge_laps(10,dispersed,{r.id:r.d for r in dispersed})
        self.assertEqual(jury.lap_events,[])

    def test_common_finish_double_points_and_lap_cutoff(self):
        riders=[dummy(1,10002),dummy(2,9503),dummy(3,9752)]
        jury=Experiment(riders,40,'A')
        # Isolate line/finish timing from the separately tested lap judge.
        # Three artificially colocated riders with different odometers otherwise
        # cause an intentional lap-credit correction before this passage.
        jury.judge_laps=lambda *args:None
        jury.observe(20,2,{1:(9998,100,0),2:(9499,100,0),3:(9747,100,0)},riders)
        self.assertEqual(jury.finish_time,21)
        self.assertEqual(jury.sprints[-1]['order'],[1,3])
        old={r.id:(r.d,100,0) for r in riders}; riders[1].d=9752
        jury.observe(22,30,old,riders)
        self.assertEqual(jury.sprints[-1]['order'],[1,3,2])
        self.assertEqual(jury.sprints[-1]['awards'],[10,6,4])
        self.assertTrue(all(e['time_s']<=21 for e in jury.lap_events))

    def test_energy_common_clock_interpolation(self):
        riders=[dummy(1,8752),dummy(2,8500)]
        riders[0].store=80;riders[1].store=60
        jury=Experiment(riders,40,'A')
        jury.observe(20,2,{1:(8748,100,0),2:(8496,80,0)},riders)
        self.assertEqual([x['w_j'] for x in jury.energy35],[90,70])
        self.assertEqual({x['time_s'] for x in jury.energy35},{21})


class TacticalTests(unittest.TestCase):
    def test_rank_forecast(self):
        self.assertGreater(place_probabilities(1,[20]*15)[0],.99)
        self.assertLess(sum(place_probabilities(20,[1]*15)),.01)
        self.assertAlmostEqual(sum(place_probabilities(10,[10]*3)),1)

    def test_hopeless_sprint_aborts_and_preserves_reserve(self):
        riders=[dummy(i,2400) for i in range(1,17)]
        for r in riders:r.v=12
        last=riders[-1]; last.d=2300;last.v=5
        jury=Experiment(riders,40,'B');jury.begin_step(riders);jury.active.add(last.id)
        target=jury.demand(last,800,riders,100)
        self.assertLessEqual(target,last.phys.cp)
        self.assertEqual(jury.decisions[-1]['action'],'abort')
        self.assertLess(sum(jury.decisions[-1][x] for x in ('p5','p3','p2','p1')),.23)

    def test_reserve_and_final_independence(self):
        riders=[dummy(i,2400-i) for i in range(1,17)]
        for r in riders:r.v=12
        a=Experiment(riders,40,'A');b=Experiment(riders,40,'B')
        a.begin_step(riders);b.begin_step(riders)
        r=riders[0]
        b.demand(r,300,riders,100)
        decision=b.decisions[-1]
        self.assertGreater(decision['reserve_j'],0)
        if decision['action']=='sprint':
            self.assertGreaterEqual(r.store-max(0,decision['target_w']-r.phys.cp)*2,decision['reserve_j'])
        for obj in (a,b):
            obj.sprints=[dict(lap=n,order=list(range(1,17))) for n in (10,20,30)]
            obj.head=9900
        self.assertEqual(a.demand(r,300,riders,100),b.demand(r,300,riders,100))

    def test_actual_physics_shared(self):
        self.assertIs(Rider.step_power.__globals__['Phys'],Phys)
        self.assertGreater(integrate_speed(16,1700,.6,2),16)


class IntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original_parameters=PARS.copy()
        cls.a=race((1001,'A'));cls.b=race((1001,'B'))

    @classmethod
    def tearDownClass(cls):
        PARS.clear(); PARS.update(cls.original_parameters)

    def test_unchanged_initial_profiles(self):
        self.assertEqual(self.a['initial'],self.b['initial'])
        self.assertEqual(len(self.a['initial']),16)
        self.assertEqual({x['role'] for x in self.a['initial']},{'tt','sprinter','attacker'})

    def test_complete_races_and_invariants(self):
        for result in (self.a,self.b): self.assertEqual(audit(result)['invariant_errors'],'')

    def test_determinism(self):
        self.assertEqual(self.b,race((1001,'B')))


if __name__=='__main__':unittest.main()
