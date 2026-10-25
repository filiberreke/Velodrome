"""ANT+ hartslag-UDP bij de bestaande KICKR-telemetrie voegen.

Deze module raakt BLE of FTMS niet aan. Alle UDP is localhost-only.
"""
import asyncio
import json
import time

HR_PORT = 51724
HR_STALE_AFTER = 5.0

class HeartRateState:
    def __init__(self, clock=time.monotonic):
        self._clock = clock
        self._last_bpm = None
        self._last_received = None
        self._last_reported = None

    def update(self, bpm):
        # bool is an int in Python; reject it explicitly.
        if type(bpm) is not int or not (25 <= bpm <= 240):
            return False
        self._last_bpm = bpm
        self._last_received = self._clock()
        return True

    def current_bpm(self):
        if self._last_received is None:
            return None
        if self._clock() - self._last_received > HR_STALE_AFTER:
            return None
        return self._last_bpm

    def receive_json(self, datagram):
        try:
            message = json.loads(datagram.decode('utf-8'))
        except (ValueError, UnicodeError, AttributeError):
            return False
        if not isinstance(message, dict) or message.get('type') != 'heart_rate':
            return False
        return self.update(message.get('heart_rate_bpm'))


class HeartRateUDPProtocol(asyncio.DatagramProtocol):
    def __init__(self, state):
        self.state = state
        self._last_logged = None

    def datagram_received(self, data, addr):
        if addr[0] not in ('127.0.0.1', '::1'):
            return
        if self.state.receive_json(data):
            bpm = self.state.current_bpm()
            if bpm != self._last_logged:
                print('ANT+ hartslag -> Godot-telemetrie:', bpm, 'bpm')
                self._last_logged = bpm


async def heart_rate_listener(state, host='127.0.0.1', port=HR_PORT):
    loop = asyncio.get_running_loop()
    transport, _protocol = await loop.create_datagram_endpoint(
        lambda: HeartRateUDPProtocol(state), local_addr=(host, port))
    print(f'ANT+ hartslag luisterpoort actief: {host}:{port}')
    try:
        await asyncio.Future()
    finally:
        transport.close()
