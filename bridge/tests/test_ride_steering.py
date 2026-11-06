"""Ride wire-format fixtures, analog-only reports, and steer/brake separation."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ride_protocol import BUTTON_BITS, decode_packet, decode_state
from steering import SteeringState


def varint(value):
    out = bytearray()
    while value >= 128:
        out.append((value & 127) | 128)
        value >>= 7
    out.append(value)
    return bytes(out)


def entry(location, value):
    return b'\x08'+varint(location)+b'\x10'+varint((value << 1) ^ (value >> 31))


def message(paddles, legacy=False, bitmap=0xffffffff):
    out = b'\x23' + (b'\x08'+varint(bitmap) if bitmap is not None else b'')
    entries = [entry(k, v) for k, v in paddles.items()]
    if legacy:
        group = b''.join(b'\x0a'+varint(len(e))+e for e in entries)
        return out + b'\x12'+varint(len(group))+group
    return out + b''.join(b'\x1a'+varint(len(e))+e for e in entries)


class RideSteeringTests(unittest.TestCase):
    def test_current_physical_button_bitmaps(self):
        # Fixed wire fixtures from BikeControl RideButtonMask (not BUTTON_BITS).
        # An encoder using BUTTON_BITS would reproduce the decoder's mistake.
        fixtures = {
            'LEFT': '2308feffffff0f', 'UP': '2308fdffffff0f',
            'RIGHT': '2308fbffffff0f', 'DOWN': '2308f7ffffff0f',
            'A': '2308efffffff0f', 'B': '2308dfffffff0f',
            'Y': '2308bfffffff0f', 'Z': '2308fffeffff0f',
            'SHIFT_UP_LEFT': '2308fffdffff0f',
            'SHIFT_DOWN_LEFT': '2308fffbffff0f',
            'POWER_LEFT': '2308fff7ffff0f',
            'ONOFF_LEFT': '2308ffefffff0f',
            'SHIFT_UP_RIGHT': '2308ffdfffff0f',
            'SHIFT_DOWN_RIGHT': '2308ffbfffff0f',
            'POWER_RIGHT': '2308fffffeff0f',
            'ONOFF_RIGHT': '2308fffffdff0f',
        }
        for name, wire_hex in fixtures.items():
            with self.subTest(name=name):
                self.assertEqual(decode_packet(bytes.fromhex(wire_hex)), {name})

    def test_unused_high_bits_do_not_invent_drop_or_power_buttons(self):
        for bit in (0x10000, 0x20000):
            self.assertEqual(decode_packet(message({}, bitmap=0xffffffff ^ bit)), set())

    def test_current_and_legacy_analog_layouts(self):
        for legacy in (True, False):
            for value in (-100, -85, -25, 0, 25, 85, 100):
                with self.subTest(legacy=legacy, value=value):
                    state = decode_state(message({0: value, 1: -value, 2: 0, 3: 0}, legacy))
                    self.assertEqual(state['paddles'], {0: value, 1: -value})
                    self.assertEqual(state['buttons'], set())

    def test_documented_legacy_capture_and_digital_compatibility(self):
        capture = bytes.fromhex('2308feffffff0f12180a04080010000a04080110000a04080210000a0408031000')
        self.assertEqual(decode_state(capture), dict(buttons={'LEFT'}, paddles={0: 0, 1: 0}))
        for name, bit in BUTTON_BITS.items():
            self.assertEqual(decode_packet(message({}, bitmap=0xffffffff ^ bit)), {name})

    def test_analog_only_and_unknown_fields(self):
        self.assertEqual(decode_state(message({1: 90}, bitmap=None)), dict(buttons=None, paddles={1: 90}))
        self.assertEqual(decode_state(message({0: -50})+b'\x52\x03abc')['paddles'], {0: -50})
        self.assertIsNone(decode_state(b'\x19\x00'))
        self.assertIsNone(decode_packet(message({1: 25}, bitmap=None)))

    def test_malformed_and_conflicting_analog_rejected(self):
        bad = [b'\x23\x1a\x05\x08', b'\x23\x08\x80', b'\x23\x00',
               b'\x23\x1a\x03\x08\x00\x10', message({0: 101}), message({1: -101}),
               message({0: -25})+b'\x1a\x04'+entry(0, -90)]
        for raw in bad:
            with self.subTest(raw=raw), self.assertRaises(ValueError): decode_state(raw)

    def test_outward_paddles_and_braking(self):
        state = SteeringState()
        self.assertEqual(state.update({0: -80, 1: 0}), dict(type='steering', value=-80))
        self.assertEqual(state.update({0: 0, 1: 90})['value'], 90)
        self.assertEqual(state.update({0: 70, 1: -80})['value'], 0, 'Inward braking never steers')
        self.assertEqual(state.update({0: -80, 1: 80})['value'], 0, 'Equal opposing steering cancels')

    def test_partial_reports_and_neutral_release(self):
        state = SteeringState()
        self.assertEqual(state.update({0: -60})['value'], -60)
        self.assertIsNone(state.update({}))
        self.assertEqual(state.update({1: 30})['value'], -30)
        self.assertEqual(state.update({0: 0})['value'], 30)
        self.assertEqual(state.update({1: 0})['value'], 0)


if __name__ == '__main__': unittest.main()
