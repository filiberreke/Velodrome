"""Mapped steering packets retain the originating Ride button's intent."""
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from button_mapping import ButtonMapper


class ButtonPacketTests(unittest.TestCase):
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
        for button in ('LEFT', 'RIGHT', 'A'):
            self.assertEqual(mapper.packet(button), dict(type='button', button=button, source_button=button))

    def test_unmapped_and_disabled_buttons_emit_no_packet(self):
        mapper = ButtonMapper({'RIGHT': ''})
        self.assertIsNone(mapper.packet('RIGHT'))
        self.assertIsNone(mapper.packet('UNKNOWN'))


if __name__ == '__main__': unittest.main()
