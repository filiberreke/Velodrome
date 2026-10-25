"""FTMS Set Target Power encoding; intentionally dependency-free for tests."""
import struct
MIN_TARGET = 0
MAX_TARGET = 1300
POWER_RANGE = '00002ad8-0000-1000-8000-00805f9b34fb'
TARGET_POWER_FEATURE = 1 << 3

def encode_target_power(watts: int) -> bytes:
    if type(watts) is not int or not MIN_TARGET <= watts <= MAX_TARGET:
        raise ValueError(f"ERG-doel moet geheel getal van {MIN_TARGET} t/m {MAX_TARGET} W zijn")
    return b"\x05" + struct.pack("<h", watts)

def parse_power_range(raw):
    if len(raw) != 6:
        raise ValueError('0x2AD8 moet exact zes bytes bevatten')
    minimum, maximum, increment = struct.unpack('<hhH', raw)
    if minimum > maximum or maximum <= 0 or increment == 0:
        raise ValueError('Ongeldig FTMS-vermogensbereik')
    return minimum, maximum, increment
