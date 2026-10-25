"""Zwift Ride button map decoder, based on public protocol documentation."""
BUTTON_BITS = {
    'LEFT': 0x1, 'UP': 0x2, 'RIGHT': 0x4, 'DOWN': 0x8,
    'A': 0x10, 'B': 0x20, 'Y': 0x40, 'Z': 0x100,
    'SHIFT_UP_LEFT': 0x200, 'SHIFT_DOWN_LEFT': 0x400,
    'POWER_LEFT': 0x800, 'ONOFF_LEFT': 0x1000,
    'SHIFT_UP_RIGHT': 0x2000, 'SHIFT_DOWN_RIGHT': 0x4000,
    'POWER_RIGHT': 0x10000, 'ONOFF_RIGHT': 0x20000,
}

def read_varint(buf, pos):
    result = 0
    for shift in range(0, 70, 7):
        if pos >= len(buf):
            raise ValueError('Truncated protobuf varint')
        byte = buf[pos]
        pos += 1
        result |= (byte & 0x7f) << shift
        if not byte & 0x80:
            return result, pos
    raise ValueError('Varint too long')

def decode_packet(data):
    """Return pressed buttons, or None for non-keyboard notifications."""
    data = bytes(data)
    if not data or data[0] != 0x23:
        return None
    pos = 1
    bitmap = None
    while pos < len(data):
        tag, pos = read_varint(data, pos)
        field, wire = tag >> 3, tag & 7
        if not field:
            raise ValueError('Invalid protobuf field')
        if wire == 0:
            value, pos = read_varint(data, pos)
            if field == 1:
                bitmap = value
        elif wire == 1:
            pos += 8
        elif wire == 2:
            size, pos = read_varint(data, pos)
            pos += size
        elif wire == 5:
            pos += 4
        else:
            raise ValueError('Unsupported protobuf wire type')
        if pos > len(data):
            raise ValueError('Truncated protobuf field')
    if bitmap is None:
        return None
    return {name for name, bit in BUTTON_BITS.items() if not bitmap & bit}
