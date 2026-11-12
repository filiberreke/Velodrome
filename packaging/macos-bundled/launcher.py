"""Start the existing macOS game and shared bridge together."""
import argparse
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import sys
import time

APP_NAME = "Velodrome 250 - Sprint Beta"


def game_executable(app):
    with (app / "Contents" / "Info.plist").open("rb") as source:
        name = plistlib.load(source)["CFBundleExecutable"]
    executable = app / "Contents" / "MacOS" / name
    if not executable.is_file():
        raise RuntimeError(f"Game executable missing: {executable}")
    return executable


def initialize_configs(root, executable, home=None):
    home = Path.home() if home is None else Path(home)
    user = home / "Library/Application Support/Godot/app_userdata" / APP_NAME / "config"
    for name in ("riders_config.cfg", "strava_config.cfg"):
        # Match config_paths.gd: preserve project, user and legacy files.
        if any(p.exists() for p in (executable.parent / "config" / name,
                                   executable.parent / name, user / name)):
            continue
        user.mkdir(parents=True, exist_ok=True)
        try:
            with (root / "defaults" / name).open("rb") as source, (user / name).open("xb") as target:
                shutil.copyfileobj(source, target)
        except FileExistsError:
            pass


def stop_process(process, timeout=15):
    if process.poll() is not None:
        return
    # SIGTERM is handled in the macOS bridge's asyncio loop. It cancels the
    # trainer loop, which attempts FTMS Reset before closing Bluetooth.
    process.terminate()
    try:
        process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        print("Proces sluit niet tijdig af; geforceerd stoppen. Trainerreset niet bevestigd.", flush=True)
        process.kill()
        process.wait()


def run(root, game_args=(), bridge_args=()):
    bridge = root / "bridge/VelodromeBridge.app/Contents/MacOS/VelodromeBridge"
    game = game_executable(root / "VelodromeGame.app")
    if not bridge.is_file():
        raise RuntimeError(f"Bridge missing: {bridge}")
    initialize_configs(root, game)
    worker = subprocess.Popen([str(bridge), *bridge_args], cwd=root, start_new_session=True)
    game_process = None
    try:
        game_process = subprocess.Popen([str(game), *game_args], cwd=root, start_new_session=True)
        while game_process.poll() is None:
            code = worker.poll()
            if code is not None:
                raise RuntimeError(f"Bridge stopte onverwacht (code {code}); spel wordt afgesloten.")
            time.sleep(0.2)
        return game_process.returncode
    finally:
        # Stop the game first so it cannot issue new trainer commands.
        if game_process is not None:
            stop_process(game_process)
        stop_process(worker)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-config", action="store_true")
    parser.add_argument("--no-ant", action="store_true")
    parser.add_argument("--smoke-test", action="store_true")
    args = parser.parse_args()
    root = Path(sys.executable).resolve().parents[1] if getattr(sys, "frozen", False) else Path(__file__).resolve().parent
    bridge = root / "bridge/VelodromeBridge.app/Contents/MacOS/VelodromeBridge"
    if args.check_config:
        game_executable(root / "VelodromeGame.app")
        for name in ("riders_config.cfg", "strava_config.cfg"):
            if not (root / "defaults" / name).is_file():
                raise RuntimeError(f"Missing default: {name}")
        subprocess.run([str(bridge), "--check-config", "--check-runtime"], check=True, cwd=Path.home())
        print("Combined macOS layout and configuration OK")
        return 0
    bridge_args = ["--no-ant"] if args.no_ant else []
    if args.smoke_test:
        # Exercise actual child lifecycle without Bluetooth/USB hardware.
        bridge_args = ["--software-test"]
    try:
        return run(root, ["--headless", "--quit-after", "3", "--verbose"] if args.smoke_test else [], bridge_args)
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    try:
        sys.exit(main())
    except Exception as exc:
        print(f"Velodrome starten mislukt: {exc}", file=sys.stderr)
        sys.exit(1)
