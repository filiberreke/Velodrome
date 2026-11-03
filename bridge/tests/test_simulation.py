import asyncio
import json
import math
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

import test_bridge as base
from combined_mode import CommandError, CombinedMode
from simulation import RoadSimulation, grade_units, model, encode_simulation
from udp_commands import CommandProtocol, decode_command

class SimulationValidation(unittest.TestCase):
    def test_grade_validation_and_rounding(self):
        for value, expected in [(0, 0), (5.25, 525), (-3.5, -350), (-20, -2000), (20, 2000)]:
            self.assertEqual(grade_units(value), expected)
        for value in [True, None, '5', [], {}, -20.01, 20.01, .001, float('nan'), float('inf'), 10**500]:
            with self.subTest(value=str(value)[:30]), self.assertRaises(ValueError): grade_units(value)

    def test_exact_ftms_layout(self):
        self.assertEqual(encode_simulation(5.25, .004, .51), b'\x11' + struct.pack('<hhBB', 0, 525, 40, 51))
        self.assertEqual(encode_simulation(-3.5, .004, .51), b'\x11' + struct.pack('<hhBB', 0, -350, 40, 51))
        for values in [(400, .004, .51), (0, .03, .51), (0, .004, 3)]:
            with self.assertRaises(ValueError): encode_simulation(*values)

    def test_neutral_gear_and_virtual_power_model(self):
        road = RoadSimulation()
        grade, crr, cw = road.target(5, 4)
        self.assertAlmostEqual(grade, 5)
        self.assertAlmostEqual(crr, .004)
        self.assertAlmostEqual(cw, road.cw)
        # The model scales gravitational+rolling force by k and aero by k^3.
        for original_grade in [-20, -5, 0, 5, 20]:
            theta = math.atan(original_grade / 100)
            for factor in road.factors:
                effective_grade, crr, cw = model(original_grade, factor, road.crr, road.cw)
                effective_theta = math.atan(effective_grade / 100)
                self.assertAlmostEqual(math.sin(effective_theta) + crr * math.cos(effective_theta),
                                       factor * (math.sin(theta) + road.crr * math.cos(theta)))
                self.assertAlmostEqual(cw, road.cw * factor**3)
                encode_simulation(effective_grade, crr, cw)

    def test_config_rejects_silent_saturation(self):
        path = Path(__file__).parents[1] / 'simulation_config.json'
        config = json.loads(path.read_text())
        config['gear_factors'][-1] = 3
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / 'config.json'; file.write_text(json.dumps(config))
            with self.assertRaises(ValueError): RoadSimulation(config_path=file)

    def test_udp_schema(self):
        _, command, params = decode_command(base.packet('set_grade', grade_pct=5.25, ramp_pct_per_s=3))
        self.assertEqual(command, 'set_grade')
        self.assertEqual(params, {'grade_pct': 5.25, 'ramp_pct_per_s': 3})
        for raw in [base.packet('set_grade'), base.packet('set_grade', grade_pct=5, watts=100)]:
            with self.assertRaises(CommandError): decode_command(raw)

    def test_wrong_mode_unsupported_and_invalid_requests_are_atomic(self):
        c = base.ready(); c.simulation_supported = True
        for grade in [True, 21, -21, float('inf'), .001]:
            with self.assertRaises(CommandError): c.accept('set_grade', {'grade_pct': grade})
            self.assertEqual(c.desired_sim_backend, 'resistance')
        for rate in [0, 101, True, 10**500]:
            with self.assertRaises(CommandError): c.accept('set_grade', {'grade_pct': 5, 'ramp_pct_per_s': rate})
            self.assertEqual(c.grade_pct, 0)
        c.simulation_supported = False
        with self.assertRaises(CommandError) as err: c.accept('set_grade', {'grade_pct': 5})
        self.assertEqual(err.exception.code, 'simulation_unsupported')
        c.simulation_supported = True
        c.accept('set_mode', {'mode': 'ERG'})
        with self.assertRaises(CommandError) as err: c.accept('set_grade', {'grade_pct': 5})
        self.assertEqual(err.exception.code, 'wrong_mode')
        self.assertEqual(c.desired_mode, 'ERG')

    def test_udp_lease_dedup_and_owner(self):
        clock = base.Clock(); c = base.ready(clock); c.simulation_supported = True
        p = CommandProtocol(c, clock); t = base.Transport(); p.connection_made(t)
        owner = ('127.0.0.1', 23456)
        raw = base.packet('set_grade', grade_pct=0)
        p.datagram_received(raw, owner)
        self.assertEqual(json.loads(t.sent[-1][0])['type'], 'ack')
        self.assertEqual(c.owner, owner)  # Even flat simulation has road resistance.
        clock.advance(4); p.datagram_received(raw, owner)
        self.assertEqual(c.lease_until, 105)
        with self.assertRaises(CommandError): c.accept('set_grade', {'grade_pct': 1}, ('127.0.0.1', 23457))
        c.accept('heartbeat', source=owner)
        self.assertEqual(c.lease_until, 109)
        c.handle_command('sim')
        self.assertIsNone(c.owner)
        self.assertEqual(c.grade_pct, 0)
        self.assertEqual(c.desired_sim_backend, 'resistance')

class SimulationAsync(unittest.IsolatedAsyncioTestCase):
    def setup_road(self):
        self.clock = base.Clock(); self.c = base.ready(self.clock); self.c.simulation_supported = True
        self.controller = base.FakeController()
        self.sender = base.SimpleNamespace(connected=True, last_received=100, last_power=100)
        return self.c

    async def drive(self, seconds=.1):
        self.clock.advance(seconds)
        self.sender.last_power = self.sender.last_received = self.clock()
        await self.c.tick(self.controller, self.sender)

    async def test_capability_bit_13(self):
        for bit, expected in [(13, True), (14, False)]:
            c = CombinedMode()
            await c.check_supported(base.FakeClient(features=12 | (1 << bit)))
            self.assertEqual(c.simulation_supported, expected)

    async def test_grade_ramp_then_flat_keeps_simulation_and_gear(self):
        c = self.setup_road(); c.accept('set_grade', {'grade_pct': 1, 'ramp_pct_per_s': 2})
        await self.drive()
        self.assertEqual(self.controller.calls[:2], [b'\x01', b'\x00'])
        self.assertEqual(c.sim_backend, 'simulation')
        self.assertEqual(c.selected_gear(), 4)
        for _ in range(6): await self.drive()
        self.assertAlmostEqual(c.status()['confirmed_simulation']['grade_pct'], 1)
        self.assertEqual(c.applied_revision, c.revision)
        grades = [struct.unpack('<hhBB', x[1:])[1] / 100 for x in self.controller.calls if x[0] == 0x11]
        self.assertTrue(all(0 <= b - a <= .21 for a, b in zip(grades, grades[1:])))
        c.accept('set_grade', {'grade_pct': 0})
        for _ in range(7): await self.drive()
        self.assertEqual(c.sim_backend, 'simulation')
        self.assertEqual(c.status()['confirmed_simulation']['grade_pct'], 0)
        self.assertFalse(any(x[0] == 4 for x in self.controller.calls))

    async def test_gear_changes_simulation_not_target_resistance(self):
        c = self.setup_road(); c.accept('set_grade', {'grade_pct': 5, 'ramp_pct_per_s': 100})
        for _ in range(4): await self.drive()
        before = c.status()['confirmed_simulation']
        with patch('virtual_shift.time.monotonic', return_value=100): c.on_button('SHIFT_UP_RIGHT')
        self.assertEqual(c.selected_gear(), 5)
        for _ in range(4): await self.drive()
        after = c.status()['confirmed_simulation']
        self.assertGreater(after['grade_pct'], before['grade_pct'])
        self.assertGreater(after['cw'], before['cw'])
        self.assertEqual(c.status()['grade_pct'], 5)
        self.assertFalse(any(x[0] == 4 for x in self.controller.calls))

    async def test_return_to_legacy_and_erg(self):
        c = self.setup_road(); c.handle_command('grade 5 100')
        for _ in range(3): await self.drive()
        c.handle_command('sim'); await self.drive()
        self.assertEqual(c.sim_backend, 'resistance')
        self.assertEqual(self.controller.calls[-1][0], 4)
        c.handle_command('grade 3'); await self.drive()
        c.handle_command('erg'); await self.drive()
        self.assertEqual(c.mode, 'ERG')
        self.assertEqual(self.controller.calls[-1][0], 5)
        with self.assertRaises(CommandError): c.handle_command('grade 2')

    async def test_lease_and_feedback_timeout(self):
        for fault in ['lease', 'feedback']:
            c = self.setup_road()
            c.accept('set_grade', {'grade_pct': 2}, ('127.0.0.1', 23456) if fault == 'lease' else None)
            await self.drive()
            if fault == 'lease':
                await self.drive(5.1)
                self.assertEqual(c.last_error, 'udp_timeout')
            else:
                self.clock.advance(3.1)
                await c.tick(self.controller, self.sender)
                self.assertEqual(c.last_error, 'trainer_data_timeout')
            self.assertEqual(c.disabled, fault == 'lease')
            self.assertEqual(c.waiting_for_feedback, fault == 'feedback')
            self.assertTrue(c.release_confirmed)

    async def test_stop_during_simulation_mode_switch(self):
        c = self.setup_road(); c.handle_command('grade 5')
        self.controller.hook = lambda stage: c.request_stop() if stage == 'release' else None
        await self.drive()
        self.assertEqual(self.controller.calls, [b'\x01'])

    async def test_frequent_grade_updates_do_not_starve_mode_switch(self):
        c = self.setup_road(); c.handle_command('grade 5')
        def update(stage):
            if stage in ('release', 'initialize'):
                c.accept('set_grade', {'grade_pct': c.grade_pct + 1})
        self.controller.hook = update
        await self.drive()
        self.assertEqual(c.mode, 'SIM')
        self.assertEqual(c.sim_backend, 'simulation')
        self.assertEqual(c.grade_pct, 7)
        self.assertEqual(self.controller.calls[:2], [b'\x01', b'\x00'])
        self.assertEqual(self.controller.calls[-1][0], 0x11)

    async def test_long_stall_does_not_skip_grade_ramp(self):
        c = self.setup_road(); c.handle_command('grade 20')
        await self.drive()
        await self.drive(2)
        self.assertLessEqual(c.road.grade, .7)

    async def test_real_udp_grade(self):
        loop = asyncio.get_running_loop(); c = self.setup_road()
        server, _ = await loop.create_datagram_endpoint(lambda: CommandProtocol(c), local_addr=('127.0.0.1', 0))
        q = asyncio.Queue()
        class Receiver(asyncio.DatagramProtocol):
            def datagram_received(self, data, addr): q.put_nowait(json.loads(data))
        client, _ = await loop.create_datagram_endpoint(Receiver, local_addr=('127.0.0.1', 0))
        try:
            client.sendto(base.packet('set_grade', grade_pct=-2.5, ramp_pct_per_s=100), server.get_extra_info('sockname'))
            answer = await asyncio.wait_for(q.get(), 2)
            self.assertEqual(answer['type'], 'ack')
            self.assertEqual(answer['state']['grade_pct'], -2.5)
            for _ in range(3): await self.drive()
            self.assertEqual(c.status()['confirmed_simulation']['grade_pct'], -2.5)
        finally:
            client.close(); server.close()

