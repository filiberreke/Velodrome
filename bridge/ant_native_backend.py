"""ANT USB on macOS through libusb 1.0; no Windows driver or DLL."""
import ctypes.util
import sys
from pathlib import Path


def native_library_paths():
    paths = []
    if getattr(sys, "frozen", False):
        # PyInstaller resolves the bundled Frameworks directory here.
        paths.append(Path(sys._MEIPASS) / "libusb-1.0.dylib")
    paths.extend((Path("/opt/homebrew/lib/libusb-1.0.dylib"),
                  Path("/usr/local/lib/libusb-1.0.dylib")))
    return paths


def get_native_backend():
    from usb.backend import libusb1
    for path in native_library_paths():
        if path.is_file():
            backend = libusb1.get_backend(find_library=lambda _name, p=path: str(p))
            if backend is not None:
                return backend, str(path)
    located = ctypes.util.find_library("usb-1.0")
    backend = libusb1.get_backend(find_library=lambda _name: located) if located else None
    if backend is None:
        raise RuntimeError(
            "ANT+ libusb 1.0 ontbreekt. Gebruik de complete macOS-bundel; "
            "bij starten uit broncode: brew install libusb. "
            "Sluit Garmin Express en andere ANT+-apps.")
    return backend, located


def activate_native_backend():
    import usb.core
    backend, origin = get_native_backend()
    original = usb.core.find

    def find(*args, **kwargs):
        if kwargs.get("backend") is None:
            kwargs["backend"] = backend
        return original(*args, **kwargs)

    usb.core.find = find
    print("ANT+ backend: macOS libusb 1.0:", origin, flush=True)

    def restore():
        usb.core.find = original
    return restore
