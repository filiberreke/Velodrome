def find_characteristics(client):
    """Pick Zwift service notification/indication/write endpoints.
    Older firmware uses 19ca UUIDs. Later firmware advertises FC82.
    """
    candidates = []
    for service in client.services:
        s_uuid = service.uuid.lower()
        if '19ca-4651-86e5-fa29dcdd09d1' in s_uuid or s_uuid.startswith('0000fc82-') or s_uuid == 'fc82':
            candidates.append(service)
    if not candidates:
        raise RuntimeError('Zwift BLE-service niet gevonden. Log met service-UUIDs nodig.')
    service = max(candidates, key=lambda x: len(x.characteristics))
    chars = list(service.characteristics)
    def with_id(suffix):
        return next((c for c in chars if c.uuid.lower().startswith(f'0000000{suffix}-')), None)
    async_char = with_id('2')
    write_char = with_id('3')
    indication_char = with_id('4')
    # New firmware may use new characteristic UUIDs, so fall back to capability discovery.
    if not async_char:
        async_char = next((c for c in chars if 'notify' in c.properties), None)
    if not write_char:
        write_char = next((c for c in chars if 'write' in c.properties or 'write-without-response' in c.properties), None)
    if not indication_char:
        indication_char = next((c for c in chars if 'indicate' in c.properties), None)
    if not all((async_char, write_char)):
        raise RuntimeError('Bluetooth-characteristics niet gevonden: ' + ', '.join(f'{c.uuid} ({c.properties})' for c in chars))
    return async_char, write_char, indication_char, [(c.uuid, c.properties) for c in chars]

