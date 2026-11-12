"""The free warmup keeps the existing SIM gears; ERG owns ramp load."""
import unittest
from unittest.mock import patch
import test_bridge as base


class TrainingGears(unittest.TestCase):
    def test_free_warmup_gears_then_erg_ignores_shifts(self):
        controller = base.ready()
        controller.mode = controller.desired_mode = 'SIM'
        before = controller.selected_gear()
        with patch('virtual_shift.time.monotonic', return_value=100):
            controller.on_button('SHIFT_UP_RIGHT')
        self.assertEqual(controller.selected_gear(), before + 1)
        with patch('virtual_shift.time.monotonic', return_value=101):
            controller.on_button('SHIFT_DOWN_LEFT')
        self.assertEqual(controller.selected_gear(), before)
        controller.accept('set_mode', {'mode': 'ERG'})
        controller.accept('set_target_power', {'watts': 100})
        with patch('virtual_shift.time.monotonic', return_value=102):
            controller.on_button('SHIFT_UP_RIGHT')
        self.assertEqual(controller.target_w, 100)
        self.assertEqual(controller.shifter.gear, before)
        self.assertIsNone(controller.selected_gear())
