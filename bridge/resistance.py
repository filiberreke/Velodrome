"""Opt-in FTMS Control Point resistance handling. Does not auto-enable on import."""
import asyncio
import struct
import logging

log = logging.getLogger(__name__)

CONTROL_POINT = '00002ad9-0000-1000-8000-00805f9b34fb'
FEATURE = '00002acc-0000-1000-8000-00805f9b34fb'
SUPPORTED_RESISTANCE = 1 << 2  # Target setting features, resistance target setting bit.

class ResistanceController:
    def __init__(self, client):
        self.client = client
        self._pending = None
        self._lock = asyncio.Lock()
        self.active = False
        self.supported = False
        self._subscribed = False
        self.faulted = False

    async def initialize(self):
        raw = bytes(await self.client.read_gatt_char(FEATURE))
        if len(raw) < 8:
            raise RuntimeError('FTMS Feature characteristic onvolledig')
        target_features = int.from_bytes(raw[4:8], 'little')
        self.supported = bool(target_features & SUPPORTED_RESISTANCE)
        if not self.supported:
            raise RuntimeError('KICKR meldt geen ondersteuning voor FTMS Target Resistance Level')
        if self.faulted:
            raise RuntimeError('FTMS-kanaal na fout geblokkeerd; herstart nodig')
        if not self._subscribed:
            await self.client.start_notify(CONTROL_POINT, self._notify)
            self._subscribed = True
        await self.command(b'\x00')  # Request Control
        self.active = True

    def _notify(self, _char, data):
        b = bytes(data)
        if len(b) >= 3 and b[0] == 0x80 and self._pending is not None:
            requested_opcode, fut = self._pending
            if b[1] == requested_opcode and not fut.done():
                fut.set_result(b[2])

    async def command(self, data):
        async with self._lock:
            if self.faulted and data != b'\x01':
                raise RuntimeError('FTMS-kanaal na fout geblokkeerd')
            loop = asyncio.get_running_loop()
            fut = loop.create_future()
            self._pending = (data[0], fut)
            try:
                log.info('FTMS write opcode=0x%02x payload=%s', data[0], data.hex())
                async with asyncio.timeout(5.0):
                    await self.client.write_gatt_char(CONTROL_POINT, data, response=True)
                    result = await fut
                if result != 1:
                    raise RuntimeError(f'FTMS Control Point weigert opcode 0x{data[0]:02x}: resultaat {result}')
                log.info('FTMS indication opcode=0x%02x result=%s', data[0], result)
            except BaseException:
                # A late indication must never satisfy another request using
                # the same opcode after a timeout. Only one cleanup Reset is allowed.
                self.faulted = True
                log.warning('FTMS transaction mislukt opcode=0x%02x; kanaal geblokkeerd', data[0], exc_info=True)
                raise
            finally:
                self._pending = None

    async def set_level(self, level):
        if not self.active:
            raise RuntimeError('FTMS control nog niet actief')
        if not 1.0 <= level <= 15.0:
            raise ValueError('Testbereik is 1.0 tot 15.0 (geen automatische aansturing)')
        # FTMS opcode 0x04: signed sint16, units 0.1 resistance level
        await self.command(b'\x04' + struct.pack('<h', round(level * 10)))

    async def release(self):
        if not self.active:
            return
        try:
            # Reset returns the trainer to its default mode, not an emergency brake.
            await self.command(b'\x01')
        finally:
            self.active = False
