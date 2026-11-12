"""Choose the native ANT USB backend, preserving Windows libusb0."""
import sys


def activate_backend(backend="auto"):
    if backend not in ("auto", "legacy", "native"):
        raise ValueError("Onbekende ANT+ backend: " + backend)
    selected = ("legacy" if sys.platform == "win32" else "native") if backend == "auto" else backend
    if selected == "legacy":
        if sys.platform != "win32":
            raise ValueError("De legacy libusb0-backend is uitsluitend voor Windows")
        from ant_legacy_backend import activate_legacy_backend, report_legacy_adapter
        restore = activate_legacy_backend()
        try:
            report_legacy_adapter()
        except Exception:
            restore()
            raise
        return restore
    if sys.platform == "darwin":
        from ant_native_backend import activate_native_backend
        return activate_native_backend()
    # Linux keeps openant/PyUSB's own native backend discovery.
    return lambda: None
