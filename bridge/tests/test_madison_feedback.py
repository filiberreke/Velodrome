"""Madison pulse targets through the existing serialized FTMS writer, no BLE."""
import unittest

import test_bridge as base


class MadisonFeedbackFTMS(unittest.IsolatedAsyncioTestCase):
    async def test_opposite_pulses_restore_road_and_keep_aero(self):
        clock = base.Clock()
        control = base.ready(clock)
        control.simulation_supported = True
        trainer = base.FakeController()
        sender = base.SimpleNamespace(connected=True, last_received=100, last_power=100)

        async def drive(grade):
            control.accept('set_grade', {'grade_pct': grade,
                                        'ramp_pct_per_s': 100, 'aero_scale': 1})
            for _ in range(5):
                clock.advance(.1)
                sender.last_received = sender.last_power = clock()
                await control.tick(trainer, sender)
            return control.status()['confirmed_simulation']

        baseline = await drive(0)
        for peak in (12, -12, 3, -3, 20, -20):
            with self.subTest(peak=peak):
                applied = await drive(peak)
                self.assertAlmostEqual(applied['grade_pct'], peak)
                self.assertEqual(applied['cw'], baseline['cw'])
                restored = await drive(0)
                self.assertEqual(restored, baseline)
                self.assertEqual(control.applied_revision, control.revision)
        self.assertTrue(any(packet[0] == 0x11 for packet in trainer.calls))
        self.assertFalse(any(packet[0] == 0x04 for packet in trainer.calls))
        # Stop while force is applied must release, rather than request flat SIM.
        await drive(12)
        control.accept('set_target_power', {'watts': 0})
        clock.advance(.1)
        await control.tick(trainer, sender)
        self.assertEqual(control.mode, 'RELEASED')
        self.assertTrue(control.release_confirmed)
