"""Start ANT+ in dezelfde Python-bridge, onafhankelijk van de BLE-eventloop.

ANT gebruikt Windows libusb0 of macOS libusb 1.0 en publiceert lokaal
naar UDP 51724, waar hr_bridge het in de Godot-telemetrie opneemt. De enige
bedoeling van de thread is USB-blocking IO uit de asyncio BLE-loop houden.
"""
import threading
from ant_hr import run_ant


class AntWorker:
    def __init__(self, run=run_ant):
        self._run_ant = run
        self._stop_requested = threading.Event()
        self._lock = threading.Lock()
        self._node = None
        self._thread = None
        self.error = None

    def _ready(self, node):
        with self._lock:
            self._node = node
            stopping = self._stop_requested.is_set()
        if stopping:
            # Startup raced with shutdown; do not run the reader after stop.
            node.stop()
            raise RuntimeError('ANT+ gestart tijdens afsluiten')

    def _worker(self):
        try:
            self._run_ant(on_node_ready=self._ready)
        except Exception as exc:
            if not self._stop_requested.is_set():
                self.error = exc
                print('ANT+ NIET BESCHIKBAAR:', type(exc).__name__, str(exc), flush=True)
                print('SIM/ERG blijft werken; hartslag blijft -- totdat ANT+ weer draait.', flush=True)
        finally:
            with self._lock:
                self._node = None

    def start(self):
        if self._thread is not None:
            raise RuntimeError('ANT+-ontvanger is al gestart')
        self._thread = threading.Thread(target=self._worker, name='ANT+ hartslag', daemon=True)
        self._thread.start()
        print('ANT+ hartslagontvanger automatisch gestart (platform-eigen USB-backend).', flush=True)

    def stop(self):
        self._stop_requested.set()
        with self._lock:
            node = self._node
        if node is not None:
            try:
                node.stop()
            except Exception as exc:
                print('ANT+ stopmelding:', type(exc).__name__, str(exc), flush=True)
        if self._thread is not None:
            self._thread.join(timeout=3.0)
            if self._thread.is_alive():
                print('ANT+ leesthread sluit traag af; beëindig programma volledig voordat je de stick hergebruikt.', flush=True)
