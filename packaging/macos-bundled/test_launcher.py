"""Configuration preservation and child lifecycle without hardware."""
import importlib.util
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location("mac_launcher", Path(__file__).with_name("launcher.py"))
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class LauncherTests(unittest.TestCase):
    def fixture(self, directory):
        root = Path(directory)
        executable = root / "VelodromeGame.app/Contents/MacOS/game"
        executable.parent.mkdir(parents=True)
        executable.touch()
        with (executable.parent.parent / "Info.plist").open("wb") as target:
            plistlib.dump({"CFBundleExecutable": "game"}, target)
        bridge = root / "bridge/VelodromeBridge.app/Contents/MacOS/VelodromeBridge"
        bridge.parent.mkdir(parents=True)
        bridge.touch()
        defaults = root / "defaults"
        defaults.mkdir()
        for name in ("riders_config.cfg", "strava_config.cfg"):
            (defaults / name).write_text("demo", encoding="utf-8")
        return root, executable

    def test_config_initialization_never_overwrites_personal_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root, executable = self.fixture(directory)
            home = root / "home"
            launcher.initialize_configs(root, executable, home)
            target = home / "Library/Application Support/Godot/app_userdata" / launcher.APP_NAME / "config/riders_config.cfg"
            self.assertEqual(target.read_text(), "demo")
            target.write_text("personal")
            launcher.initialize_configs(root, executable, home)
            self.assertEqual(target.read_text(), "personal")

    def test_legacy_config_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root, executable = self.fixture(directory)
            (executable.parent / "riders_config.cfg").write_text("personal")
            home = root / "home"
            launcher.initialize_configs(root, executable, home)
            target = home / "Library/Application Support/Godot/app_userdata" / launcher.APP_NAME / "config/riders_config.cfg"
            self.assertFalse(target.exists())

    def test_bridge_receives_termination_after_game_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            root, _ = self.fixture(directory)
            worker = Mock()
            worker.poll.return_value = None
            game = Mock(returncode=0)
            game.poll.return_value = 0
            with patch.object(launcher, "initialize_configs"), patch.object(launcher.subprocess, "Popen", side_effect=[worker, game]):
                self.assertEqual(launcher.run(root), 0)
            worker.terminate.assert_called_once()
            worker.wait.assert_called_once_with(timeout=15)

    def test_bridge_is_stopped_if_game_start_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            root, _ = self.fixture(directory)
            worker = Mock()
            worker.poll.return_value = None
            with patch.object(launcher, "initialize_configs"), patch.object(launcher.subprocess, "Popen", side_effect=[worker, OSError("game failed")]):
                with self.assertRaises(OSError):
                    launcher.run(root)
            worker.terminate.assert_called_once()

    def test_bridge_failure_stops_game(self):
        with tempfile.TemporaryDirectory() as directory:
            root, _ = self.fixture(directory)
            worker = Mock()
            worker.poll.return_value = 1
            game = Mock()
            game.poll.return_value = None
            with patch.object(launcher, "initialize_configs"), patch.object(launcher.subprocess, "Popen", side_effect=[worker, game]):
                with self.assertRaisesRegex(RuntimeError, "Bridge stopte"):
                    launcher.run(root)
            game.terminate.assert_called_once()

    def test_forced_kill_only_after_shutdown_timeout(self):
        process = Mock()
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired("bridge", 15), 0]
        launcher.stop_process(process)
        process.terminate.assert_called_once()
        process.kill.assert_called_once()


if __name__ == "__main__":
    unittest.main()
