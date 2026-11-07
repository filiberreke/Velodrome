"""Select BLE devices using advertisement names and Zwift Ride role data."""


def advertised_name(device, advertisement):
    return (getattr(advertisement, 'local_name', None)
            or getattr(device, 'name', None) or '').strip()


def is_left_ride(device, advertisement):
    """Same manufacturer marker used by our working keyboard mapper."""
    data = getattr(advertisement, 'manufacturer_data', {}) or {}
    marker = data.get(0x094A, b'')
    return bool(marker and marker[0] == 8)


FTMS_UUID = "00001826-0000-1000-8000-00805f9b34fb"
TRAINER_NAME_TOKENS = ("kickr", "tacx", "neo", "flux", "elite", "direto", "suito", "justo")


def advertises_ftms(advertisement):
    services = getattr(advertisement, 'service_uuids', None) or ()
    return any(str(service).casefold() in ("1826", "0x1826", FTMS_UUID)
               for service in services)


def select_device(records, query, default_tokens=()):
    """Ordinary BLE name selection (trainer etc.)."""
    needle = (query or '').strip().casefold()
    tokens = tuple(t.casefold() for t in default_tokens) or TRAINER_NAME_TOKENS
    if not needle:
        for device, advertisement in records:
            if advertises_ftms(advertisement):
                return device
    for device, advertisement in records:
        names = (advertised_name(device, advertisement), getattr(device, 'name', '') or '')
        if needle:
            if any(needle in name.casefold() for name in names):
                return device
        elif any(token in name.casefold() for token in tokens for name in names):
            return device
    return None


def select_left_ride(records, explicit_query=''):
    """Fail closed when left master cannot be unambiguously identified.

    An explicit address or address substring can override the auto selection,
    e.g. --ride DE:52:81:64:38:94. Explicit names matching two devices fail.
    """
    query = explicit_query.strip().casefold()
    candidates = [(device, adv) for device, adv in records
                  if 'zwift' in advertised_name(device, adv).casefold()
                  or 'sf2' in advertised_name(device, adv).casefold()
                  or is_left_ride(device, adv)]
    if query:
        matched = [(device, adv) for device, adv in candidates
                   if query in str(getattr(device, 'address', '')).casefold()
                   or query in advertised_name(device, adv).casefold()]
        return matched[0][0] if len(matched) == 1 else None
    left = [(device, adv) for device, adv in candidates if is_left_ride(device, adv)]
    return left[0][0] if len(left) == 1 else None
