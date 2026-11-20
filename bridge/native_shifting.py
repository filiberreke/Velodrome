"""Experimental Zwift trainer service, selected explicitly with --native-shifting.

Wire facts are documented in NATIVE_SHIFTING.md. The existing 12-gear ladder is
retained, but ratios are now sent to the trainer independently of road grade.
"""
import asyncio
import logging
import time

from resistance import ResistanceController
from ride_protocol import fields
from simulation import RoadSimulation, validate_aero_scale

log = logging.getLogger(__name__)
SERVICE = '00000001-19ca-4651-86e5-fa29dcdd09d1'
WRITE = '00000003-19ca-4651-86e5-fa29dcdd09d1'
NOTIFY = '00000002-19ca-4651-86e5-fa29dcdd09d1'
INDICATE = '00000004-19ca-4651-86e5-fa29dcdd09d1'
GREETING = b'RideOn\x02'
NEUTRAL_RATIO = 24000


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


def encode_road(grade, crr, cw):
    """Opcode 4, simulation field 4. Signed incline uses protobuf zigzag."""
    incline = round(grade * 100)
    if not -2000 <= incline <= 2000 or not 0 <= crr <= .0255 or not 0 <= cw <= 2.55:
        raise ValueError('Native simulation outside supported road domain')
    zigzag = (incline << 1) ^ (incline >> 31)
    payload = integer(1, 0) + integer(2, zigzag)
    payload += integer(3, round(cw * 10000)) + integer(4, round(crr * 100000))
    return b'\x04' + message(4, payload)


def encode_ratio(ratio):
    if type(ratio) is not int or not 7500 <= ratio <= 54899:
        raise ValueError('Native ratio outside tested protocol range')
    return b'\x04' + message(5, integer(2, ratio))


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
    return ratio if type(ratio) is int and 7500 <= ratio <= 54899 else None


class NativeController(ResistanceController):
    """All writes run through CombinedMode's existing single writer."""
    def __init__(self, client):
        super().__init__(client)
        self.native_ready = False
        self.confirmed_ratio = None
        self._greeting = None
        self._ratio_waiter = None
        self._native_subscribed = False

    async def initialize(self):
        if self.client.services.get_service(SERVICE) is None:
            raise RuntimeError('Zwift trainer service 00000001 ontbreekt; gebruik de backupbridge. '
                               'De oudere FC82-service wordt nog niet ondersteund.')
        for uuid in (WRITE, INDICATE):
            if self.client.services.get_characteristic(uuid) is None:
                raise RuntimeError('Zwift trainer service mist write/indicate characteristic')
        await super().initialize()

    def _native_notify(self, _char, data):
        data = bytes(data)
        if data == GREETING + b'\x00' and self._greeting is not None:
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
                if ratio == expected and not future.done():
                    future.set_result(True)

    async def _write_native(self, packet):
        if not self.active or self.faulted:
            raise RuntimeError('Native trainercontrol niet actief')
        await self.client.write_gatt_char(WRITE, packet, response=True)

    async def prepare_native(self):
        if self.native_ready:
            return
        if not self._native_subscribed:
            await self.client.start_notify(INDICATE, self._native_notify)
            if self.client.services.get_characteristic(NOTIFY) is not None:
                await self.client.start_notify(NOTIFY, self._native_notify)
            self._native_subscribed = True
        self._greeting = asyncio.get_running_loop().create_future()
        try:
            async with asyncio.timeout(5):
                await self._write_native(GREETING)
                await self._greeting
            self.native_ready = True
        finally:
            self._greeting = None

    async def set_native_ratio(self, ratio):
        packet = encode_ratio(ratio)
        if self.confirmed_ratio == ratio:
            return
        future = asyncio.get_running_loop().create_future()
        self._ratio_waiter = ratio, future
        try:
            async with asyncio.timeout(5):
                await self._write_native(packet)
                await future
        finally:
            self._ratio_waiter = None

    async def release(self):
        try:
            # FTMS Reset is also the existing disconnect/watchdog cleanup.
            await super().release()
        finally:
            self.native_ready = False
            self.confirmed_ratio = None


class NativeRoad(RoadSimulation):
    def reset(self):
        super().reset()
        self.ratio = None

    def target(self, grade, gear):
        return grade, self.crr, self.cw

    def confirmed(self):
        # ATT write success has no application-level slope acknowledgement.
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
        packet = encode_road(grade, self.crr, self.cw * aero)
        if packet != self.last_packet:
            await controller._write_native(packet)
            self.last_packet = packet
        self.grade, self.aero_scale, self.ratio = grade, aero, controller.confirmed_ratio
        self.factor = self.factors[gear - 1]
        return abs(grade - target_grade) < 1e-8 and abs(aero - aero_scale) < 1e-8


def native_mode(ramp_w_per_s=300.0, clock=time.monotonic):
    from combined_mode import CombinedMode

    class NativeMode(CombinedMode):
        native_shifting = True

        def __init__(self):
            super().__init__(ramp_w_per_s, clock)
            self.road = NativeRoad(clock=clock)
            # Native SIM always uses the road path, including console-only rides.
            self.sim_backend = self.desired_sim_backend = 'simulation'

        def status(self, source=None):
            status = super().status(source)
            status.update(shifting_backend='zwift-native-experimental',
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
