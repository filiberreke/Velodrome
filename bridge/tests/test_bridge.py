"""Hardware-free behavior, FTMS serialization and real loopback UDP tests."""
import asyncio
import ast
import json
import importlib.util
import logging
from pathlib import Path
import struct
import sys
import time
from types import SimpleNamespace, ModuleType
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from combined_mode import CombinedMode, CommandError
from erg_protocol import encode_target_power, parse_power_range, POWER_RANGE
from resistance import ResistanceController, FEATURE, CONTROL_POINT
from udp_commands import CommandProtocol, decode_command, CACHE_SIZE
from hr_bridge import HeartRateState
from ftms import parse_bike_data

logging.disable(logging.CRITICAL)

class Clock:
    def __init__(self): self.now = 100.0
    def __call__(self): return self.now
    def advance(self, seconds): self.now += seconds

class Transport:
    def __init__(self): self.sent = []
    def sendto(self, raw, addr): self.sent.append((raw, addr))

def packet(command='status', id='test-1', **params):
    return json.dumps(dict(type='command', v=1, id=id, command=command, **params)).encode()

def ready(clock=None, limits=(0, 1500, 1)):
    c = CombinedMode(clock=clock or Clock())
    c.started = c.power_supported = True
    c.power_range = limits
    c.range_state = 'known' if limits else 'unavailable'
    return c

class FakeController:
    def __init__(self):
        self.active = True
        self.calls = []
        self.hook = None
    async def release(self):
        self.calls.append(b'\x01')
        self.active = False
        if self.hook: self.hook('release')
    async def initialize(self):
        self.calls.append(b'\x00')
        self.active = True
        if self.hook: self.hook('initialize')
    async def command(self, data):
        self.calls.append(data)
        if self.hook: self.hook('command')
    async def set_level(self, level):
        self.calls.append(b'\x04' + struct.pack('<h', round(level * 10)))

class FakeClient:
    def __init__(self, raw=struct.pack('<hhH', 0, 1500, 1), present=True, features=12):
        self.raw, self.features = raw, features
        self.services = SimpleNamespace(get_characteristic=lambda uuid: object() if present else None)
        self.callback = None
        self.writes = []
        self.subscriptions = 0
        self.inflight = self.max_inflight = 0
        self.result = 1
    async def read_gatt_char(self, uuid):
        if uuid == FEATURE: return struct.pack('<II', 0, self.features)
        if isinstance(self.raw, Exception): raise self.raw
        return self.raw
    async def start_notify(self, uuid, callback):
        self.callback = callback
        self.subscriptions += 1
    async def write_gatt_char(self, uuid, data, response):
        self.inflight += 1
        self.max_inflight = max(self.inflight, self.max_inflight)
        self.writes.append(bytes(data))
        try:
            await asyncio.sleep(0.001)
            self.callback(None, bytes([0x80, data[0], self.result]))
        finally:
            self.inflight -= 1

class ValidationTests(unittest.TestCase):
    def test_encoding_boundaries(self):
        for value in (0, 1, 250, 1300):
            self.assertEqual(encode_target_power(value), b'\x05' + struct.pack('<h', value))
        for value in (-1, 1301, True, 100.0, '100', None):
            with self.assertRaises(ValueError): encode_target_power(value)

    def test_range_and_increment_without_clamping(self):
        c = ready(limits=(50, 1000, 5))
        for value in (0, 50, 250, 1000): c.validate_target(value)
        for value in (49, 51, 1001, 1300):
            with self.assertRaises(CommandError) as err: c.accept('set_target_power', {'watts': value})
            self.assertEqual(err.exception.code, 'unsupported_power')
            self.assertEqual(c.target_w, 0)

    def test_malformed_range(self):
        for raw in (b'', b'12345', struct.pack('<hhH', 100, 50, 1), struct.pack('<hhH', 0, 1300, 0)):
            with self.assertRaises(ValueError): parse_power_range(raw)

    def test_invalid_rates_do_not_mutate(self):
        c = ready()
        for rate in (0, -1, 10001, 10**500, True, '300', float('nan'), float('inf')):
            with self.assertRaises(CommandError):
                c.accept('set_target_power', {'watts': 1300, 'ramp_w_per_s': rate})
            self.assertEqual(c.target_w, 0)

    def test_strict_json(self):
        bad = [b'', b'x' * 1025, b'\xff', b'[]', b'null',
               b'{"id":"a","id":"b"}', b'{"x":NaN}', b'{"x":Infinity}',
               packet(id='space id'), packet(vv=1), packet('unknown'),
               b'{"type":"command","v":true,"id":"a","command":"status"}',
               packet('set_target_power'), packet('set_mode', mode='SIM', unknown=1)]
        for raw in bad:
            with self.subTest(raw=raw[:70]), self.assertRaises(CommandError): decode_command(raw)

    def test_console_and_udp_share_state(self):
        c = ready()
        c.accept('set_target_power', {'watts': 1300, 'ramp_w_per_s': 1500}, ('127.0.0.1', 1000))
        self.assertEqual(c.desired_mode, 'SIM')
        c.handle_command('erg')
        self.assertEqual(c.desired_mode, 'ERG')
        c.handle_command('target 0')
        self.assertEqual(c.target_w, 0)
        c.handle_command('sim')
        self.assertEqual(c.selected_gear(), 4)
        c.handle_command('stop')
        with self.assertRaises(CommandError): c.handle_command('erg')

    def test_lease_owner_and_console_override(self):
        clock = Clock(); c = ready(clock)
        owner = ('127.0.0.1', 1000)
        c.accept('set_mode', {'mode': 'ERG'}, owner)
        c.accept('set_target_power', {'watts': 200}, owner)
        with self.assertRaises(CommandError): c.accept('set_target_power', {'watts': 200}, ('127.0.0.1', 1001))
        clock.advance(4)
        c.accept('heartbeat', source=owner)
        self.assertEqual(c.lease_until, 109)
        c.handle_command('sim')
        self.assertIsNone(c.owner)
        c.accept('set_mode', {'mode': 'ERG'}, owner)
        c.accept('set_target_power', {'watts': 220}, owner)
        clock.advance(6)
        with self.assertRaises(CommandError): c.accept('heartbeat', source=owner)
        self.assertFalse(c.disabled)
        self.assertEqual(c.target_w, 0)
        self.assertTrue(c.reconnect_ready)

    def test_fresh_race_may_reset_only_its_own_lease(self):
        clock = Clock(); c = ready(clock)
        owner = ('127.0.0.1', 1000)
        other = ('127.0.0.1', 1001)
        c.accept('set_mode', {'mode': 'ERG'}, owner)
        c.accept('set_target_power', {'watts': 265}, owner)
        self.assertTrue(c.accept('status', source=owner)['udp_owned_by_requester'])
        self.assertFalse(c.accept('status', source=other)['udp_owned_by_requester'])
        with self.assertRaises(CommandError) as error:
            c.accept('set_target_power', {'watts': 0}, other)
        self.assertEqual(error.exception.code, 'control_busy')
        clock.advance(6)
        # Even after expiry the previous owner may release, but cannot renew load.
        c.accept('set_target_power', {'watts': 0}, owner)
        self.assertFalse(c.disabled)
        self.assertIsNone(c.owner)
        self.assertEqual(c.target_w, 0)
        self.assertTrue(c.reconnect_ready)

    def test_udp_cache_errors_conflicts_and_no_lease_renewal(self):
        clock = Clock(); c = ready(clock)
        protocol = CommandProtocol(c, clock); transport = Transport(); protocol.connection_made(transport)
        addr = ('127.0.0.1', 12345)
        raw = packet('set_mode', mode='ERG')
        protocol.datagram_received(raw, addr)
        first = transport.sent[-1][0]
        protocol.datagram_received(packet('set_target_power', id='new-target', watts=200), addr)
        clock.advance(4)
        protocol.datagram_received(raw, addr)
        self.assertEqual(transport.sent[-1][0], first)
        self.assertEqual(c.lease_until, 105)
        protocol.datagram_received(packet('set_mode', mode='SIM'), addr)
        self.assertEqual(json.loads(transport.sent[-1][0])['code'], 'id_conflict')
        bad = packet('set_target_power', id='bad', watts=1301)
        protocol.datagram_received(bad, addr)
        error = transport.sent[-1][0]
        protocol.datagram_received(bad, addr)
        self.assertEqual(error, transport.sent[-1][0])
        before = len(transport.sent)
        protocol.datagram_received(packet(), ('192.0.2.1', 1000))
        self.assertEqual(len(transport.sent), before)

    def test_bounded_cache_and_flood(self):
        clock = Clock(); c = ready(clock); p = CommandProtocol(c, clock); t = Transport(); p.connection_made(t)
        addr = ('127.0.0.1', 1000)
        for n in range(200): p.datagram_received(packet(id=str(n)), addr)
        self.assertEqual(len(t.sent), 100)
        p.cache = {str(n): (1000, '', b'') for n in range(CACHE_SIZE)}
        clock.advance(1)
        p.datagram_received(packet(id='full'), addr)
        self.assertEqual(json.loads(t.sent[-1][0])['code'], 'server_busy')
        p.datagram_received(packet('stop', id='stop'), addr)
        self.assertTrue(c.disabled)

    def test_heart_rate_and_bike_data(self):
        clock = Clock(); hr = HeartRateState(clock)
        self.assertTrue(hr.update(140))
        self.assertFalse(hr.update(True))
        clock.advance(5.1)
        self.assertIsNone(hr.current_bpm())
        raw = struct.pack('<HHHh', (1 << 2) | (1 << 6), 3000, 180, 250)
        self.assertEqual(parse_bike_data(raw), {'speed_kmh': 30, 'cadence_rpm': 90, 'power_w': 250})

class AsyncTests(unittest.IsolatedAsyncioTestCase):
    def setup_mode(self, limits=(0, 1500, 1)):
        self.clock = Clock(); self.mode = ready(self.clock, limits)
        self.controller = FakeController()
        self.sender = SimpleNamespace(connected=True, last_received=100.0, last_power=100.0)
        return self.mode

    async def drive(self, seconds=0.1):
        self.clock.advance(seconds)
        self.sender.last_received = self.sender.last_power = self.clock()
        await self.mode.tick(self.controller, self.sender)

    async def test_capabilities(self):
        for client, state in [(FakeClient(), 'known'), (FakeClient(present=False), 'unavailable'),
                              (FakeClient(raw=b'bad'), 'invalid'), (FakeClient(raw=RuntimeError('read')), 'invalid')]:
            c = CombinedMode()
            await c.check_supported(client)
            self.assertEqual(c.range_state, state)
            self.assertTrue(c.started)
            if state == 'invalid':
                with self.assertRaises(CommandError): c.validate_target(100)
                c.validate_target(0)
        c = CombinedMode(); await c.check_supported(FakeClient(features=4))
        with self.assertRaises(CommandError): c.validate_target(100)
        self.assertEqual(c.selected_gear(), 4)

    async def test_zero_release_and_resume(self):
        c = self.setup_mode(limits=(100, 1300, 5))
        c.accept('set_target_power', {'watts': 0})
        await self.drive()
        self.assertEqual(self.controller.calls, [b'\x01'])
        self.assertEqual(c.mode, 'RELEASED')
        self.assertTrue(c.release_confirmed)
        self.assertIsNone(c.selected_gear())
        c.accept('set_target_power', {'watts': 500})
        await self.drive()
        self.assertEqual(c.sent_w, 100)
        self.assertEqual(c.mode, 'ERG')
        c.accept('set_mode', {'mode': 'SIM'})
        await self.drive()
        self.assertEqual(c.mode, 'SIM')
        self.assertEqual(c.selected_gear(), 4)

    async def test_ramp_up_down_and_sprint(self):
        c = self.setup_mode()
        c.accept('set_mode', {'mode': 'ERG'})
        c.accept('set_target_power', {'watts': 1300, 'ramp_w_per_s': 2000})
        await self.drive()
        for _ in range(10): await self.drive()
        powers = [struct.unpack('<h', x[1:])[0] for x in self.controller.calls if x[0] == 5]
        self.assertEqual(powers[-1], 1300)
        self.assertTrue(any(b - a > 10 for a, b in zip(powers, powers[1:])))
        self.assertTrue(all(0 < b - a <= 200 for a, b in zip(powers, powers[1:])))
        c.accept('set_target_power', {'watts': 100})
        for _ in range(10): await self.drive()
        self.assertEqual(c.sent_w, 100)
        self.assertEqual(c.applied_revision, c.revision)

    async def test_slow_quantized_ramp(self):
        c = self.setup_mode(limits=(50, 1300, 10))
        c.accept('set_mode', {'mode': 'ERG'})
        c.accept('set_target_power', {'watts': 100, 'ramp_w_per_s': 10})
        await self.drive()
        for _ in range(5): await self.drive()
        self.assertEqual(c.sent_w, 50)
        for _ in range(6): await self.drive()
        self.assertEqual(c.sent_w, 60)

    async def test_udp_timeout_releases_and_new_race_recovers(self):
        c = self.setup_mode()
        owner = ('127.0.0.1', 1000)
        c.accept('set_mode', {'mode': 'ERG'}, owner)
        c.accept('set_target_power', {'watts': 265}, owner)
        await self.drive()
        await self.drive(5.1)
        self.assertFalse(c.disabled)
        self.assertEqual(c.last_error, 'udp_timeout')
        self.assertTrue(c.release_confirmed)
        self.assertEqual(c.mode, 'RELEASED')
        self.assertEqual(c.target_w, 0)
        self.assertIsNone(c.owner)
        c.accept('set_mode', {'mode': 'SIM'}, owner)
        c.accept('set_grade', {'grade_pct': 0}, owner)
        await self.drive()
        self.assertEqual(c.mode, 'SIM')
        self.assertFalse(c.disabled)

    async def test_repeated_team_swaps_never_reuse_old_erg_target(self):
        c = self.setup_mode()
        c.simulation_supported = True
        owner = ('127.0.0.1', 1000)
        for watts in (199, 232, 265):
            c.accept('set_mode', {'mode': 'ERG'}, owner)
            self.assertEqual(c.target_w, 0)
            self.assertIsNone(c.owner)
            await self.drive()
            self.assertFalse(any(op[0] == 5 for op in self.controller.calls[-1:]))
            c.accept('set_target_power', {'watts': watts}, owner)
            for _ in range(12):
                await self.drive()
                c.accept('heartbeat', source=owner)
            self.assertEqual(c.target_w, watts)
            c.accept('set_mode', {'mode': 'SIM'}, owner)
            c.accept('set_grade', {'grade_pct': 0}, owner)
            await self.drive()
            self.assertEqual(c.mode, 'SIM')
        sent_before = len([x for x in self.controller.calls if x[0] == 5])
        c.accept('set_mode', {'mode': 'ERG'}, owner)
        self.assertEqual(c.target_w, 0)
        self.assertIsNone(c.owner)
        await self.drive()
        self.assertEqual(c.mode, 'RELEASED')
        self.assertEqual(len([x for x in self.controller.calls if x[0] == 5]), sent_before)
        await self.drive(6)
        self.assertFalse(c.disabled)
        self.assertFalse(c.reconnect_ready)
        c.accept('set_target_power', {'watts': 240}, owner)
        await self.drive()
        self.assertEqual(c.target_w, 240)
        self.assertEqual(c.mode, 'ERG')

    async def test_data_timeout(self):
        c = self.setup_mode(); c.accept('set_mode', {'mode': 'ERG'})
        c.accept('set_target_power', {'watts': 265})
        self.clock.advance(3.1)
        await c.tick(self.controller, self.sender)
        self.assertFalse(c.disabled)
        self.assertTrue(c.waiting_for_feedback)
        self.assertEqual(c.last_error, 'trainer_data_timeout')

    async def test_power_timeout_despite_other_notifications(self):
        c = self.setup_mode(); c.accept('set_mode', {'mode': 'ERG'})
        c.accept('set_target_power', {'watts': 265})
        self.clock.advance(3.1)
        self.sender.last_received = self.clock()
        await c.tick(self.controller, self.sender)
        self.assertFalse(c.disabled)
        self.assertTrue(c.waiting_for_feedback)

    async def test_disconnect_releases_without_more_targets(self):
        c = self.setup_mode(); c.accept('set_mode', {'mode': 'ERG'})
        c.accept('set_target_power', {'watts': 265})
        await self.drive()
        count = len(self.controller.calls)
        self.sender.connected = False
        await c.tick(self.controller, self.sender)
        self.assertFalse(c.disabled)
        self.assertTrue(c.waiting_for_feedback)
        self.assertEqual(self.controller.calls[count:], [b'\x01'])

    async def test_stall_does_not_catch_up_entire_ramp(self):
        c = self.setup_mode()
        c.accept('set_mode', {'mode': 'ERG'})
        c.accept('set_target_power', {'watts': 1300, 'ramp_w_per_s': 100})
        await self.drive()
        first = c.sent_w
        await self.drive(2.0)
        self.assertLessEqual(c.sent_w - first, 35)

    async def test_existing_telemetry_shape_and_gear(self):
        # Execute the actual Sender class without importing optional BLE/USB
        # libraries. This exercises its real publish path and JSON serialization.
        import socket
        tree = ast.parse((Path(__file__).resolve().parents[1] / 'bridge.py').read_text(encoding='utf-8'))
        sender_ast = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == 'Sender')
        scope = dict(socket=socket, json=json, time=time, asyncio=asyncio,
                     HeartRateState=HeartRateState, TARGET=('127.0.0.1', 51723))
        exec(compile(ast.Module(body=[sender_ast], type_ignores=[]), '<bridge Sender>', 'exec'), scope)
        sender = scope['Sender']()
        sender.sock.close()
        sender.sock = Transport()
        c = ready(); sender.combined_mode = c
        sender.connected = True; sender.last_received = time.monotonic()
        sender.latest = {'power_w': 200, 'speed_kmh': 35, 'cadence_rpm': 90}
        sender.heart_rate.update(140)
        async def once_sleep(_): raise asyncio.CancelledError()
        with patch('asyncio.sleep', side_effect=once_sleep):
            with self.assertRaises(asyncio.CancelledError): await sender.publish()
        raw, endpoint = sender.sock.sent[-1]
        self.assertEqual(endpoint, ('127.0.0.1', 51723))
        result = json.loads(raw)
        self.assertEqual(set(result), {'type', 'valid', 'power_w', 'speed_kmh', 'cadence_rpm', 'sample_id', 'heart_rate_bpm', 'gear'})
        self.assertTrue(result['valid'])
        self.assertEqual(result['gear'], 4)
        self.assertEqual(result['heart_rate_bpm'], 140)
        c.accept('set_mode', {'mode': 'ERG'})
        self.assertIsNone(c.selected_gear())

    async def test_stop_during_reset_prevents_new_mode(self):
        c = self.setup_mode(); c.accept('set_mode', {'mode': 'ERG'})
        self.controller.hook = lambda stage: c.request_stop() if stage == 'release' else None
        await self.drive()
        self.assertEqual(self.controller.calls, [b'\x01'])

    async def test_changed_request_during_initialize(self):
        c = self.setup_mode(); c.accept('set_mode', {'mode': 'ERG'})
        c.accept('set_target_power', {'watts': 265})
        self.controller.hook = lambda stage: c.accept('set_target_power', {'watts': 0}) if stage == 'initialize' else None
        await self.drive()
        self.controller.hook = None
        await self.drive()
        self.assertFalse(self.controller.active)
        self.assertTrue(c.release_confirmed)
        self.assertFalse(any(x[0] == 5 for x in self.controller.calls))

    async def test_serialized_ftms_and_subscription_reuse(self):
        client = FakeClient(); controller = ResistanceController(client)
        await controller.initialize()
        await asyncio.gather(*(controller.command(encode_target_power(n)) for n in range(100, 110)))
        self.assertEqual(client.max_inflight, 1)
        await controller.release()
        await controller.initialize()
        self.assertEqual(client.subscriptions, 1)

    async def test_ftms_rejection_blocks_further_targets(self):
        client = FakeClient(); controller = ResistanceController(client)
        await controller.initialize(); client.result = 3
        with self.assertRaises(RuntimeError): await controller.command(encode_target_power(1300))
        client.result = 1
        with self.assertRaises(RuntimeError): await controller.command(encode_target_power(200))
        await controller.release()
        self.assertFalse(controller.active)

    async def test_timeout_poison_and_wrong_opcode(self):
        client = FakeClient(); controller = ResistanceController(client)
        await controller.initialize()
        async def wrong_reply(uuid, data, response):
            controller._notify(None, b'\x80\x04\x01')
        client.write_gatt_char = wrong_reply
        real_timeout = asyncio.timeout
        with patch('resistance.asyncio.timeout', side_effect=lambda _: real_timeout(0.02)):
            with self.assertRaises(TimeoutError): await controller.command(encode_target_power(100))
        self.assertTrue(controller.faulted)
        controller._notify(None, b'\x80\x05\x01')  # Late indication ignored.
        with self.assertRaises(RuntimeError): await controller.command(encode_target_power(200))

    async def test_real_loopback_udp_and_duplicate(self):
        loop = asyncio.get_running_loop(); c = self.setup_mode()
        server, _ = await loop.create_datagram_endpoint(lambda: CommandProtocol(c), local_addr=('127.0.0.1', 0))
        received = asyncio.Queue()
        class Receiver(asyncio.DatagramProtocol):
            def datagram_received(self, data, addr): received.put_nowait(data)
        client, _ = await loop.create_datagram_endpoint(Receiver, local_addr=('127.0.0.1', 0))
        try:
            endpoint = server.get_extra_info('sockname')
            raw = packet('set_target_power', watts=1300)
            client.sendto(raw, endpoint)
            first = await asyncio.wait_for(received.get(), 2)
            self.assertEqual(json.loads(first)['type'], 'ack')
            self.assertEqual(c.target_w, 1300)
            self.assertEqual(c.desired_mode, 'SIM')
            client.sendto(raw, endpoint)
            self.assertEqual(await asyncio.wait_for(received.get(), 2), first)
        finally:
            client.close(); server.close()

    async def test_trainer_loop_with_udp_and_console(self):
        # Actual trainer_loop + command handler, with BLE replaced by a simulated
        # client. No hardware drivers or optional packages are imported.
        fake_bleak = ModuleType('bleak')
        fake_bleak.BleakClient = fake_bleak.BleakScanner = None
        filename = Path(__file__).resolve().parents[1] / 'bridge.py'
        spec = importlib.util.spec_from_file_location('_tested_bridge', filename)
        bridge = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, {'bleak': fake_bleak}): spec.loader.exec_module(bridge)
        client = FakeClient(features=12 | (1 << 13))
        class Services:
            def __iter__(self): return iter([SimpleNamespace(uuid=bridge.FTMS_SERVICE)])
            def get_characteristic(self, uuid): return object()
        client.services = Services()
        client.is_connected = True
        old_notify = client.start_notify
        async def start_notify(uuid, callback):
            if uuid == bridge.BIKE_DATA:
                callback(None, struct.pack('<HHHh', 68, 3000, 180, 150))
            else:
                await old_notify(uuid, callback)
        client.start_notify = start_notify
        class Context:
            async def __aenter__(self): return client
            async def __aexit__(self, *args): pass
        sender = bridge.Sender(); c = CombinedMode(10000)
        bridge.BleakClient = lambda *a, **kw: Context()
        task = asyncio.create_task(bridge.trainer_loop(SimpleNamespace(name='fake', address='test'), sender, combined=c))
        async def until(predicate):
            async with asyncio.timeout(3):
                while not predicate(): await asyncio.sleep(0.01)
        try:
            await until(lambda: c.started)
            protocol = CommandProtocol(c); transport = Transport(); protocol.connection_made(transport)
            addr = ('127.0.0.1', 11111)
            protocol.datagram_received(packet('set_grade', id='grade-1', grade_pct=1, ramp_pct_per_s=100), addr)
            await until(lambda: c.road.confirmed() is not None and c.road.confirmed()['grade_pct'] == 1)
            self.assertTrue(any(x[0] == 0x11 for x in client.writes))
            protocol.datagram_received(packet('set_mode', id='i2', mode='ERG'), addr)
            protocol.datagram_received(packet('set_target_power', id='i1', watts=200), addr)
            await until(lambda: c.sent_w == 200)
            self.assertEqual(c.applied_revision, c.revision)
            c.handle_command('sim')
            await until(lambda: c.mode == 'SIM')
            c.handle_command('stop')
            await until(lambda: c.mode == 'RELEASED')
            self.assertEqual(client.max_inflight, 1)
            self.assertEqual(client.subscriptions, 1)
            self.assertFalse(any(x == b'\x05\x00\x00' for x in client.writes))
        finally:
            task.cancel()
            try: await task
            except asyncio.CancelledError: pass
            sender.sock.close()

if __name__ == '__main__': unittest.main()

