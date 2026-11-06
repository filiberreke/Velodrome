"""Run the real Ride notification callback with a fake BLE subscription."""
import asyncio
import importlib.util
from pathlib import Path
import sys
from types import ModuleType, SimpleNamespace
import unittest
from unittest.mock import patch

from test_ride_steering import message


class RideDeliveryTests(unittest.IsolatedAsyncioTestCase):
    async def test_physical_pause_and_four_shift_keys_reach_correct_routes(self):
        fake_bleak = ModuleType('bleak')
        fake_bleak.BleakClient = fake_bleak.BleakScanner = None
        filename = Path(__file__).resolve().parents[1] / 'bridge.py'
        spec = importlib.util.spec_from_file_location('_ride_physical_bridge', filename)
        bridge = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, {'bleak': fake_bleak}): spec.loader.exec_module(bridge)
        from virtual_shift import VirtualShifter
        shifter = VirtualShifter()
        fixtures = [
            ('Z', '2308fffeffff0f', 4),
            ('SHIFT_UP_LEFT', '2308fffdffff0f', 3),
            ('SHIFT_DOWN_LEFT', '2308fffbffff0f', 2),
            ('SHIFT_UP_RIGHT', '2308ffdfffff0f', 3),
            ('SHIFT_DOWN_RIGHT', '2308ffbfffff0f', 4),
        ]
        sent, gears = [], []
        ready = asyncio.Event()
        notify = SimpleNamespace(uuid='notify')
        write = SimpleNamespace(uuid='write', properties=['write'])

        def shift(button):
            shifter.last_button_at = 0  # Each fixture is an independent gesture.
            shifter.on_button(button, announce=False)
            gears.append(shifter.gear)

        class Client:
            is_connected = True
            async def start_notify(self, uuid, callback):
                for _, wire_hex, _ in fixtures:
                    callback(notify, bytes.fromhex(wire_hex))
                    callback(notify, bytes.fromhex(wire_hex))  # Held state, no second action.
                    callback(notify, bytes.fromhex('2308ffffffff0f'))
                ready.set()
            async def write_gatt_char(self, *args, **kwargs): pass
            async def __aenter__(self): return self
            async def __aexit__(self, *args): pass

        with patch.object(bridge, 'BleakClient', return_value=Client()), patch.object(
            bridge, 'find_characteristics', return_value=(notify, write, None, [])):
            task = asyncio.create_task(bridge.ride_loop(
                SimpleNamespace(name='Ride fixture', address='test'),
                SimpleNamespace(send=sent.append), bridge.ButtonMapper.load(),
                combined=SimpleNamespace(on_button=shift)))
            try:
                await asyncio.wait_for(ready.wait(), 2)
                actions = [p for p in sent if p['type'] == 'button']
                self.assertEqual([(p['source_button'], p['button']) for p in actions], [
                    ('Z', 'Z'), ('SHIFT_UP_LEFT', 'LEFT'), ('SHIFT_DOWN_LEFT', 'LEFT'),
                    ('SHIFT_UP_RIGHT', 'RIGHT'), ('SHIFT_DOWN_RIGHT', 'RIGHT')])
                self.assertEqual(gears, [gear for _, _, gear in fixtures])
                edges = [(p['source_button'], p['pressed']) for p in sent if p['type'] == 'controller_button']
                self.assertEqual(edges, [(name, down) for name, _, _ in fixtures for down in (True, False)])
            finally:
                task.cancel()
                with self.assertRaises(asyncio.CancelledError): await task

    async def test_real_notification_sends_analog_and_keeps_digital_edges_independent(self):
        fake_bleak = ModuleType('bleak')
        fake_bleak.BleakClient = fake_bleak.BleakScanner = None
        filename = Path(__file__).resolve().parents[1] / 'bridge.py'
        spec = importlib.util.spec_from_file_location('_ride_delivery_bridge', filename)
        bridge = importlib.util.module_from_spec(spec)
        with patch.dict(sys.modules, {'bleak': fake_bleak}): spec.loader.exec_module(bridge)
        notify = SimpleNamespace(uuid='notify')
        write = SimpleNamespace(uuid='write', properties=['write'])
        sent, shifted = [], []
        ready = asyncio.Event()

        class Client:
            is_connected = True
            async def start_notify(self, uuid, callback):
                callback(notify, message({0: 0, 1: 85}, bitmap=None))
                callback(notify, message({}, bitmap=0xffffffff ^ 0x1000))
                callback(notify, message({}, bitmap=0xffffffff ^ 0x1000))
                callback(notify, message({1: 0}, legacy=True))
                ready.set()
            async def write_gatt_char(self, *args, **kwargs): pass
            async def __aenter__(self): return self
            async def __aexit__(self, *args): pass

        with patch.object(bridge, 'BleakClient', return_value=Client()), patch.object(
            bridge, 'find_characteristics', return_value=(notify, write, None, [])):
            task = asyncio.create_task(bridge.ride_loop(
                SimpleNamespace(name='Ride test', address='test'),
                SimpleNamespace(send=sent.append), bridge.ButtonMapper.load(),
                combined=SimpleNamespace(on_button=shifted.append)))
            try:
                await asyncio.wait_for(ready.wait(), 2)
                self.assertEqual([p for p in sent if p['type'] == 'steering'],
                    [dict(type='steering', value=85), dict(type='steering', value=0)])
                self.assertEqual([p for p in sent if p['type'] == 'button'],
                    [dict(type='button', button='RIGHT', source_button='SHIFT_UP_RIGHT')])
                self.assertEqual(shifted, ['SHIFT_UP_RIGHT'], 'Repeated held digital state has one edge')
            finally:
                task.cancel()
                with self.assertRaises(asyncio.CancelledError): await task


if __name__ == '__main__': unittest.main()
