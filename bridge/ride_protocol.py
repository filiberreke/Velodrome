"""Zwift Ride digital/analog decoder for legacy and current 0x23 layouts."""
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

def fields(data):
    """Read bounded protobuf fields, leaving nested messages as bytes."""
    pos = 0
    while pos < len(data):
        tag, pos = read_varint(data, pos)
        field, wire = tag >> 3, tag & 7
        if not field:
            raise ValueError('Invalid protobuf field')
        if wire == 0:
            value, pos = read_varint(data, pos)
        elif wire == 1:
            value = data[pos:pos + 8]
            pos += 8
        elif wire == 2:
            size, pos = read_varint(data, pos)
            value = data[pos:pos + size]
            pos += size
        elif wire == 5:
            value = data[pos:pos + 4]
            pos += 4
        else:
            raise ValueError('Unsupported protobuf wire type')
        if pos > len(data):
            raise ValueError('Truncated protobuf field')
        yield field, wire, value


def decode_state(data):
    """Decode digital buttons and signed analog paddles from a Ride 0x23 frame.

    Older captures wrap analog entries in field 2; current implementations use
    repeated field 3 directly. Missing paddles are omitted, not assumed released.
    """
    data = bytes(data)
    if not data or data[0] != 0x23:
        return None
    bitmap = None
    paddles = {}

    def analog(entry):
        location = value = None
        for field, wire, raw in fields(entry):
            if field == 1 and wire == 0: location = raw
            elif field == 2 and wire == 0: value = (raw >> 1) ^ -(raw & 1)
        if location not in (0, 1) or value is None:
            return
        if not -100 <= value <= 100:
            raise ValueError('Analog paddle outside -100..100')
        if location in paddles and paddles[location] != value:
            raise ValueError('Conflicting analog paddle values')
        paddles[location] = value

    for field, wire, value in fields(data[1:]):
        if field == 1 and wire == 0:
            if value > 0xffffffff: raise ValueError('Button map outside uint32')
            bitmap = value
        elif field == 2 and wire == 2:
            for nested, kind, entry in fields(value):
                if nested == 1 and kind == 2: analog(entry)
        elif field == 3 and wire == 2:
            analog(value)
    buttons = None if bitmap is None else {name for name, bit in BUTTON_BITS.items() if not bitmap & bit}
    return {'buttons': buttons, 'paddles': paddles}


def decode_packet(data):
    """Compatibility wrapper for callers interested only in digital buttons."""
    state = decode_state(data)
    return state['buttons'] if state is not None else None
