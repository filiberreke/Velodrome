import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from device_registry import capabilities
from openbikecontrol import APP_INFO, APP_INFO_UUID, BUTTON_STATE_UUID, SERVICE_UUID
from openbikecontrol import ControllerInput, connect


class OpenBikeControlTests(unittest.IsolatedAsyncioTestCase):
    def test_service_is_discoverable_as_controller(self):
        advert = SimpleNamespace(service_uuids=[SERVICE_UUID.upper()])
        self.assertEqual(capabilities(object(), advert), ['controller'])

    async def test_ble_handshake_and_new_session(self):
        packets, shifts, operations = [], [], []

        class Client:
            is_connected = False

            def __init__(self, device, timeout):
                pass

            async def __aenter__(self):
                return self

            async def __aexit__(self, *exc):
                pass

            async def start_notify(self, uuid, callback):
                operations.append(uuid)
                self.notify = callback

            async def write_gatt_char(self, uuid, data, *, response):
                operations.append((uuid, data, response))
                self.notify(None, b'\x01\x14\x01\x01\x01')

        for _ in range(2):
            await connect(object(), Client, packets.append, shifts.append)
        self.assertEqual(operations, [BUTTON_STATE_UUID, (APP_INFO_UUID, APP_INFO, True)] * 2)
        self.assertEqual(packets[0], {'type': 'controller_button', 'source_button': 'A',
                                      'mapped_action': 'A', 'pressed': True})
        self.assertEqual(packets[1]['buttons'], ['A'])
        self.assertEqual(packets[:2], packets[2:])
        self.assertEqual(shifts, ['SHIFT_UP_RIGHT'] * 2)

    def test_button_edges_and_invalid_notifications(self):
        packets, shifts = [], []
        controller = ControllerInput(packets.append, shifts.append)
        for data in (b'\x01\x10\x01\x11\x01', b'\x01\x10\x01',
                     b'\x01\x14', b'\x02\x14\x01', b'\x01\xff\x01',
                     b'\x01\x10\x02', b'\x01\x10\x00\x11\x00',
                     b'\x01\x02\x01', b'\x01\x02\x01', b'\x01\x02\x00',
                     b'\x01\x02\x01'):
            controller.receive(None, data)
        controller.publish_connection()
        self.assertEqual([(row['source_button'], row['pressed']) for row in packets[:-1]],
                         [('UP', True), ('DOWN', True), ('UP', False), ('DOWN', False)])
        self.assertEqual(packets[-1]['buttons'], [])
        self.assertEqual(shifts, ['SHIFT_DOWN_LEFT', 'SHIFT_DOWN_LEFT'])


if __name__ == '__main__':
    unittest.main()
