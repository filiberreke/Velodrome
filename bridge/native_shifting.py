"""Experimental native trainer shifting, selected explicitly with --native-shifting.

Two trainer-side protocols are supported; NATIVE_SHIFTING.md documents both:

* zwift-hub   service 00000001-19ca..., RideOn handshake with reply, gear ratio and
              road simulation as 0x04 protobuf commands, ratio echoed as 0x3c/520.
* wahoo-fc82  service 0xFC82 (Wahoo KICKR family), RideOn 02 03 handshake, gear ratio
              as 0x3f protobuf command without reply. Road grade stays on FTMS 0x11.

The existing 12-gear ladder is retained; ratios go to the trainer independently of
road grade.
"""
import asyncio
import logging
import time

from resistance import FEATURE, ResistanceController
from ride_protocol import fields
from simulation import RoadSimulation, SIMULATION_FEATURE, encode_simulation, validate_aero_scale

log = logging.getLogger(__name__)

HUB = 'zwift-hub'
FC82 = 'wahoo-fc82'
PROTOCOLS = ('auto', HUB, FC82)

SERVICE = '00000001-19ca-4651-86e5-fa29dcdd09d1'
FC82_SERVICE = '0000fc82-0000-1000-8000-00805f9b34fb'
WRITE = '00000003-19ca-4651-86e5-fa29dcdd09d1'
NOTIFY = '00000002-19ca-4651-86e5-fa29dcdd09d1'
INDICATE = '00000004-19ca-4651-86e5-fa29dcdd09d1'
GREETING = b'RideOn\x02'
FC82_GREETING = b'RideOn\x02\x03'
NEUTRAL_RATIO = 24000
MIN_RATIO, MAX_RATIO = 7500, 54899
# Zwift's own ratio table contains float-truncated values (26099, 42399, 54899).
# A trainer that stores the ratio as float may echo 1 unit lower than requested.
RATIO_TOLERANCE = 2
WRITE_TIMEOUT_S = 5.0
LOGGED_NOTIFICATIONS = 12


class NativeUnsupported(RuntimeError):
    """Trainer lacks the requested native service; reconnecting cannot fix it."""


def ratio_matches(reported, requested):
    return reported is not None and abs(reported - requested) <= RATIO_TOLERANCE


def varint(value):
    if type(value) is not int or not 0 <= value <= 0xffffffff:
        raise ValueError('Expected uint32')
    result = bytearray()
    while value >= 128:
        result.append((value & 127) | 128)
        value >>= 7
    result.append(value)
    return bytes(result)


def integer(field, value):
    return varint(field << 3) + varint(value)


def message(field, payload):
    return varint((field << 3) | 2) + varint(len(payload)) + payload


def check_ratio(ratio):
    if type(ratio) is not int or not MIN_RATIO <= ratio <= MAX_RATIO:
        raise ValueError('Native ratio outside tested protocol range')
    return ratio


def encode_road(grade, crr, cw):
    """Zwift hub opcode 4, simulation field 4. Signed incline uses protobuf zigzag."""
    incline = round(grade * 100)
    if not -2000 <= incline <= 2000 or not 0 <= crr <= .0255 or not 0 <= cw <= 2.55:
        raise ValueError('Native simulation outside supported road domain')
    zigzag = (incline << 1) ^ (incline >> 31)
    payload = integer(1, 0) + integer(2, zigzag)
    payload += integer(3, round(cw * 10000)) + integer(4, round(crr * 100000))
    return b'\x04' + message(4, payload)


def encode_ratio(ratio):
    """Zwift hub opcode 4, physical field 5, ratio x10000 in field 2."""
    return b'\x04' + message(5, integer(2, check_ratio(ratio)))


def encode_fc82_ratio(ratio, sequence):
    """Wahoo 0x3f: command_type 1 (gear ratio), sequence, payload field 7."""
    return b'\x3f' + integer(1, 1) + integer(2, sequence) + message(4, integer(7, check_ratio(ratio)))


def read_ratio(data):
    if not data or data[0] != 0x3c or len(data) > 512:
        return None
    envelope = {field: value for field, _, value in fields(data[1:])}
    if envelope.get(1) != 520 or not isinstance(envelope.get(2), bytes):
        return None
    response = {field: value for field, _, value in fields(envelope[2])}
    if not isinstance(response.get(1), bytes):
        return None
    values = {field: value for field, _, value in fields(response[1])}
    ratio = values.get(8)
    return ratio if type(ratio) is int and MIN_RATIO <= ratio <= MAX_RATIO else None


def _uuid(item):
    return str(getattr(item, 'uuid', item)).lower()


def _service(client, uuid):
    return next((s for s in client.services if _uuid(s) == uuid), None)


def _characteristic(service, uuid):
    return next((c for c in service.characteristics if _uuid(c) == uuid), None)


class NativeController(ResistanceController):
    """All writes run through CombinedMode's existing single writer."""
    def __init__(self, client, protocol='auto'):
        if protocol not in PROTOCOLS:
            raise ValueError(f'native protocol moet een van {PROTOCOLS} zijn')
        super().__init__(client)
        self.requested_protocol = protocol
        self.protocol = None
        self.native_ready = False
        self.confirmed_ratio = None
        self.written_ratio = None
        self._greeting = None
        self._ratio_waiter = None
        self._native_subscribed = False
        self._write_char = None
        self._write_response = True
        self._listen = []
        self._sequence = 0
        self._logged = 0

    def _select(self):
        hub = _service(self.client, SERVICE)
        fc82 = _service(self.client, FC82_SERVICE)
        names = ', '.join(_uuid(s) for s in self.client.services)
        if self.requested_protocol in ('auto', HUB) and hub is not None:
            write = _characteristic(hub, WRITE)
            indicate = _characteristic(hub, INDICATE)
            if write is None or indicate is None:
                raise NativeUnsupported('Zwift hub-service mist write/indicate characteristic')
            self._listen = [indicate] + [c for c in (_characteristic(hub, NOTIFY),) if c is not None]
            return HUB, write
        if self.requested_protocol in ('auto', FC82) and fc82 is not None:
            write = _characteristic(fc82, WRITE)
            if write is None:
                raise NativeUnsupported('FC82-service mist control characteristic 00000003')
            # No reply is documented; subscribe only to log what the trainer reports.
            self._listen = [c for c in fc82.characteristics
                            if {'notify', 'indicate'} & set(getattr(c, 'properties', ()))]
            return FC82, write
        raise NativeUnsupported(f'Geen native shifting-service ({self.requested_protocol}) gevonden. '
                                f'Services: {names}. Gebruik de bridge zonder --native-shifting.')

    async def initialize(self):
        protocol, write = self._select()
        if protocol == FC82:
            # FC82 only carries the gear; grade needs FTMS Indoor Bike Simulation.
            raw = bytes(await self.client.read_gatt_char(FEATURE))
            if len(raw) < 8 or not int.from_bytes(raw[4:8], 'little') & SIMULATION_FEATURE:
                raise NativeUnsupported('FC82-trainer meldt geen FTMS-simulatie; helling kan niet worden gestuurd')
        self.protocol, self._write_char = protocol, write
        properties = set(getattr(write, 'properties', ('write',)))
        self._write_response = 'write' in properties or 'write-without-response' not in properties
        await super().initialize()
        log.info('Native protocol=%s write=%s response=%s', protocol, _uuid(write), self._write_response)

    def _native_notify(self, char, data):
        data = bytes(data)
        if self._logged < LOGGED_NOTIFICATIONS:
            self._logged += 1
            log.info('Native %s notify %s: %s', self.protocol, _uuid(char), data.hex())
        # Reference emulators answer RideOn 02 00; accept any RideOn reply so a
        # different status suffix on real hardware does not time out the handshake.
        if data.startswith(b'RideOn') and self._greeting is not None:
            if not self._greeting.done():
                self._greeting.set_result(True)
            return
        try:
            ratio = read_ratio(data)
        except (ValueError, TypeError):
            log.warning('Ongeldig native trainerbericht: %s', data.hex())
            return
        if ratio is not None:
            self.confirmed_ratio = ratio
            if self._ratio_waiter is not None:
                expected, future = self._ratio_waiter
                if ratio_matches(ratio, expected) and not future.done():
                    future.set_result(True)

    async def _write_native(self, packet):
        if not self.active or self.faulted or self._write_char is None:
            raise RuntimeError('Native trainercontrol niet actief')
        # Same 5 s bound as FTMS command(); a hung write must not stall the loop.
        async with asyncio.timeout(WRITE_TIMEOUT_S):
            await self.client.write_gatt_char(self._write_char, packet, response=self._write_response)

    async def prepare_native(self):
        if self.native_ready:
            return
        if not self._native_subscribed:
            for char in self._listen:
                await self.client.start_notify(char, self._native_notify)
            self._native_subscribed = True
        if self.protocol == FC82:
            await self._write_native(FC82_GREETING)
            self.native_ready = True
            return
        self._greeting = asyncio.get_running_loop().create_future()
        try:
            async with asyncio.timeout(5):
                await self._write_native(GREETING)
                await self._greeting
            self.native_ready = True
        finally:
            self._greeting = None

    async def set_native_ratio(self, ratio):
        if self.protocol == FC82:
            if self.written_ratio == ratio:
                return
            packet = encode_fc82_ratio(ratio, self._sequence)
            await self._write_native(packet)
            self._sequence = (self._sequence + 1) & 0xffffffff
            self.written_ratio = ratio
            return
        packet = encode_ratio(ratio)
        if ratio_matches(self.confirmed_ratio, ratio):
            return
        future = asyncio.get_running_loop().create_future()
        self._ratio_waiter = ratio, future
        try:
            async with asyncio.timeout(5):
                await self._write_native(packet)
                await future
            self.written_ratio = ratio
        finally:
            self._ratio_waiter = None

    def road_command(self, grade, crr, cw):
        """Packet and writer: hub uses native 0x04, FC82 uses FTMS 0x11 (indicated)."""
        if self.protocol == FC82:
            return encode_simulation(grade, crr, cw), self.command
        return encode_road(grade, crr, cw), self._write_native

    async def release(self):
        try:
            # FTMS Reset is also the existing disconnect/watchdog cleanup.
            await super().release()
        finally:
            self.native_ready = False
            self.confirmed_ratio = None
            self.written_ratio = None


class NativeRoad(RoadSimulation):
    def reset(self):
        super().reset()
        self.ratio = None
        self.ratio_written = None
        self.protocol = None

    def target(self, grade, gear):
        return grade, self.crr, self.cw

    def confirmed(self):
        # FC82 grade travels as FTMS 0x11 with a Control Point indication.
        if self.protocol == FC82 and self.last_packet is not None:
            return super().confirmed()
        # Zwift hub: ATT write success has no application-level slope acknowledgement.
        return None

    async def tick(self, controller, target_grade, gear, aero_scale=1.0):
        aero_scale = validate_aero_scale(aero_scale)
        await controller.prepare_native()
        ratio = round(NEUTRAL_RATIO * self.factors[gear - 1])
        await controller.set_native_ratio(ratio)
        now = self.clock()
        dt = min(.35, max(0.0, now - self.last_time))
        self.last_time = now
        grade = self.grade + max(-self.rate * dt, min(self.rate * dt, target_grade - self.grade))
        aero = self.aero_scale + max(-2 * dt, min(2 * dt, aero_scale - self.aero_scale))
        packet, write = controller.road_command(grade, self.crr, self.cw * aero)
        if packet != self.last_packet:
            await write(packet)
            self.last_packet = packet
        self.protocol = controller.protocol
        self.grade, self.aero_scale = grade, aero
        self.ratio, self.ratio_written = controller.confirmed_ratio, controller.written_ratio
        self.factor = self.factors[gear - 1]
        return abs(grade - target_grade) < 1e-8 and abs(aero - aero_scale) < 1e-8


def native_mode(ramp_w_per_s=300.0, clock=time.monotonic, protocol='auto'):
    from combined_mode import CombinedMode

    if protocol not in PROTOCOLS:
        raise ValueError(f'native protocol moet een van {PROTOCOLS} zijn')

    class NativeMode(CombinedMode):
        native_shifting = True
        native_protocol = protocol

        def __init__(self):
            super().__init__(ramp_w_per_s, clock)
            self.road = NativeRoad(clock=clock)
            # Native SIM always uses the road path, including console-only rides.
            self.sim_backend = self.desired_sim_backend = 'simulation'

        def status(self, source=None):
            status = super().status(source)
            status.update(shifting_backend='zwift-native-experimental',
                          native_protocol=self.road.protocol,
                          native_ratio_written=self.road.ratio_written,
                          native_ratio_confirmed=self.road.ratio,
                          native_grade_written_pct=self.road.grade if self.road.last_packet else None)
            return status

        def accept(self, command, params=None, source=None):
            result = super().accept(command, params, source)
            if command == 'set_mode' and self.desired_mode == 'SIM':
                self.desired_sim_backend = 'simulation'
                result = self.status(source)
            return result

    return NativeMode()
