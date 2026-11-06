"""Mapped steering packets retain the originating Ride button's intent."""
import json
from pathlib import Path
import sys
import unittest
import tempfile
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from button_mapping import ButtonMapper
from virtual_shift import VirtualShifter


class ButtonPacketTests(unittest.TestCase):
    def test_phase1_config_gets_pause_without_losing_custom_bindings(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'button_mapping.json'
            path.write_text(json.dumps({'A': 'Y', 'B': 'B', 'Y': ''}), encoding='utf-8')
            mapper = ButtonMapper.load(path)
        self.assertEqual(mapper.packet('Z'), dict(type='button', button='Z', source_button='Z'))
        self.assertEqual(mapper.map_button('A'), 'Y')
        self.assertIsNone(mapper.packet('Y'))

    def test_explicit_pause_override_is_preserved(self):
        for action in ['', 'A']:
            with self.subTest(action=action), tempfile.TemporaryDirectory() as folder:
                path = Path(folder) / 'button_mapping.json'
                path.write_text(json.dumps({'Z': action}), encoding='utf-8')
                self.assertEqual(ButtonMapper.load(path).map_button('Z'), action)

    def test_both_left_keys_shift_down_and_both_right_keys_shift_up(self):
        shifter = VirtualShifter()
        with patch('virtual_shift.time.monotonic', side_effect=[10, 11, 12, 13]):
            for key, gear in [('SHIFT_UP_LEFT', 3), ('SHIFT_DOWN_LEFT', 2),
                              ('SHIFT_UP_RIGHT', 3), ('SHIFT_DOWN_RIGHT', 4)]:
                self.assertTrue(shifter.on_button(key, announce=False))
                self.assertEqual(shifter.gear, gear)
    def test_paddles_retain_source_after_direction_mapping(self):
        mapper = ButtonMapper.load()
        for button in ('SHIFT_UP_LEFT', 'SHIFT_DOWN_LEFT', 'SHIFT_UP_RIGHT', 'SHIFT_DOWN_RIGHT'):
            with self.subTest(button=button):
                packet = json.loads(json.dumps(mapper.packet(button)))
                self.assertEqual(packet['type'], 'button')
                self.assertEqual(packet['button'], 'LEFT' if button.endswith('_LEFT') else 'RIGHT')
                self.assertEqual(packet['source_button'], button)

    def test_direction_and_reset_buttons_retain_source(self):
        mapper = ButtonMapper.load()
        for button in ('LEFT', 'RIGHT', 'UP', 'DOWN', 'A', 'B', 'Y', 'Z'):
            self.assertEqual(mapper.packet(button), dict(type='button', button=button, source_button=button))

    def test_unmapped_and_disabled_buttons_emit_no_packet(self):
        mapper = ButtonMapper({'RIGHT': ''})
        self.assertIsNone(mapper.packet('RIGHT'))
        self.assertIsNone(mapper.packet('UNKNOWN'))


if __name__ == '__main__': unittest.main()
