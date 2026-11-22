"""Regression of native wire commands and existing controller lifecycle."""
import asyncio
import importlib.util
import struct
import sys
import unittest
from pathlib import Path
from types import ModuleType
from types import SimpleNamespace
from unittest.mock import patch

from test_bridge import Clock
from native_shifting import (
    FC82, FC82_GREETING, FC82_SERVICE, GREETING, HUB, INDICATE, NOTIFY, SERVICE, WRITE,
    NativeController, encode_fc82_ratio, encode_ratio, encode_road, integer, message,
    native_mode, read_ratio,
)
from ride_protocol import fields
from resistance import CONTROL_POINT, FEATURE
from simulation import encode_simulation


def char(uuid, *properties):
    return SimpleNamespace(uuid=uuid, properties=list(properties))


def hub_service():
    return SimpleNamespace(uuid=SERVICE, characteristics=[
        char(NOTIFY, 'notify'), char(WRITE, 'write'), char(INDICATE, 'indicate')])


def fc82_service():
    return SimpleNamespace(uuid=FC82_SERVICE, characteristics=[
        char(NOTIFY, 'notify'), char(WRITE, 'write', 'write-without-response'), char(INDICATE, 'indicate')])


class Services(list):
    """Iterable like bleak's BleakGATTServiceCollection, with characteristic lookup."""
    def get_characteristic(self, uuid):
        return next((c for s in self for c in s.characteristics if c.uuid == uuid), object())


class Trainer:
    """Simulated trainer. services: 'hub', 'fc82', 'both' or 'none'."""
    def __init__(self, supported=True, services='hub', simulation=True):
        if not supported:
            services = 'none'
        self.services = Services([SimpleNamespace(uuid='00001826-0000-1000-8000-00805f9b34fb', characteristics=[])])
        if services in ('hub', 'both'):
            self.services.append(hub_service())
        if services in ('fc82', 'both'):
            self.services.append(fc82_service())
        self.features = 12 | ((1 << 13) if simulation else 0)
        self.callbacks = {}
        self.writes = []
        self.responses = []
        self.accept_ratio = True
        self.ratio_offset = 0
        self.greeting_reply = GREETING + b'\x00'
        self.hang_road = False

    async def read_gatt_char(self, uuid):
        if uuid == FEATURE:
            return struct.pack('<II', 0, self.features)
        return struct.pack('<hhH', 0, 1500, 1)

    async def start_notify(self, target, callback):
        self.callbacks[str(getattr(target, 'uuid', target))] = callback

    async def write_gatt_char(self, target, packet, response=True):
        uuid = str(getattr(target, 'uuid', target))
        self.writes.append((uuid, bytes(packet)))
        self.responses.append(response)
        if uuid == CONTROL_POINT:
            self.callbacks[uuid](uuid, bytes([0x80, packet[0], 1]))
        elif packet == GREETING:
            self.callbacks[INDICATE](INDICATE, self.greeting_reply)
        elif packet.startswith(b'\x04\x2a') and self.accept_ratio:
            # Echo the requested ratio in the captured 0x3c/520 response layout.
            requested = dict((f, v) for f, _, v in fields(dict((f, v) for f, _, v in fields(packet[1:]))[5]))[2]
            reported = integer(8, requested + self.ratio_offset)
            self.callbacks[INDICATE](INDICATE, b'\x3c' + integer(1, 520) + message(2, message(1, reported)))
        elif packet.startswith(b'\x04\x22') and self.hang_road:
            await asyncio.sleep(3600)


class NativeTests(unittest.IsolatedAsyncioTestCase):
    def test_wire_examples(self):
        self.assertEqual(encode_ratio(24000), bytes.fromhex('042a0410c0bb01'))
        self.assertEqual(encode_ratio(7500), bytes.fromhex('042a0310cc3a'))
        self.assertEqual(encode_ratio(54899), bytes.fromhex('042a0410f3ac03'))
        self.assertEqual(encode_road(-1, .004, .3),
                         bytes.fromhex('04220b080010c70118b817209003'))
        self.assertEqual(read_ratio(bytes.fromhex('3c08880412060a0440c0bb01')), 24000)
        for ratio in (0, 54900, True):
            with self.assertRaises(ValueError):
                encode_ratio(ratio)

    async def test_native_grade_and_ratio_then_erg_release_and_reconnect(self):
        clock = Clock()
        mode = native_mode(clock=clock)
        client = Trainer()
        controller = NativeController(client)
        await controller.initialize()
        await mode.check_supported(client)
        sender = SimpleNamespace(connected=True, last_received=100, last_power=100)
        mode.accept('set_grade', {'grade_pct': 5, 'ramp_pct_per_s': 100})
        for _ in range(4):
            clock.advance(.1)
            sender.last_received = sender.last_power = clock()
            await mode.tick(controller, sender)
        native = [data for uuid, data in client.writes if uuid == WRITE]
        self.assertIn(encode_ratio(24000), native)
        self.assertIn(encode_road(5, .004, .3), native)
        self.assertFalse(any(data[0] == 0x11 for uuid, data in client.writes if uuid == CONTROL_POINT))
        self.assertEqual(mode.status()['native_ratio_confirmed'], 24000)
        self.assertIsNone(mode.status()['confirmed_simulation'])
        mode.accept('set_mode', {'mode': 'ERG'})
        mode.accept('set_target_power', {'watts': 200})
        await mode.tick(controller, sender)
        self.assertFalse(controller.native_ready)
        self.assertEqual(mode.mode, 'ERG')
        mode.accept('set_target_power', {'watts': 0})
        await mode.tick(controller, sender)
        self.assertFalse(controller.active)
        mode.connection_lost()
        await controller.initialize()
        await mode.check_supported(client)
        self.assertIsNone(controller.confirmed_ratio)
        self.assertEqual(mode.target_w, 0)

    async def test_absent_service_fails_before_ftms_write(self):
        client = Trainer(supported=False)
        with self.assertRaisesRegex(RuntimeError, 'Geen native shifting-service'):
            await NativeController(client).initialize()
        self.assertEqual(client.writes, [])

    async def test_ratio_timeout_does_not_send_grade_and_watchdog_releases(self):
        clock = Clock()
        mode = native_mode(clock=clock)
        client = Trainer()
        client.accept_ratio = False
        controller = NativeController(client)
        await controller.initialize()
        await mode.check_supported(client)
        sender = SimpleNamespace(connected=True, last_received=100, last_power=100)
        mode.accept('set_grade', {'grade_pct': 5})
        timeout = asyncio.timeout
        with patch('native_shifting.asyncio.timeout', side_effect=lambda _: timeout(.01)):
            with self.assertRaises(TimeoutError):
                await mode.tick(controller, sender)
        self.assertFalse(any(data.startswith(b'\x04\x22') for uuid, data in client.writes if uuid == WRITE))
        mode.suspend('native_timeout')
        await mode.tick(controller, sender)
        self.assertFalse(controller.active)
        self.assertFalse(controller.native_ready)

    async def test_native_gear_does_not_scale_grade_or_drag(self):
        mode = native_mode()
        self.assertEqual(mode.road.target(8.68, 4), mode.road.target(8.68, 12))
        self.assertEqual(mode.road.target(8.68, 12)[0], 8.68)
        mode.started = True
        mode.accept('set_mode', {'mode': 'SIM'})
        self.assertEqual(mode.desired_sim_backend, 'simulation')

    def test_mock_echo_matches_captured_frame(self):
        self.assertEqual(b'\x3c' + integer(1, 520) + message(2, message(1, integer(8, 24000))),
                         bytes.fromhex('3c08880412060a0440c0bb01'))

    async def _riding(self, client, clock, protocol='auto'):
        mode = native_mode(clock=clock, protocol=protocol)
        controller = NativeController(client, protocol)
        await controller.initialize()
        await mode.check_supported(client)
        sender = SimpleNamespace(connected=True, last_received=clock(), last_power=clock())
        return mode, controller, sender

    async def test_shift_sends_new_ratio(self):
        clock = Clock()
        client = Trainer()
        mode, controller, sender = await self._riding(client, clock)
        await mode.tick(controller, sender)
        mode.on_button('SHIFT_UP_RIGHT')
        self.assertEqual(mode.shifter.gear, 5)
        await mode.tick(controller, sender)
        ratio = round(24000 * mode.road.factors[4])
        self.assertIn((WRITE, encode_ratio(ratio)), client.writes)
        self.assertEqual(mode.status()['native_ratio_confirmed'], ratio)

    async def test_float_truncated_ratio_echo_is_accepted(self):
        # 25440 stored as float32 reads back as 25439 when truncated.
        clock = Clock()
        client = Trainer()
        client.ratio_offset = -1
        mode, controller, sender = await self._riding(client, clock)
        timeout = asyncio.timeout
        with patch('native_shifting.asyncio.timeout', side_effect=lambda _: timeout(.05)):
            await mode.tick(controller, sender)
            mode.on_button('SHIFT_UP_RIGHT')
            await mode.tick(controller, sender)
        ratio_writes = [d for u, d in client.writes if u == WRITE and d.startswith(b'\x04\x2a')]
        self.assertEqual(len(ratio_writes), 2)  # No resend loop on the next tick either.
        await mode.tick(controller, sender)
        self.assertEqual(len([d for u, d in client.writes if u == WRITE and d.startswith(b'\x04\x2a')]), 2)

    async def test_greeting_reply_with_other_suffix(self):
        client = Trainer()
        client.greeting_reply = b'RideOn\x02\x01'
        mode, controller, sender = await self._riding(client, Clock())
        timeout = asyncio.timeout
        with patch('native_shifting.asyncio.timeout', side_effect=lambda _: timeout(.05)):
            await mode.tick(controller, sender)
        self.assertTrue(controller.native_ready)

    async def test_hung_road_write_times_out(self):
        client = Trainer()
        client.hang_road = True
        mode, controller, sender = await self._riding(client, Clock())
        timeout = asyncio.timeout
        with patch('native_shifting.asyncio.timeout', side_effect=lambda _: timeout(.05)):
            started = asyncio.get_running_loop().time()
            with self.assertRaises(TimeoutError):
                # Outer guard only: without a write timeout the tick hangs until here.
                await asyncio.wait_for(mode.tick(controller, sender), 1)
            self.assertLess(asyncio.get_running_loop().time() - started, .5)

    async def test_trainer_loop_without_service_keeps_telemetry(self):
        fake_bleak = ModuleType('bleak')
        fake_bleak.BleakClient = fake_bleak.BleakScanner = None
        filename = Path(__file__).resolve().parents[1] / 'bridge.py'
        spec = importlib.util.spec_from_file_location('_tested_native_bridge', filename)
        bridge = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, {'bleak': fake_bleak}):
            spec.loader.exec_module(bridge)
        client = Trainer(supported=False)
        client.is_connected = True
        class Services:
            def __iter__(self): return iter([SimpleNamespace(uuid=bridge.FTMS_SERVICE)])
            def get_service(self, uuid): return None
            def get_characteristic(self, uuid): return object()
        client.services = Services()
        async def start_notify(uuid, callback):
            client.callbacks[uuid] = callback
            if uuid == bridge.BIKE_DATA:
                callback(None, struct.pack('<HHHh', 68, 3000, 180, 150))
        client.start_notify = start_notify
        connects = []
        class Context:
            async def __aenter__(self):
                connects.append(1)
                return client
            async def __aexit__(self, *args): pass
        bridge.BleakClient = lambda *a, **kw: Context()
        sender = bridge.Sender()
        mode = native_mode()
        task = asyncio.create_task(bridge.trainer_loop(SimpleNamespace(name='fake', address='t'), sender, combined=mode))
        try:
            async with asyncio.timeout(3):
                while not mode.disabled:
                    await asyncio.sleep(.01)
            await asyncio.sleep(.3)
            self.assertEqual(len(connects), 1)
            self.assertTrue(sender.connected)
            self.assertEqual(mode.last_error, 'native_unsupported')
            self.assertEqual(client.writes, [])
        finally:
            task.cancel()
            try: await task
            except asyncio.CancelledError: pass
            sender.sock.close()

    # --- Wahoo FC82 -------------------------------------------------------

    def test_fc82_wire_examples(self):
        # Hand-encoded from the FreeWheel Shift proto: 0x3f, {1: 1, 2: seq, 4: {7: ratio}}.
        self.assertEqual(encode_fc82_ratio(24000, 0), bytes.fromhex('3f08011000220438c0bb01'))
        self.assertEqual(encode_fc82_ratio(7500, 5), bytes.fromhex('3f080110052203' + '38cc3a'))
        self.assertEqual(encode_fc82_ratio(54899, 300), bytes.fromhex('3f080110ac02220438f3ac03'))
        for ratio in (0, 54900, True):
            with self.assertRaises(ValueError):
                encode_fc82_ratio(ratio, 0)

    async def test_protocol_selection(self):
        for services, requested, expected in (('hub', 'auto', HUB), ('fc82', 'auto', FC82),
                                              ('both', 'auto', HUB), ('both', FC82, FC82)):
            controller = NativeController(Trainer(services=services), requested)
            await controller.initialize()
            self.assertEqual(controller.protocol, expected, (services, requested))
        for services, requested in (('fc82', HUB), ('hub', FC82)):
            client = Trainer(services=services)
            with self.assertRaisesRegex(RuntimeError, 'Geen native shifting-service'):
                await NativeController(client, requested).initialize()
            self.assertEqual(client.writes, [])
        with self.assertRaises(ValueError):
            NativeController(Trainer(), 'fc83')

    async def test_fc82_without_ftms_simulation_fails_before_writes(self):
        client = Trainer(services='fc82', simulation=False)
        with self.assertRaisesRegex(RuntimeError, 'FTMS-simulatie'):
            await NativeController(client).initialize()
        self.assertEqual(client.writes, [])

    async def test_fc82_ratio_native_and_grade_via_ftms(self):
        clock = Clock()
        client = Trainer(services='fc82')
        mode, controller, sender = await self._riding(client, clock)
        mode.accept('set_grade', {'grade_pct': 5, 'ramp_pct_per_s': 100})
        mode.shifter.gear = 12  # Hardest gear must not scale the FTMS grade.
        for _ in range(4):
            clock.advance(.1)
            sender.last_received = sender.last_power = clock()
            await mode.tick(controller, sender)
        native = [data for uuid, data in client.writes if uuid == WRITE]
        ratio = round(24000 * mode.road.factors[11])
        self.assertEqual(native, [FC82_GREETING, encode_fc82_ratio(ratio, 0)])
        self.assertFalse(any(data[0] == 0x04 for data in native))
        ftms = [data for uuid, data in client.writes if uuid == CONTROL_POINT]
        self.assertEqual(ftms[-1], encode_simulation(5, .004, .3))
        status = mode.status()
        self.assertEqual(status['native_protocol'], FC82)
        self.assertEqual(status['native_ratio_written'], ratio)
        self.assertIsNone(status['native_ratio_confirmed'])
        self.assertEqual(status['confirmed_simulation']['grade_pct'], 5)
        self.assertTrue(all(client.responses))

    async def test_fc82_shift_increments_sequence_and_rehandshakes_after_release(self):
        clock = Clock()
        client = Trainer(services='fc82')
        mode, controller, sender = await self._riding(client, clock)
        await mode.tick(controller, sender)
        mode.on_button('SHIFT_UP_RIGHT')
        await mode.tick(controller, sender)
        await mode.tick(controller, sender)  # Unchanged gear: no resend.
        native = [data for uuid, data in client.writes if uuid == WRITE]
        r4, r5 = (round(24000 * mode.road.factors[g]) for g in (3, 4))
        self.assertEqual(native, [FC82_GREETING, encode_fc82_ratio(r4, 0), encode_fc82_ratio(r5, 1)])
        mode.accept('set_mode', {'mode': 'ERG'})
        await mode.tick(controller, sender)
        mode.accept('set_mode', {'mode': 'SIM'})
        await mode.tick(controller, sender)
        native = [data for uuid, data in client.writes if uuid == WRITE]
        self.assertEqual(native[3:], [FC82_GREETING, encode_fc82_ratio(r5, 2)])

    async def test_fc82_prefers_write_without_response_only_when_needed(self):
        client = Trainer(services='fc82')
        client.services[1].characteristics[1].properties = ['write-without-response']
        controller = NativeController(client)
        await controller.initialize()
        await controller.prepare_native()
        self.assertEqual(client.responses[-1], False)
