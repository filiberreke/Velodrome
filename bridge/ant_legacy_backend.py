"""Gebruik de bestaande Windows libusb-win32 (libusb0) driver voor ANTUSB2.

Verandert GEEN drivers of Windows-instellingen. Het installeert geen DLL.
Injecteert de PyUSB libusb0 backend in openant's USB-discovery uitsluitend
in het ANT+-proces. Bridge/BLE en andere USB-apparaten zijn niet geraakt.
"""
import ctypes.util
import os
import platform
import sys
from pathlib import Path

ANT_VID = 0x0FCF
ANT_PID = 0x1008


class LegacyBackendError(RuntimeError):
    pass


def candidate_libusb0_paths():
    """Windows systeemlocaties, zonder downloads of onveilige werkmap-DLL's."""
    if sys.platform != 'win32':
        return []
    root = Path(os.environ.get('SystemRoot', r'C:\Windows'))
    arch_64 = platform.architecture()[0] == '64bit'
    names = ('libusb0.dll', 'libusb0_x64.dll') if arch_64 else ('libusb0.dll',)
    folders = (root / 'System32', root / 'Sysnative') if arch_64 else (root / 'SysWOW64', root / 'System32')
    paths = [folder / name for folder in folders for name in names]
    # Optioneel: enkel expliciete absolute padnaam (door gebruiker gecontroleerd).
    custom = os.environ.get('ANT_LIBUSB0_DLL', '').strip().strip('"')
    if custom:
        path = Path(custom)
        if path.is_absolute():
            paths.insert(0, path)
    return paths


def get_legacy_backend():
    """Zoek uitsluitend libusb0 (API 0.1), nooit libusb-1.0."""
    try:
        from usb.backend import libusb0
    except ImportError as exc:
        raise LegacyBackendError('PyUSB ontbreekt; installeer requirements_ant.txt.') from exc

    # Default locator werkt op sommige systemen met libusb0.dll in PATH.
    backend = libusb0.get_backend()
    if backend is not None:
        return backend, 'libusb0 (standaard DLL-zoekpad)'
    tried = []
    for path in candidate_libusb0_paths():
        if not path.is_file():
            continue
        tried.append(str(path))
        try:
            backend = libusb0.get_backend(find_library=lambda _lib, p=path: str(p))
        except (OSError, ValueError):
            continue
        if backend is not None:
            return backend, str(path)
    # ctypes locator is vaak nuttig voor probleemdiagnose, niet als implicit fallback
    located = ctypes.util.find_library('libusb0')
    detail = f'gevonden via Windows: {located}' if located else 'niet gevonden'
    raise LegacyBackendError(
        'Oud libusb0-programmaonderdeel (libusb0.dll) ontbreekt of heeft verkeerde bitness; '
        + detail + '. Controleer Apparaatbeheer > ANT USB Stick 2 > '
        + 'Stuurprogramma > Details: staat libusb0.sys erbij? '
        + 'GEEN drivers vervangen. Als libusb0.sys aanwezig is, vraag waar '
        + 'de bijpassende libusb0.dll staat en geef het pad door.')


def activate_legacy_backend(find_func=None, backend=None, verbose=True):
    """Patch alleen de lokale PyUSB-discovery voor de huidige processessie.

    Geef voor een test backend mee, dan wordt geen DLL geladen.
    Geeft de onpatch-callback terug voor test/cleanup.
    """
    import usb.core
    if backend is None:
        backend, origin = get_legacy_backend()
    else:
        origin = 'mock/test-backend'
    original_find = find_func or usb.core.find
    if verbose:
        print('ANT+ USB-driver behouden (geen driverinstallatie).')
        print('ANT+ backend: oudere libusb0; bron:', origin)

    def find_with_legacy(*args, **kwargs):
        # Andere velden behouden; alleen backend expliciet doorgeven.
        if kwargs.get('backend') is None:
            kwargs['backend'] = backend
        return original_find(*args, **kwargs)
    usb.core.find = find_with_legacy

    def restore():
        usb.core.find = original_find
    return restore


def report_legacy_adapter():
    import usb.core
    devices = list(usb.core.find(find_all=True, idVendor=ANT_VID, idProduct=ANT_PID))
    print(f'ANT+ legacy: {len(devices)} ANTUSB2-stick(s) gevonden (0FCF:1008).')
    if not devices:
        raise LegacyBackendError('Geen ANTUSB2 zichtbaar via libusb0. '
            'Controleer in Apparaatbeheer > Stuurprogramma > Details of libusb0.sys actief is; '
            'sluit Garmin Express en andere ANT+-apps. Verander geen driver.')
    return devices
