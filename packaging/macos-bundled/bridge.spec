# Console app bundle: launched in Terminal by Start-Velodrome.command.
import os
from pathlib import Path
root = Path(SPECPATH).resolve().parents[1]
bridge = root / "bridge"
a = Analysis(
    [str(bridge / "bridge.py")],
    pathex=[str(bridge)],
    binaries=[(os.environ["VELODROME_LIBUSB_PATH"], ".")],
    datas=[(str(p), ".") for p in bridge.glob("*.json")],
    hiddenimports=["bleak.backends.corebluetooth", "usb.backend.libusb1"],
)
pyz = PYZ(a.pure)
exe = EXE(pyz, a.scripts, [], exclude_binaries=True, name="VelodromeBridge",
          console=True, argv_emulation=False, codesign_identity=None)
coll = COLLECT(exe, a.binaries, a.datas, name="VelodromeBridge")
app = BUNDLE(coll, name="VelodromeBridge.app",
             bundle_identifier="org.velodrome.bridge", version="0.15.0",
             info_plist={
                 "NSBluetoothAlwaysUsageDescription": "Velodrome gebruikt Bluetooth voor je KICKR en Zwift Ride.",
                 "NSBluetoothPeripheralUsageDescription": "Velodrome gebruikt Bluetooth voor je KICKR en Zwift Ride.",
                 "LSMinimumSystemVersion": "13.0",
             })
