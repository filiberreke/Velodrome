"""Persistent BLE discovery shared by independent KICKR and Ride tasks."""
import asyncio
import time

RETRY_SECONDS = 5.0

class Discovery:
    def __init__(self, scan, clock=time.monotonic):
        self.scan = scan
        self.clock = clock
        self.lock = asyncio.Lock()
        self.cached = []
        self.scanned_at = -float('inf')

    async def records(self):
        # Avoid simultaneous OS scans; both consumers may use the same result.
        async with self.lock:
            if self.clock() - self.scanned_at >= 2.0:
                try:
                    self.cached = await self.scan()
                except Exception as exc:
                    self.cached = []
                    print('Bluetooth-scan niet beschikbaar:', type(exc).__name__, str(exc), flush=True)
                self.scanned_at = self.clock()
            return self.cached

class DeviceSearch:
    def __init__(self, discovery, select, label, sleep=asyncio.sleep):
        self.discovery, self.select, self.label = discovery, select, label
        self.sleep = sleep
        self.address = None

    async def __call__(self):
        while True:
            records = await self.discovery.records()
            if self.address is None:
                device = self.select(records)
            else:
                # Never silently switch bikes/controllers when another appears.
                device = next((d for d, _ in records if str(d.address).casefold() == self.address), None)
            if device is not None:
                self.address = str(device.address).casefold()
                print(f'{self.label} gevonden: {device.name or "(advertentienaam)"} {device.address}', flush=True)
                return device
            print(f'{self.label} niet gevonden; blijft wachten en zoekt opnieuw over {RETRY_SECONDS:g} seconden.', flush=True)
            await self.sleep(RETRY_SECONDS)
