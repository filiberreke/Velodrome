import asyncio
import importlib.util
from pathlib import Path
from types import SimpleNamespace, ModuleType
import sys
import struct
import unittest
from unittest.mock import patch

import test_bridge as base
from combined_mode import CombinedMode, CommandError
from device_search import Discovery, DeviceSearch
from selection import select_device, select_left_ride

def record(name, address, left=False):
    return (SimpleNamespace(name=name, address=address),
            SimpleNamespace(local_name=name, manufacturer_data={0x094A: b'\x08'} if left else {}))

def load_bridge():
    fake = ModuleType('bleak'); fake.BleakClient = fake.BleakScanner = None
    spec = importlib.util.spec_from_file_location('_reconnect_bridge', Path(__file__).parents[1] / 'bridge.py')
    bridge = importlib.util.module_from_spec(spec)
    with patch.dict(sys.modules, {'bleak': fake}): spec.loader.exec_module(bridge)
    return bridge

class SearchTests(unittest.IsolatedAsyncioTestCase):
    async def test_waits_through_missing_device_and_scan_error(self):
        clock = base.Clock(); scans = 0; waits = []
        wanted = record('KICKR', 'AA')
        async def scan():
            nonlocal scans
            scans += 1
            if scans == 1: raise OSError('Bluetooth temporarily off')
            return [] if scans < 4 else [wanted]
        async def sleep(delay): waits.append(delay); clock.advance(delay)
        search = DeviceSearch(Discovery(scan, clock), lambda rows: select_device(rows, 'KICKR'), 'KICKR', sleep)
        self.assertIs(await search(), wanted[0])
        self.assertEqual(scans, 4)
        self.assertEqual(waits, [5, 5, 5])

    async def test_rescan_pins_same_address_and_shares_scan(self):
        clock = base.Clock(); wanted = record('KICKR', 'AA'); other = record('KICKR', 'BB')
        ride = record('Zwift Ride', 'CC', True); scans = 0
        async def scan():
            nonlocal scans
            scans += 1
            return [wanted, ride] if scans in [1, 3] else [other, ride]
        async def sleep(delay): clock.advance(delay)
        discovery = Discovery(scan, clock)
        trainer = DeviceSearch(discovery, lambda rows: select_device(rows, 'KICKR'), 'KICKR', sleep)
        controller = DeviceSearch(discovery, select_left_ride, 'Ride', sleep)
        self.assertIs(await trainer(), wanted[0])
        self.assertIs(await controller(), ride[0])
        self.assertEqual(scans, 1)
        clock.advance(5)
        self.assertIs(await trainer(), wanted[0])
        self.assertEqual(scans, 3) # Ignored BB and waited for AA.

    async def test_cancellation_interrupts_wait(self):
        async def scan(): return []
        search = DeviceSearch(Discovery(scan), select_left_ride, 'Ride')
        task = asyncio.create_task(search())
        await asyncio.sleep(.01); task.cancel()
        with self.assertRaises(asyncio.CancelledError): await task

class RecoveryTests(unittest.IsolatedAsyncioTestCase):
    async def test_main_keeps_telemetry_and_command_socket_alive_while_missing(self):
        bridge = load_bridge(); published = []
        class Sender(bridge.Sender):
            def send(self, packet): published.append(packet)
        async def scan(): return []
        async def console(_combined): await asyncio.Event().wait()
        bridge.Sender, bridge.discover_devices, bridge.combined_console = Sender, scan, console
        bridge.COMMAND_PORT = 0 # Never bind/control the user's real bridge.
        args = base.SimpleNamespace(list=False, no_ant=True, trainer='KICKR', ride='', erg_ramp_w_per_s=300)
        task = asyncio.create_task(bridge.main(args))
        try:
            async with asyncio.timeout(2):
                while not published: await asyncio.sleep(.01)
            self.assertFalse(task.done())
            self.assertTrue(published)
            self.assertFalse(published[-1]['valid'])
        finally:
            task.cancel()
            with self.assertRaises(asyncio.CancelledError): await task

    async def test_disconnect_discards_targets_and_can_be_rearmed(self):
        clock = base.Clock(); c = base.ready(clock); c.simulation_supported = True
        owner = ('127.0.0.1', 23456)
        c.accept('set_grade', {'grade_pct': 9, 'aero_scale': .31}, owner)
        c.connection_lost()
        self.assertFalse(c.disabled)
        self.assertFalse(c.started)
        self.assertTrue(c.waiting_for_feedback)
        self.assertIsNone(c.owner)
        self.assertEqual((c.target_w, c.grade_pct, c.aero_scale), (0, 0, 1))
        with self.assertRaises(CommandError): c.accept('set_mode', {'mode': 'SIM'}, owner)
        # Release can be staged while offline. No target/lease is restored.
        c.accept('set_target_power', {'watts': 0}, owner)
        await c.check_supported(base.FakeClient(features=12 | (1 << 13)))
        controller = base.FakeController()
        sender = base.SimpleNamespace(connected=True, last_received=clock(), last_power=clock())
        await c.tick(controller, sender)
        self.assertEqual(controller.calls, [b'\x01'])
        self.assertFalse(c.waiting_for_feedback)
        self.assertTrue(c.release_confirmed)
        self.assertTrue(c.status()['reconnect_ready'])
        c.accept('set_mode', {'mode': 'SIM'}, owner)
        c.accept('set_grade', {'grade_pct': 2}, owner)
        clock.advance(.1); await c.tick(controller, sender)
        self.assertEqual(c.desired_mode, 'SIM')
        self.assertEqual(c.grade_pct, 2)

    async def test_feedback_gap_waits_for_new_power_without_reloading(self):
        clock = base.Clock(); c = base.ready(clock)
        c.accept('set_mode', {'mode': 'ERG'})
        controller = base.FakeController()
        sender = base.SimpleNamespace(connected=True, last_received=100, last_power=100)
        clock.advance(3.1); await c.tick(controller, sender)
        self.assertFalse(c.disabled)
        self.assertTrue(c.waiting_for_feedback)
        self.assertEqual(c.target_w, 0)
        sender.last_received = sender.last_power = clock()
        await c.tick(controller, sender)
        self.assertFalse(c.waiting_for_feedback)
        self.assertEqual(c.mode, 'RELEASED')
        self.assertFalse(any(p[0] == 5 for p in controller.calls))

    async def test_explicit_stop_stays_stopped_after_reconnect(self):
        c = base.ready(); c.request_stop('udp_stop'); c.connection_lost()
        self.assertTrue(c.disabled)
        self.assertEqual(c.last_error, 'udp_stop')

    async def test_trainer_loop_reconnects_after_initial_failure_and_drop(self):
        await self.exercise_reconnect()

    async def test_stale_link_is_closed_and_rediscovered(self):
        await self.exercise_reconnect(stalled=True)

    async def exercise_reconnect(self, stalled=False):
        bridge = load_bridge(); attempts = 0; finds = 0
        clock = asyncio.get_running_loop()
        second_connected = asyncio.Event()
        c = CombinedMode()
        sender = bridge.Sender()
        class Services:
            def __iter__(self): return iter([SimpleNamespace(uuid=bridge.FTMS_SERVICE)])
            def get_characteristic(self, _uuid): return object()
        class Client(base.FakeClient):
            def __init__(self):
                super().__init__(features=12 | (1 << 13)); self.services = Services(); self.is_connected = True
            async def start_notify(self, uuid, callback):
                if uuid == bridge.BIKE_DATA:
                    callback(None, struct.pack('<HHHh', 68, 3000, 180, 150))
                else: await super().start_notify(uuid, callback)
        clients = []
        class Context:
            async def __aenter__(self):
                nonlocal attempts
                attempts += 1
                if attempts == 1: raise OSError('off at startup')
                client = Client(); clients.append(client)
                if attempts == 2 and not stalled:
                    clock.call_later(.05, setattr, client, 'is_connected', False)
                elif attempts >= 3: second_connected.set()
                return client
            async def __aexit__(self, *args): pass
        async def find():
            nonlocal finds
            finds += 1
            return SimpleNamespace(name='KICKR', address='AA')
        bridge.BleakClient = lambda *a, **kw: Context()
        with patch.object(bridge, 'RETRY_SECONDS', .01), patch.object(bridge, 'FEEDBACK_TIMEOUT_SECONDS', .05 if stalled else 3):
            task = asyncio.create_task(bridge.trainer_loop(None, sender, combined=c, device_search=find))
            try:
                await asyncio.wait_for(second_connected.wait(), 2)
                async with asyncio.timeout(2):
                    while not c.started: await asyncio.sleep(.01)
                self.assertGreaterEqual(finds, 3)
                self.assertFalse(c.disabled)
                self.assertTrue(sender.connected)
                self.assertFalse(any(p[0] in [4, 5, 0x11] for p in clients[-1].writes))
            finally:
                task.cancel()
                with self.assertRaises(asyncio.CancelledError): await task
                sender.sock.close()
