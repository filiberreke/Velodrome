"""Regression of native wire commands and existing controller lifecycle."""
import asyncio
import struct
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from test_bridge import Clock
from native_shifting import (
    GREETING, SERVICE, WRITE, INDICATE, NativeController, encode_ratio,
    encode_road, integer, message, native_mode, read_ratio,
)
from resistance import CONTROL_POINT, FEATURE


class Trainer:
    def __init__(self, supported=True):
        self.services = SimpleNamespace(
            get_service=lambda uuid: object() if supported and uuid == SERVICE else None,
            get_characteristic=lambda uuid: object(),
        )
        self.callbacks = {}
        self.writes = []
        self.accept_ratio = True

    async def read_gatt_char(self, uuid):
        if uuid == FEATURE:
            return struct.pack('<II', 0, 12 | (1 << 13))
        return struct.pack('<hhH', 0, 1500, 1)

    async def start_notify(self, uuid, callback):
        self.callbacks[uuid] = callback

    async def write_gatt_char(self, uuid, packet, response=True):
        self.writes.append((uuid, bytes(packet)))
        if uuid == CONTROL_POINT:
            self.callbacks[uuid](uuid, bytes([0x80, packet[0], 1]))
        elif packet == GREETING:
            self.callbacks[INDICATE](INDICATE, GREETING + b'\x00')
        elif packet.startswith(b'\x04\x2a') and self.accept_ratio:
            # Independent captured-format response for the neutral 2.4 ratio.
            self.callbacks[INDICATE](INDICATE, bytes.fromhex('3c08880412060a0440c0bb01'))


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
        with self.assertRaisesRegex(RuntimeError, 'ontbreekt'):
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
