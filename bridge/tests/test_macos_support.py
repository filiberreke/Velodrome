"""Platform selection, cancellable console and shared device identity tests."""
import asyncio
import io
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import ant_backend
import ant_native_backend
import platform_support
from selection import select_left_ride


class BackendTests(unittest.TestCase):
    def test_windows_keeps_legacy_backend_and_adapter_check(self):
        legacy = SimpleNamespace(activate_legacy_backend=Mock(return_value=Mock()),
                                 report_legacy_adapter=Mock())
        with patch.object(sys, "platform", "win32"), patch.dict(sys.modules, ant_legacy_backend=legacy):
            restore = ant_backend.activate_backend()
        legacy.activate_legacy_backend.assert_called_once()
        legacy.report_legacy_adapter.assert_called_once()
        self.assertIs(restore, legacy.activate_legacy_backend.return_value)

    def test_windows_restores_on_adapter_error(self):
        restore = Mock()
        legacy = SimpleNamespace(activate_legacy_backend=Mock(return_value=restore),
                                 report_legacy_adapter=Mock(side_effect=RuntimeError("adapter missing")))
        with patch.object(sys, "platform", "win32"), patch.dict(sys.modules, ant_legacy_backend=legacy):
            with self.assertRaisesRegex(RuntimeError, "adapter missing"):
                ant_backend.activate_backend()
        restore.assert_called_once()

    def test_macos_uses_native_backend(self):
        with patch.object(sys, "platform", "darwin"), patch.object(ant_native_backend, "activate_native_backend") as native:
            self.assertIs(ant_backend.activate_backend(), native.return_value)
        native.assert_called_once()

    def test_macos_rejects_windows_backend(self):
        with patch.object(sys, "platform", "darwin"):
            with self.assertRaisesRegex(ValueError, "Windows"):
                ant_backend.activate_backend("legacy")

    def test_bundled_libusb_is_searched_first(self):
        with patch.object(sys, "frozen", True, create=True), patch.object(sys, "_MEIPASS", "/bundle/Frameworks", create=True):
            self.assertEqual(str(ant_native_backend.native_library_paths()[0]).replace("\\", "/"),
                             "/bundle/Frameworks/libusb-1.0.dylib")

    def test_native_backend_injection_preserves_explicit_backend_and_restores(self):
        find = Mock()
        core = SimpleNamespace(find=find)
        backend = object()
        with patch.dict(sys.modules, {"usb": SimpleNamespace(core=core), "usb.core": core}), patch.object(ant_native_backend, "get_native_backend", return_value=(backend, "bundled")):
            restore = ant_native_backend.activate_native_backend()
            core.find(idVendor=0x0fcf)
            find.assert_called_with(idVendor=0x0fcf, backend=backend)
            explicit = object()
            core.find(backend=explicit)
            find.assert_called_with(backend=explicit)
            restore()
            self.assertIs(core.find, find)

    def test_macos_logs_live_outside_bundle(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(sys, "platform", "darwin"), patch.object(platform_support.Path, "home", return_value=Path(directory)):
            result = platform_support.bridge_log_path()
            self.assertEqual(result, Path(directory) / "Library/Logs/Velodrome/bridge.log")
            self.assertTrue(result.parent.is_dir())

    def test_mac_uuid_selects_left_ride_without_mac_address(self):
        device = SimpleNamespace(name=None, address="243E23AE-4A99-406C-B317-18F1BD7B4CBE")
        advertisement = SimpleNamespace(local_name="Zwift Ride", manufacturer_data={0x094A: b"\x08"})
        records = [(device, advertisement)]
        self.assertIs(select_left_ride(records, device.address.lower()), device)
        self.assertIs(select_left_ride(records), device)


@unittest.skipIf(os.name == "nt", "POSIX stdin reader")
class ConsoleTests(unittest.IsolatedAsyncioTestCase):
    async def test_line_and_eof(self):
        read, write = os.pipe()
        with os.fdopen(read) as stream, patch.object(sys, "stdin", stream), patch.object(sys, "platform", "darwin"):
            os.write(write, b"status\n")
            self.assertEqual(await platform_support.console_input(""), "status")
            os.close(write)
            with self.assertRaises(EOFError):
                await platform_support.console_input("")

    async def test_cancellation_removes_reader_without_waiting_for_enter(self):
        read, write = os.pipe()
        try:
            with os.fdopen(read) as stream, patch.object(sys, "stdin", stream), patch.object(sys, "platform", "darwin"):
                task = asyncio.create_task(platform_support.console_input(""))
                await asyncio.sleep(0)
                task.cancel()
                with self.assertRaises(asyncio.CancelledError):
                    await task
                self.assertFalse(asyncio.get_running_loop().remove_reader(read))
        finally:
            os.close(write)
