"""Keyboard gear ingress uses the same shifter and preserves control ownership."""
import json
import unittest
from unittest.mock import patch
import test_bridge as base
from combined_mode import CommandError
from udp_commands import CommandProtocol

class KeyboardShift(unittest.TestCase):
    def test_udp_shift_deduplicates_and_preserves_lease(self):
        clock = base.Clock()
        controller = base.ready(clock)
        controller.mode = controller.desired_mode = 'SIM'
        protocol = CommandProtocol(controller, clock)
        transport = base.Transport()
        protocol.connection_made(transport)
        address = ('127.0.0.1', 45000)
        controller.owner = address
        controller.lease_until = 104.0
        initial = controller.shifter.gear
        packet = base.packet('shift', direction=1)
        with patch('virtual_shift.time.monotonic', return_value=100):
            protocol.datagram_received(packet, address)
        self.assertEqual(json.loads(transport.sent[-1][0])['type'], 'ack')
        self.assertEqual(controller.shifter.gear, initial + 1)
        with patch('virtual_shift.time.monotonic', return_value=101):
            protocol.datagram_received(packet, address)
        self.assertEqual(controller.shifter.gear, initial + 1)
        self.assertEqual(controller.lease_until, 104.0)
        self.assertEqual(controller.owner, address)

    def test_boundaries_and_invalid_requests(self):
        controller = base.ready()
        controller.mode = controller.desired_mode = 'SIM'
        for direction in (True, 0, 2, '1', 1.0, None):
            with self.subTest(direction=direction), self.assertRaises(CommandError):
                controller.accept('shift', {'direction': direction})
        controller.shifter.gear = 12
        with patch('virtual_shift.time.monotonic', return_value=100):
            controller.accept('shift', {'direction': 1})
        self.assertEqual(controller.shifter.gear, 12)
        controller.owner = ('127.0.0.1', 45000)
        controller.lease_until = 104.0
        with self.assertRaises(CommandError):
            controller.accept('shift', {'direction': -1}, source=('127.0.0.1',45001))
        controller.owner = None
        controller.accept('set_mode', {'mode':'ERG'})
        with self.assertRaises(CommandError):
            controller.accept('shift', {'direction': -1})
        controller.started = False
        with self.assertRaises(CommandError):
            controller.accept('shift', {'direction': -1})
