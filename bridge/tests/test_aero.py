import json
import unittest
import test_bridge as base
from combined_mode import CommandError
from udp_commands import CommandProtocol

class AeroValidation(unittest.TestCase):
    def test_invalid_scale_is_atomic(self):
        c = base.ready(); c.simulation_supported = True
        for value in [-.01, 1.01, True, None, '0.5', float('nan'), float('inf'), 10**500]:
            with self.subTest(value=str(value)[:20]), self.assertRaises(CommandError):
                c.accept('set_grade', {'grade_pct': 4, 'aero_scale': value})
            self.assertEqual(c.grade_pct, 0)
            self.assertEqual(c.aero_scale, 1)
            self.assertEqual(c.desired_sim_backend, 'resistance')

    def test_udp_scale_and_legacy_default(self):
        c = base.ready(); c.simulation_supported = True
        p = CommandProtocol(c); t = base.Transport(); p.connection_made(t)
        p.datagram_received(base.packet('set_grade', grade_pct=2, aero_scale=.31), ('127.0.0.1', 23456))
        state = json.loads(t.sent[-1][0])['state']
        self.assertEqual(state['aero_scale'], .31)
        self.assertTrue(state['aero_scale_supported'])
        c.accept('set_grade', {'grade_pct': 0})
        self.assertEqual(c.aero_scale, 1)

class AeroFTMS(unittest.IsolatedAsyncioTestCase):
    async def test_draft_only_changes_aero_and_is_ramped(self):
        clock = base.Clock(); c = base.ready(clock); c.simulation_supported = True
        controller = base.FakeController()
        sender = base.SimpleNamespace(connected=True, last_received=100, last_power=100)
        async def drive():
            clock.advance(.1); sender.last_received = sender.last_power = clock()
            await c.tick(controller, sender)
        c.accept('set_grade', {'grade_pct': 5, 'ramp_pct_per_s': 100})
        for _ in range(5): await drive()
        before = c.status()['confirmed_simulation']
        c.accept('set_grade', {'grade_pct': 5, 'aero_scale': .31})
        await drive()
        first = c.status()['confirmed_simulation']
        self.assertGreater(first['cw'], round(c.road.cw * .31, 2))
        for _ in range(5): await drive()
        after = c.status()['confirmed_simulation']
        self.assertEqual(after['grade_pct'], before['grade_pct'])
        self.assertEqual(after['crr'], before['crr'])
        self.assertEqual(after['cw'], round(c.road.cw * .31, 2))
        self.assertEqual(c.applied_revision, c.revision)
        c.accept('set_grade', {'grade_pct': 5, 'aero_scale': 1})
        for _ in range(5): await drive()
        self.assertEqual(c.status()['confirmed_simulation'], before)
        self.assertFalse(any(call[0] == 4 for call in controller.calls))
