"""Clocked UDP-to-FTMS verification without a Bluetooth adapter."""
import json
import math
import unittest

import test_bridge as base
from combined_mode import CommandError
from udp_commands import CommandProtocol


class EliminationPushTrainer(unittest.IsolatedAsyncioTestCase):
    def setup_pair(self):
        self.clock = base.Clock()
        self.owner = ('127.0.0.1', 41321)
        self.sender = base.SimpleNamespace(connected=True, last_received=100.0, last_power=100.0)
        self.game, self.reference = base.ready(self.clock), base.ready(self.clock)
        self.trainer, self.reference_trainer = base.FakeController(), base.FakeController()
        self.protocol = CommandProtocol(self.game, self.clock)
        self.transport = base.Transport()
        self.protocol.connection_made(self.transport)
        for state in (self.game, self.reference):
            state.simulation_supported = True
            state.accept('set_grade', {'grade_pct': 1.25, 'aero_scale': 0.8}, self.owner)

    def receive(self, command, **params):
        raw = json.loads(base.packet(command, **params))
        raw['id'] = f"push-test-{len(self.transport.sent)}"
        self.protocol.datagram_received(json.dumps(raw).encode(), self.owner)
        response = json.loads(self.transport.sent[-1][0])
        self.assertTrue(response['ok'], response)

    async def frame(self):
        self.clock.advance(0.1)
        self.sender.last_received = self.sender.last_power = self.clock()
        await self.game.tick(self.trainer, self.sender)
        await self.reference.tick(self.reference_trainer, self.sender)

    @staticmethod
    def slope(state):
        return math.sin(math.atan(state.road.confirmed()['grade_pct'] / 100))

    async def test_clocked_push_grade_shift_base_grade_and_expiry(self):
        for mass, kmh in [(85, 30), (85, 40), (85, 45), (85, 50), (98, 33)]:
            with self.subTest(mass=mass, kmh=kmh):
                self.setup_pair()
                for _ in range(6):
                    await self.frame()
                extra = round(100 * 50 / (mass * 9.81 * (kmh / 3.6)), 2)
                start = self.clock()
                count = len(self.trainer.calls)
                self.receive('set_grade', grade_pct=1.25, aero_scale=0.8,
                             push_grade_pct=extra, push_duration_ms=5000)
                first = restored = None
                physical_watts = []
                for frame in range(52):
                    if frame in [10, 20, 30, 40, 50]:
                        self.receive('heartbeat')
                        self.reference.accept('heartbeat', source=self.owner)
                    if frame == 14:
                        self.receive('shift', direction=1)
                        self.reference.accept('shift', {'direction': 1}, self.owner)
                    if frame == 23:
                        self.receive('set_grade', grade_pct=-1.0, aero_scale=0.6,
                                     push_grade_pct=extra, push_duration_ms=2700)
                        self.reference.accept('set_grade', {'grade_pct': -1.0, 'aero_scale': 0.6}, self.owner)
                    await self.frame()
                    delta = self.slope(self.game) - self.slope(self.reference)
                    now = self.clock() - start
                    if delta > 1e-6 and first is None:
                        first = now
                    if first is not None and delta == 0 and restored is None:
                        restored = now
                    if 0.3 < now < 4.9:
                        physical_watts.append(delta * mass * 9.81 * kmh / 3.6)
                    self.assertEqual(self.game.road.confirmed()['cw'], self.reference.road.confirmed()['cw'])
                    self.assertEqual(self.game.road.confirmed()['crr'], self.reference.road.confirmed()['crr'])
                self.assertAlmostEqual(first, 0.1, places=5)
                self.assertGreaterEqual(restored, 4.999999)
                self.assertLessEqual(restored, 5.100001)
                self.assertTrue(all(abs(w - 50.0) < 1.5 for w in physical_watts), physical_watts)
                self.assertEqual(self.game.road.confirmed(), self.reference.road.confirmed())
                self.assertEqual(self.game.selected_gear(), 5)
                print('PUSH_TRAINER', json.dumps({
                    'mass_kg': mass, 'speed_kmh': kmh, 'push_grade_pct': extra,
                    'first_ftms_s': round(first, 3), 'restored_s': round(restored, 3),
                    'raised_resistance_s': round(restored - first, 3),
                    'combined_ftms_writes': len(self.trainer.calls) - count,
                    'steady_w_min': round(min(physical_watts), 2), 'steady_w_max': round(max(physical_watts), 2),
                }))

    async def test_pause_disconnect_and_stop_clear_transient_load(self):
        for action in ['pause', 'disconnect', 'watchdog', 'stop']:
            self.setup_pair()
            self.receive('set_grade', grade_pct=0.0, push_grade_pct=0.72, push_duration_ms=5000)
            for _ in range(7):
                await self.frame()
            self.assertGreater(self.game.road.confirmed()['grade_pct'], 0)
            if action == 'pause':
                self.receive('set_target_power', watts=0)
            elif action == 'disconnect':
                self.game.suspend('trainer_data_timeout')
            elif action == 'watchdog':
                self.clock.advance(5)
            else:
                self.receive('stop')
            await self.frame()
            self.assertTrue(self.game.release_confirmed)
            self.assertEqual(self.game.push_until, 0)
            self.assertEqual(self.game.mode, 'RELEASED')
            self.assertEqual(self.trainer.calls[-1], b'\x01')

    async def test_rejects_invalid_pairs_without_changing_target(self):
        self.setup_pair()
        for grade, duration in [(0.5, 0), (0.0, 100), (0.5, True), (0.5, 5001),
                                (1.51, 100), (-0.5, 100), (float('nan'), 100)]:
            with self.assertRaises(CommandError):
                self.game.accept('set_grade',
                                 {'grade_pct': -10, 'push_grade_pct': grade, 'push_duration_ms': duration},
                                 self.owner)
            self.assertEqual(self.game.grade_pct, 1.25)
            self.assertEqual(self.game.push_until, 0)
