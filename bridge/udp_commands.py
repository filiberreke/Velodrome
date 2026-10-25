"""Local JSON command ingress. No BLE I/O or tasks are created by datagrams."""
import asyncio
import json
import logging
import re
import time
from collections import OrderedDict
from combined_mode import CommandError

HOST, PORT = '127.0.0.1', 51725
MAX_PACKET = 1024
CACHE_SECONDS, CACHE_SIZE = 60.0, 2048
log = logging.getLogger(__name__)
SCHEMA = {'set_mode': {'mode'}, 'set_target_power': {'watts', 'ramp_w_per_s'},
          'set_grade': {'grade_pct', 'ramp_pct_per_s', 'aero_scale'},
          'stop': set(), 'status': set(), 'heartbeat': set()}
REQUIRED = {'set_mode': {'mode'}, 'set_target_power': {'watts'}, 'set_grade': {'grade_pct'}}

def pairs_unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Dubbele JSON-sleutel')
        result[key] = value
    return result

def reject_constant(value):
    raise ValueError('Niet-eindig JSON-getal')

def decode_command(data):
    if not 0 < len(data) <= MAX_PACKET:
        raise CommandError('invalid_packet', 'Datagram moet 1..1024 bytes zijn')
    try:
        obj = json.loads(data.decode('utf-8'), object_pairs_hook=pairs_unique, parse_constant=reject_constant)
    except (ValueError, UnicodeError, RecursionError) as exc:
        raise CommandError('invalid_json', 'Strikt UTF-8 JSON-object vereist, zonder dubbele sleutels/NaN/Infinity') from exc
    if not isinstance(obj, dict):
        raise CommandError('invalid_packet', 'JSON-object vereist')
    command_id = obj.get('id')
    if not isinstance(command_id, str) or re.fullmatch(r'[A-Za-z0-9_.:-]{1,64}', command_id) is None:
        raise CommandError('invalid_id', 'id: 1..64 ASCII letters/cijfers/_.:-')
    if obj.get('type') != 'command' or type(obj.get('v')) is not int or obj['v'] != 1:
        raise CommandError('invalid_envelope', 'type=command en v=1 vereist')
    command = obj.get('command')
    if not isinstance(command, str) or command not in SCHEMA:
        raise CommandError('unknown_command', 'Onbekend commando')
    params = {k: v for k, v in obj.items() if k not in ('type', 'v', 'id', 'command')}
    if set(params) - SCHEMA[command] or not REQUIRED.get(command, set()) <= set(params):
        raise CommandError('invalid_fields', 'Onbekende of ontbrekende velden')
    return obj, command, params

class CommandProtocol(asyncio.DatagramProtocol):
    def __init__(self, combined, clock=time.monotonic):
        self.combined = combined
        self.clock = clock
        self.transport = None
        self.cache = OrderedDict()
        self.tokens = 100.0
        self.token_at = clock()

    def connection_made(self, transport):
        self.transport = transport

    def error_received(self, exc):
        log.warning('UDP command socket: %s', exc)

    def reply(self, packet, addr):
        raw = json.dumps(packet, ensure_ascii=True, allow_nan=False, separators=(',', ':')).encode('utf-8')
        self.transport.sendto(raw, addr)
        return raw

    def datagram_received(self, data, addr):
        if addr[0] != HOST:
            return
        now = self.clock()
        self.tokens = min(100.0, self.tokens + max(0.0, now - self.token_at) * 50.0)
        self.token_at = now
        if self.tokens < 1:
            return  # Bounded work/logging under flood; no lease refresh.
        self.tokens -= 1
        while self.cache and next(iter(self.cache.values()))[0] <= now:
            self.cache.popitem(last=False)
        obj = None
        try:
            obj, command, params = decode_command(data)
            key = (addr, obj['id'])
            fingerprint = json.dumps(obj, sort_keys=True, separators=(',', ':'))
            cached = self.cache.get(key)
            if cached:
                if cached[1] != fingerprint:
                    raise CommandError('id_conflict', 'id al gebruikt met een andere opdracht')
                self.transport.sendto(cached[2], addr)
                return  # Retries never refresh a lease or repeat control actions.
            if len(self.cache) >= CACHE_SIZE and command != 'stop':
                raise CommandError('server_busy', 'Deduplicatiecache vol; probeer later met nieuw id')
            try:
                state = self.combined.accept(command, params, source=addr)
                packet = {'type': 'ack', 'v': 1, 'id': obj['id'], 'ok': True,
                          'result': 'snapshot' if command == 'status' else 'accepted', 'state': state}
            except CommandError as exc:
                packet = self.error(obj['id'], exc)
            raw = self.reply(packet, addr)
            if len(self.cache) < CACHE_SIZE:
                self.cache[key] = (now + CACHE_SECONDS, fingerprint, raw)
            log.info('UDP %s id=%s command=%s result=%s', addr, obj['id'], command, packet['type'])
        except CommandError as exc:
            self.reply(self.error(obj['id'] if obj else None, exc), addr)
            log.warning('UDP geweigerd %s: %s', addr, exc.code)

    def error(self, command_id, exc):
        return {'type': 'error', 'v': 1, 'id': command_id, 'ok': False,
                'code': exc.code, 'message': str(exc), 'state': self.combined.status()}

