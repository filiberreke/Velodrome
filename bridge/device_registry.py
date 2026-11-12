"""Live, capability-filtered inventory. Selection ACK precedes reconnection.

Only advertisements actually observed by this bridge are selectable. None is
legacy automatic selection; an empty string explicitly disables a role.
"""
import asyncio
import json
import time
from pathlib import Path
from combined_mode import CommandError
from selection import advertised_name, is_left_ride
from hr_bridge import HeartRateState

ROLES = ('trainer', 'controller', 'heart_rate')
HR_SERVICE = '0000180d-0000-1000-8000-00805f9b34fb'
HR_MEASUREMENT = '00002a37-0000-1000-8000-00805f9b34fb'
FTMS_SERVICE = '00001826-0000-1000-8000-00805f9b34fb'


def capabilities(device, adv):
    services = {str(s).lower() for s in (getattr(adv, 'service_uuids', []) or [])}
    roles = []
    if FTMS_SERVICE in services:
        roles.append('trainer')
    if is_left_ride(device, adv):
        roles.append('controller')
    if HR_SERVICE in services:
        roles.append('heart_rate')
    return roles


def decode_ble_hr(data):
    if len(data) < 2 or (data[0] & 1 and len(data) < 3):
        return None
    return int.from_bytes(data[1:3], 'little') if data[0] & 1 else data[1]


class DeviceRegistry:
    def __init__(self, discovery, ant_state, path=None, clock=time.monotonic):
        self.discovery, self.ant_state, self.clock = discovery, ant_state, clock
        self.path = Path(path) if path else None
        self.selected = dict.fromkeys(ROLES)
        self.revision = dict.fromkeys(ROLES, 0)
        self.inventory = {}
        self.connected = dict.fromkeys(ROLES, '')
        self.chosen = dict.fromkeys(ROLES, '')
        self.ble_hr = HeartRateState(clock)
        self.scan_error = ''
        if self.path and self.path.exists():
            try:
                saved = json.loads(self.path.read_text(encoding='utf-8'))
                for role in ROLES:
                    value = saved.get(role)
                    if value is None or isinstance(value, str):
                        self.selected[role] = value
            except (OSError, ValueError, AttributeError):
                self.scan_error = 'Opgeslagen selecties konden niet worden gelezen'

    def observe(self, records):
        for device, adv in records:
            roles = capabilities(device, adv)
            if roles:
                address = str(device.address)
                self.inventory[address] = {
                    'address': address, 'name': advertised_name(device, adv) or address,
                    'roles': roles, 'transport': 'BLE', 'seen': self.clock(), 'device': device}

    async def scan_loop(self):
        while True:
            self.observe(await self.discovery.records())
            self.scan_error = getattr(self.discovery, 'error', '')
            await asyncio.sleep(3)

    def snapshot(self):
        devices = []
        for address, row in self.inventory.items():
            available = self.clock() - row['seen'] < 30 or address in self.connected.values()
            if available or address in self.selected.values():
                devices.append({k: row[k] for k in ('address', 'name', 'roles', 'transport')} |
                               {'available': available})
        # The current ANT backend exposes a single wildcard HR stream, not a
        # sensor identity. Never pretend it found an individual Garmin ID.
        if self.ant_state.current_bpm() is not None:
            devices.append({'address': 'ant:active', 'name': 'ANT+ hartslag (actieve zender)',
                            'roles': ['heart_rate'], 'transport': 'ANT+', 'available': True})
        connected = dict(self.connected)
        if self.selected['heart_rate'] in (None, 'ant:active') and self.ant_state.current_bpm() is not None:
            connected['heart_rate'] = 'ant:active'
        return {'device_selection_v': 1, 'devices': devices,
                'selected': dict(self.selected), 'connected': connected,
                'scan_error': self.scan_error}

    def accept(self, command, params):
        if command == 'select_device':
            role, address = params['role'], params['address']
            if not isinstance(role, str) or role not in ROLES or not isinstance(address, str):
                raise CommandError('invalid_selection', 'Ongeldige rol of adres')
            if address and not any(d['address'] == address and role in d['roles'] and d['available']
                                   for d in self.snapshot()['devices']):
                raise CommandError('device_unavailable', 'Apparaat niet gevonden of rol niet ondersteund')
            if self.selected[role] != address:
                updated = self.selected | {role: address}
                if self.path:
                    try:
                        temporary = self.path.with_suffix('.tmp')
                        temporary.write_text(json.dumps(updated), encoding='utf-8')
                        temporary.replace(self.path)
                    except OSError as exc:
                        raise CommandError('save_failed', 'Selectie kon niet worden opgeslagen') from exc
                self.selected = updated
                self.revision[role] += 1
        return self.snapshot()

    def choose(self, role, records, fallback):
        self.observe(records)
        selected = self.selected[role]
        if selected is None:
            device = fallback(records)
            if device:
                self.chosen[role] = str(device.address)
            return device
        for device, adv in records:
            if str(device.address) == selected and role in capabilities(device, adv):
                self.chosen[role] = selected
                return device
        return None

    def bpm(self):
        selected = self.selected['heart_rate']
        if selected is None or selected == 'ant:active':
            return self.ant_state.current_bpm()
        return self.ble_hr.current_bpm() if selected else None

    async def hr_loop(self, client_type):
        while True:
            selected = self.selected['heart_rate']
            row = self.inventory.get(selected)
            if row and self.clock() - row['seen'] < 30:
                async with client_type(row['device'], timeout=18.0) as client:
                    await client.start_notify(HR_MEASUREMENT, lambda _, data: self.ble_hr.update(decode_ble_hr(data)))
                    self.connected['heart_rate'] = selected
                    while client.is_connected:
                        await asyncio.sleep(0.5)
            else:
                await asyncio.sleep(1)

    async def supervise(self, role, factory, cleanup):
        """Serialize role switches: old BLE context/reset finishes before new link."""
        while True:
            revision = self.revision[role]
            task = asyncio.create_task(factory())
            try:
                while revision == self.revision[role] and not task.done():
                    await asyncio.sleep(0.1)
            finally:
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    pass
                except Exception as exc:
                    print(role, 'verbinding:', exc)
                self.connected[role] = ''
                cleanup()
            await asyncio.sleep(0.1)
