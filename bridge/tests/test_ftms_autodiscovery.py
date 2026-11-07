"""Regression tests for automatic FTMS trainer discovery."""
import unittest
from types import SimpleNamespace

from selection import select_device


def record(name, services=()):
    device = SimpleNamespace(name=name, address=name)
    adv = SimpleNamespace(local_name=name, service_uuids=list(services))
    return device, adv


class TrainerSelectionTests(unittest.TestCase):
    def test_ftms_advertisement_without_known_brand(self):
        trainer = record("Indoor Bike", ["00001826-0000-1000-8000-00805f9b34fb"])
        self.assertIs(select_device([trainer], ""), trainer[0])

    def test_tacx_without_advertised_service(self):
        trainer = record("Tacx NEO 2T")
        self.assertIs(select_device([trainer], ""), trainer[0])

    def test_explicit_trainer_overrides_auto(self):
        kickr = record("KICKR", ["1826"])
        tacx = record("Tacx NEO")
        self.assertIs(select_device([kickr, tacx], "Tacx"), tacx[0])

    def test_unknown_non_ftms_device_not_selected(self):
        self.assertIsNone(select_device([record("Headphones")], ""))


if __name__ == "__main__":
    unittest.main()
