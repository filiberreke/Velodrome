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
                callback(notify, message({}, bitmap=0xffffffff ^ 0x2000))
                callback(notify, message({}, bitmap=0xffffffff ^ 0x2000))
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
