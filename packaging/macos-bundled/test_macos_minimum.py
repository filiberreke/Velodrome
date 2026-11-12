"""Regression checks for deployment-target audit, including fat binaries."""
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("mac_minimum", Path(__file__).with_name("verify_macos_minimum.py"))
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class MinimumTests(unittest.TestCase):
    def test_parse_all_architecture_deployment_commands(self):
        output = """
Load command 1
      cmd LC_BUILD_VERSION
    minos 11.0
      sdk 15.0
    ntools 1
      tool LD
   version 1053.12
Load command 2
      cmd LC_ID_DYLIB
  current version 2.3.4
Load command 3
      cmd LC_SOURCE_VERSION
  version 711.0
Load command 1
      cmd LC_VERSION_MIN_MACOSX
  version 10.13
      sdk 15.0
"""
        self.assertEqual(audit.deployment_versions(output), ["11.0", "10.13"])

    def test_reject_newer_binary_even_if_plist_allows_monterey(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "runtime").write_bytes(bytes.fromhex("cffaedfe"))
            (root / "Info.plist").write_bytes(plistlib.dumps({"LSMinimumSystemVersion": "12.0"}))
            with patch.object(audit.subprocess, "check_output", return_value="Load command 1\n      cmd LC_BUILD_VERSION\n    minos 15.0\n"):
                result = audit.verify(root, "12.0")
            self.assertEqual(len(result["errors"]), 1)
            self.assertIn("binary minimum", result["errors"][0])

    def test_accept_older_binary_and_reject_newer_plist(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "runtime").write_bytes(bytes.fromhex("cffaedfe"))
            (root / "Info.plist").write_bytes(plistlib.dumps({"LSMinimumSystemVersion": "13.0"}))
            with patch.object(audit.subprocess, "check_output", return_value="Load command 1\n      cmd LC_BUILD_VERSION\n    minos 11.0\n"):
                result = audit.verify(root, "12.0")
            self.assertEqual(len(result["errors"]), 1)
            self.assertIn("app minimum", result["errors"][0])
            (root / "Info.plist").write_bytes(plistlib.dumps({"LSMinimumSystemVersion": "12.0"}))
            with patch.object(audit.subprocess, "check_output", return_value="Load command 1\n      cmd LC_BUILD_VERSION\n    minos 11.0\n"):
                self.assertEqual(audit.verify(root, "12.0")["errors"], [])
