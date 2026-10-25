"""ANT+ Heart Rate (device type 120) -> UDP op 127.0.0.1:51724.

Gebaseerd op het publieke openant raw_device_data.py ANT+ HR-profielvoorbeeld.
Alleen lezen; geen trainerweerstand, geen BLE.
"""
import argparse
import json
import socket
import sys
import time

HOST = '127.0.0.1'
PORT = 51724
NETWORK_KEY = [0xB9, 0xA5, 0x21, 0xFB, 0xBD, 0x72, 0xC3, 0x45]


def decode_heart_rate(data):
    """ANT+ HRM payload: huidige hartslag is byte 7 van 8 databytes."""
    raw = bytes(data)
    if len(raw) < 8:
        return None
    bpm = raw[7]
    return bpm if 25 <= bpm <= 240 else None


class HeartRatePublisher:
    def __init__(self, sock=None, target=(HOST, PORT), clock=time.monotonic):
        self.sock = sock or socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.target = target
        self.clock = clock
        self.packets = 0
        self._last_printed = None
        self._last_print_time = 0.0

    def handle_data(self, data):
        bpm = decode_heart_rate(data)
        if bpm is None:
            return False
        self.packets += 1
        message = {'type': 'heart_rate', 'heart_rate_bpm': bpm}
        self.sock.sendto(json.dumps(message, separators=(',', ':')).encode('utf-8'), self.target)
        now = self.clock()
        if bpm != self._last_printed or now - self._last_print_time >= 5.0:
            print(f'Garmin ANT+ hartslag: {bpm} bpm (pakket {self.packets}; UDP 51724)', flush=True)
            self._last_printed = bpm
            self._last_print_time = now
        return True

    def close(self):
        self.sock.close()


def run_ant(device_id=0, backend='legacy', on_node_ready=None):
    if backend != 'legacy':
        raise ValueError('v0.13 ondersteunt uitsluitend de geteste Dynastream/libusb0-backend')
    restore_backend = None
    if sys.platform == 'win32':
        from ant_legacy_backend import activate_legacy_backend, report_legacy_adapter
        restore_backend = activate_legacy_backend()
        try:
            report_legacy_adapter()
        except Exception:
            restore_backend()
            raise
    try:
        from openant.easy.node import Node
        from openant.easy.channel import Channel
    except ImportError as exc:
        raise RuntimeError('openant ontbreekt; gebruik start_ant_hr_test_windows.bat') from exc

    pub = HeartRatePublisher()
    node = None
    print('ANT+ luisteren naar hartslagprofiel (device type 120).')
    print('Zet op de Garmin Broadcast Heart Rate aan. Ctrl+C = stoppen.')
    if device_id == 0:
        print('Sensor-ID automatisch: eerste gevonden ANT+ hartslagzender.')
    else:
        print('Gevraagde sensor-ID:', device_id)
    try:
        node = Node()
        node.set_network_key(0x00, NETWORK_KEY)
        channel = node.new_channel(Channel.Type.BIDIRECTIONAL_RECEIVE)
        channel.on_broadcast_data = pub.handle_data
        channel.on_burst_data = pub.handle_data
        channel.set_period(8070)
        channel.set_search_timeout(12)
        channel.set_rf_freq(57)
        channel.set_id(device_id, 120, 0)
        channel.open()
        if on_node_ready is not None:
            on_node_ready(node)
        node.start()  # Blokkerend; stop() vanuit hoofdthread beëindigt ontvangst.
    finally:
        if node is not None:
            try:
                node.stop()
            except Exception as exc:
                print('ANT+ afsluitmelding:', exc)
        pub.close()
        if restore_backend is not None:
            restore_backend()


def run_demo():
    """Test alleen UDP/koppeling, GEEN echte hartslag."""
    print('DEMO: synthetische hartslag. Dit is GEEN Garmin-meting. Ctrl+C = stoppen.')
    pub = HeartRatePublisher()
    try:
        bpm_series = (80, 81, 83, 85, 83, 81)
        i = 0
        while True:
            bpm = bpm_series[i % len(bpm_series)]
            pub.handle_data(bytes([0, 0, 0, 0, 0, 0, 0, bpm]))
            i += 1
            time.sleep(1.0)
    finally:
        pub.close()


def main():
    p = argparse.ArgumentParser(description='Velodrome 250: ANT+ hartslag naar lokale UDP bridge')
    p.add_argument('--device-id', type=int, default=0, help='Optioneel ANT+ sensornummer (0 = eerste hartslagsensor)')
    p.add_argument('--demo', action='store_true', help='STUUR SYNTHETISCHE hartslag via UDP voor softwaretest')
    p.add_argument('--backend', choices=['legacy'], default='legacy', help='Oorspronkelijke Dynastream-driver via libusb0')
    args = p.parse_args()
    if not 0 <= args.device_id <= 65535:
        p.error('--device-id moet 0..65535 zijn')
    try:
        if args.demo:
            run_demo()
        else:
            run_ant(args.device_id, args.backend)
    except KeyboardInterrupt:
        print('ANT+ hartslagtest gestopt.')
    except Exception as exc:
        print('ANT+ FOUT:', type(exc).__name__, str(exc), file=sys.stderr)
        print('Zie README.md. De originele Dynastream-driver blijft ongewijzigd.', file=sys.stderr)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
