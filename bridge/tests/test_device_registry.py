import asyncio
import json
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace as NS
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from device_registry import DeviceRegistry, capabilities, decode_ble_hr, FTMS_SERVICE, HR_SERVICE
from device_search import Discovery
from hr_bridge import HeartRateState
from combined_mode import CombinedMode, CommandError
from udp_commands import CommandProtocol


def record(address, services=(), marker=None):
    return NS(address=address, name=address), NS(local_name=address, service_uuids=services,
                                               manufacturer_data={0x094A: bytes([marker])} if marker else {})


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.now = 100.
        self.ant = HeartRateState(lambda: self.now)
        self.registry = DeviceRegistry(None, self.ant, clock=lambda: self.now)
        self.rows = [record('bike', [FTMS_SERVICE]), record('left', marker=8),
                     record('right', marker=9), record('hr', [HR_SERVICE]), record('headphones')]
        self.registry.observe(self.rows)

    def test_only_supported_observed_roles(self):
        inventory = self.registry.snapshot()['devices']
        self.assertEqual({d['address'] for d in inventory}, {'bike', 'left', 'hr'})
        for role, address in [('controller', 'right'), ('trainer', 'hr'), ('trainer', 'invented')]:
            with self.assertRaises(CommandError):
                self.registry.accept('select_device', dict(role=role, address=address))
        for role in ([], 123, 'bad'):
            with self.assertRaises(CommandError):
                self.registry.accept('select_device', dict(role=role, address='bike'))

    def test_persistence_disconnect_no_fallback_and_disable(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'selections.json'
            self.registry.path = path
            self.registry.accept('select_device', dict(role='trainer', address='bike'))
            restored = DeviceRegistry(None, self.ant, path)
            self.assertEqual(restored.selected['trainer'], 'bike')
            self.assertIsNone(restored.choose('trainer', [record('other', [FTMS_SERVICE])], lambda _: 'wrong'))
            self.registry.accept('select_device', dict(role='trainer', address=''))
            self.assertIsNone(self.registry.choose('trainer', self.rows, lambda _: 'wrong'))
            self.assertEqual(DeviceRegistry(None, self.ant, path).selected['trainer'], '')

    def test_stale_and_connected_inventory(self):
        self.registry.accept('select_device', dict(role='trainer', address='bike'))
        self.now += 31
        self.assertEqual(self.registry.snapshot()['devices'][0]['available'], False)
        with self.assertRaises(CommandError):
            self.registry.accept('select_device', dict(role='trainer', address='bike'))
        self.registry.connected['trainer'] = 'bike'
        self.assertTrue(self.registry.snapshot()['devices'][0]['available'])

    def test_ant_only_after_real_data_ble_hr_8_and_16_bit(self):
        self.assertNotIn('ant:active', str(self.registry.snapshot()))
        self.ant.update(130)
        self.assertIn('ant:active', str(self.registry.snapshot()))
        self.registry.accept('select_device', dict(role='heart_rate', address='hr'))
        self.registry.ble_hr.update(decode_ble_hr(bytes([0, 150])))
        self.assertEqual(self.registry.bpm(), 150)
        self.assertEqual(decode_ble_hr(bytes([1, 180, 0])), 180)
        self.assertIsNone(decode_ble_hr(bytes([1, 180])))
        self.registry.accept('select_device', dict(role='heart_rate', address=''))
        self.assertIsNone(self.registry.bpm())
        self.now += 6
        self.assertNotIn('ant:active', str(self.registry.snapshot()))

    def test_udp_selection_deduplicates_without_trainer_lease(self):
        sent = []
        combined = CombinedMode()
        protocol = CommandProtocol(combined, devices=self.registry)
        protocol.connection_made(NS(sendto=lambda raw, addr: sent.append(json.loads(raw))))
        packet = dict(v=1, type='command', id='choose', command='select_device', role='trainer', address='bike')
        for _ in range(2): protocol.datagram_received(json.dumps(packet).encode(), ('127.0.0.1', 55555))
        self.assertTrue(sent[0]['ok'])
        self.assertEqual(sent[0], sent[1])
        self.assertEqual(self.registry.revision['trainer'], 1)
        self.assertIsNone(combined.owner)

    def test_save_failure_keeps_previous_selection(self):
        with tempfile.TemporaryDirectory() as folder:
            self.registry.path = Path(folder) / 'missing' / 'selections.json'
            with self.assertRaises(CommandError) as error:
                self.registry.accept('select_device', dict(role='trainer', address='bike'))
            self.assertEqual(error.exception.code, 'save_failed')
            self.assertIsNone(self.registry.selected['trainer'])
            self.assertEqual(self.registry.revision['trainer'], 0)


class SwitchingTests(unittest.IsolatedAsyncioTestCase):
    async def test_real_udp_inventory_and_selection(self):
        registry = DeviceRegistry(None, HeartRateState())
        registry.observe([record('bike', [FTMS_SERVICE])])
        combined = CombinedMode()
        loop = asyncio.get_running_loop()
        server, _ = await loop.create_datagram_endpoint(
            lambda: CommandProtocol(combined, devices=registry), local_addr=('127.0.0.1', 0))
        received = asyncio.Queue()
        class Receiver(asyncio.DatagramProtocol):
            def datagram_received(self, data, addr): received.put_nowait(json.loads(data))
        client, _ = await loop.create_datagram_endpoint(Receiver, remote_addr=server.get_extra_info('sockname'))
        try:
            for command, params in [('devices', {}), ('select_device', {'role': 'trainer', 'address': 'bike'})]:
                client.sendto(json.dumps(dict(v=1, type='command', id=command, command=command, **params)).encode())
                reply = await asyncio.wait_for(received.get(), 1)
                self.assertTrue(reply['ok'])
                self.assertEqual(reply['state']['devices'][0]['address'], 'bike')
            self.assertEqual(registry.selected['trainer'], 'bike')
            self.assertIsNone(combined.owner)
        finally:
            client.close()
            server.close()

    async def test_switch_finishes_old_cleanup_before_reconnect(self):
        registry = DeviceRegistry(None, HeartRateState())
        events = []
        async def worker():
            events.append('connect')
            try: await asyncio.Future()
            finally:
                await asyncio.sleep(.01)
                events.append('release')
        task = asyncio.create_task(registry.supervise('trainer', worker, lambda: events.append('clear')))
        await asyncio.sleep(.02)
        registry.accept('select_device', dict(role='trainer', address=''))
        await asyncio.sleep(.25)
        task.cancel()
        with self.assertRaises(asyncio.CancelledError): await task
        self.assertEqual(events[:4], ['connect', 'release', 'clear', 'connect'])

    async def test_ble_hr_subscription_uses_selected_device(self):
        registry = DeviceRegistry(None, HeartRateState())
        registry.observe([record('hr', [HR_SERVICE])])
        registry.accept('select_device', dict(role='heart_rate', address='hr'))
        class Client:
            is_connected = True
            def __init__(self, device, **kw): self.device = device
            async def __aenter__(self): return self
            async def __aexit__(self, *args): pass
            async def start_notify(self, uuid, callback): callback(None, bytes([0, 155]))
        task = asyncio.create_task(registry.hr_loop(Client))
        await asyncio.sleep(.02)
        self.assertEqual(registry.bpm(), 155)
        self.assertEqual(registry.connected['heart_rate'], 'hr')
        task.cancel()
        with self.assertRaises(asyncio.CancelledError): await task


if __name__ == '__main__': unittest.main()
