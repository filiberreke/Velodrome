"""Small platform adapters; trainer and Ride protocols stay shared."""
import asyncio
import signal
import sys
from pathlib import Path


def bridge_log_path():
    if sys.platform == "darwin":
        directory = Path.home() / "Library" / "Logs" / "Velodrome"
        directory.mkdir(parents=True, exist_ok=True)
        return directory / "bridge.log"
    return Path(__file__).with_name("bridge.log")


async def console_input(prompt):
    if sys.platform != "darwin":
        return await asyncio.to_thread(input, prompt)
    # A cancellable stdin reader avoids a blocked executor thread keeping the
    # macOS bridge alive after the launcher requests graceful shutdown.
    loop = asyncio.get_running_loop()
    ready = loop.create_future()
    stream = sys.stdin
    if stream is None or stream.closed:
        raise EOFError
    print(prompt, end="", flush=True)

    def readable():
        if not ready.done():
            ready.set_result(stream.readline())

    descriptor = stream.fileno()
    loop.add_reader(descriptor, readable)
    try:
        line = await ready
        if not line:
            raise EOFError
        return line.rstrip("\r\n")
    finally:
        loop.remove_reader(descriptor)


def install_shutdown_handler():
    if sys.platform == "darwin":
        loop = asyncio.get_running_loop()
        loop.add_signal_handler(signal.SIGTERM, asyncio.current_task().cancel)


def check_platform_runtime():
    """Import native bindings and load libusb without scanning BLE or USB."""
    if sys.platform == "darwin":
        import CoreBluetooth
        import Foundation
        from ant_native_backend import get_native_backend
        backend, origin = get_native_backend()
        if backend is None:
            raise RuntimeError("ANT+ libusb backend ontbreekt")
        print("macOS runtime OK: CoreBluetooth, Foundation, ANT+ libusb:", origin)
