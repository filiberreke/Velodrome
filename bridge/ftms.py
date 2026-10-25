def parse_bike_data(raw):
    """Bluetooth SIG FTMS Indoor Bike Data (0x2AD2)."""
    b = bytes(raw)
    if len(b) < 2:
        raise ValueError("FTMS data te kort")
    flags = int.from_bytes(b[:2], "little")
    position = 2
    out = {}

    def get(size, signed=False):
        nonlocal position
        if position + size > len(b):
            raise ValueError("Onvolledig FTMS-pakket")
        number = int.from_bytes(b[position:position + size], "little", signed=signed)
        position += size
        return number

    if not flags & 1: out["speed_kmh"] = get(2) / 100
    if flags & (1 << 1): get(2)
    if flags & (1 << 2): out["cadence_rpm"] = get(2) / 2
    if flags & (1 << 3): get(2)
    if flags & (1 << 4): get(3)
    if flags & (1 << 5): get(2, True)
    if flags & (1 << 6): out["power_w"] = get(2, True)
    if flags & (1 << 7): get(2, True)
    if flags & (1 << 8): get(2); get(2); get(1)
    if flags & (1 << 9): out["heart_bpm"] = get(1)
    if flags & (1 << 10): get(1)
    if flags & (1 << 11): get(2)
    if flags & (1 << 12): get(2)
    return out

