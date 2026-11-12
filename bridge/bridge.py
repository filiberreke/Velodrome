"""Velodrome 250 v0.15: KICKR FTMS, Zwift Ride, Garmin ANT+ and local UDP commands."""
import argparse
import asyncio
import json
import socket
import time
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
import sys
from bleak import BleakClient, BleakScanner
from ride_protocol import decode_state
from steering import SteeringState
from ride_ble import find_characteristics
from button_mapping import ButtonMapper
from selection import select_device, select_left_ride
from device_search import Discovery, DeviceSearch, RETRY_SECONDS
from hr_bridge import HeartRateState, HeartRateUDPProtocol, HR_PORT
from ant_worker import AntWorker
from platform_support import console_input, bridge_log_path, install_shutdown_handler, check_platform_runtime

from device_registry import DeviceRegistry

BIKE_DATA = "00002ad2-0000-1000-8000-00805f9b34fb"
FTMS_SERVICE = "00001826-0000-1000-8000-00805f9b34fb"
TARGET = ("127.0.0.1", 51723)
FEEDBACK_TIMEOUT_SECONDS = 3.0


from ftms import parse_bike_data
from resistance import ResistanceController
from virtual_shift import VirtualShifter, RAMP_PERIOD
from combined_mode import CombinedMode
from udp_commands import CommandProtocol, HOST as COMMAND_HOST, PORT as COMMAND_PORT


class Sender:
    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.latest = {}
        self.last_power = 0.0
        self.last_speed = 0.0
        self.last_received = 0.0
        self.connected = False
        self.sample_id = 0
        self.power_sample_id = 0  # Distinct measured power, not cadence-only notifications.
        self.heart_rate = HeartRateState()
        self.devices = None
        self.combined_mode = None  # Linked after device selection; no FTMS startup changes.

    def send(self, packet):
        if self.devices and packet.get('type') == 'controller_connection':
            self.devices.connected['controller'] = self.devices.chosen['controller'] if packet.get('connected') else ''
        self.sock.sendto(json.dumps(packet).encode("utf-8"), TARGET)

    async def publish(self):
        while True:
            valid = (self.connected and time.monotonic() - self.last_received < 1.0
                     and "power_w" in self.latest and "speed_kmh" in self.latest)
            self.send({"type": "telemetry", "valid": valid,
                       "power_w": self.latest.get("power_w"),
                       "speed_kmh": self.latest.get("speed_kmh"),
                       "cadence_rpm": self.latest.get("cadence_rpm"),
                       "sample_id": self.sample_id,
                       "power_sample_id": self.power_sample_id,
                       "power_age_s": max(0.0, time.monotonic() - self.last_power) if self.last_power else None,
                       "heart_rate_bpm": self.devices.bpm() if self.devices else self.heart_rate.current_bpm(),
                       "gear": self.combined_mode.selected_gear() if self.combined_mode is not None else None})
            await asyncio.sleep(0.1)


async def discover_devices():
    print("Bluetooth-scannen (8 seconden)...")
    devices = await BleakScanner.discover(timeout=8.0, return_adv=True)
    for _, (dev, adv) in devices.items():
        name = (adv.local_name or dev.name or "(naamloos)")
        print(f"  {name:28s} {dev.address}")
    return list(devices.values())


async def trainer_loop(device, sender, resistance_queue=None, shifter=None, trainer_ready_event=None, combined=None, device_search=None):
    while True:
        try:
            if device_search is not None:
                device = await device_search()
            print("KICKR verbinden:", device.name, device.address)
            async with BleakClient(device, timeout=18.0) as client:
                if not any(s.uuid.lower() == FTMS_SERVICE for s in client.services):
                    raise RuntimeError("FTMS 1826 ontbreekt op geselecteerd apparaat")
                sender.connected = True
                if sender.devices: sender.devices.connected['trainer'] = str(device.address)
                connected_at = time.monotonic()
                sender.latest.clear()
                sender.last_received = sender.last_power = 0.0
                def notification(_char, data):
                    try:
                        values = parse_bike_data(data)
                        sender.latest.update(values)
                        sender.last_received = time.monotonic()
                        if 'power_w' in values:
                            sender.last_power = sender.last_received
                            sender.power_sample_id += 1
                        sender.sample_id += 1
                    except ValueError as exc:
                        print("FTMS decode:", exc)
                await client.start_notify(BIKE_DATA, notification)
                print("KICKR verbonden. FTMS data actief.")
                if trainer_ready_event is not None and shifter is None:
                    trainer_ready_event.set()
                controller = None
                try:
                    if resistance_queue is not None or shifter is not None or (combined is not None and not combined.disabled):
                        controller = ResistanceController(client)
                        print("FTMS: controle aanvragen...")
                        try:
                            await asyncio.wait_for(controller.initialize(), timeout=15.0)
                        except Exception as exc:
                            print("FTMS initialisatie mislukt:", type(exc).__name__, str(exc))
                            raise
                        print("FTMS CONTROL ACTIEF. Test voorzichtig en houd het toetsenbord bij de hand.")
                        if trainer_ready_event is not None:
                            trainer_ready_event.set()
                        if combined is not None:
                            await combined.check_supported(client)
                            if combined.reconnect_ready:
                                print('KICKR hersteld; oude doelen gewist. Wacht op verse data en een nieuwe wedstrijd/opdracht.')
                            else:
                                print('SIM/ERG CONTROL ACTIEF; start in SIM met versnelling 4.')
                        elif shifter is None:
                            print("Commando's: 1, 2, 3 ... 15 (weerstandsniveau), reset, stop")
                        else:
                            print('12 versnellingen actief: links lichter, rechts zwaarder; typ stop + ENTER om regeling te stoppen.')
                    while client.is_connected:
                        # Some adapters leave a stale link open after data stops.
                        now = time.monotonic()
                        if (now - max(connected_at, sender.last_received) > FEEDBACK_TIMEOUT_SECONDS
                                or now - max(connected_at, sender.last_power) > FEEDBACK_TIMEOUT_SECONDS):
                            if combined is not None:
                                combined.suspend('trainer_data_timeout')
                            raise ConnectionError('KICKR-data/power ontbreekt; opnieuw verbinden')
                        if controller is not None:
                            if combined is not None:
                                try:
                                    await combined.tick(controller, sender)
                                except Exception as exc:
                                    # A failed FTMS transaction faults this controller. Reconnect
                                    # instead of leaving the control loop permanently disabled.
                                    combined.suspend('ftms_error: ' + str(exc))
                                    print('SIM/ERG tijdelijk onderbroken na FTMS-fout:', type(exc).__name__, str(exc))
                                    try:
                                        await controller.release()
                                        combined.release_confirmed = True
                                        combined.mode, combined.sent_w = 'RELEASED', None
                                    except Exception as reset_exc:
                                        combined.release_confirmed = False
                                        print('FTMS reset niet bevestigd:', reset_exc)
                                    controller = None
                                    raise ConnectionError('FTMS-control opnieuw verbinden') from exc
                                await asyncio.sleep(0.1)
                                continue
                            if shifter is not None:
                                # Commands from console take priority over any ramping.
                                try:
                                    choice = resistance_queue.get_nowait()
                                except asyncio.QueueEmpty:
                                    choice = None
                                if choice == 'stop':
                                    shifter.enabled = False
                                    await controller.release()
                                    controller = None
                                    print('Virtueel schakelen gestopt; FTMS control gereset.')
                                else:
                                    try:
                                        await shifter.tick(controller)
                                    except Exception as exc:
                                        shifter.enabled = False
                                        try:
                                            await controller.release()
                                        except Exception:
                                            pass
                                        controller = None
                                        print('SCHAKELREGELING UIT bij FTMS-fout:', exc)
                                    await asyncio.sleep(RAMP_PERIOD)
                                continue
                            try:
                                level = await asyncio.wait_for(resistance_queue.get(), timeout=0.4)
                            except asyncio.TimeoutError:
                                continue
                            if level == 'stop':
                                await controller.release()
                                controller = None
                                print('FTMS controle vrijgegeven; bridge leest verder alleen.')
                            elif level == 'reset':
                                await controller.release()
                                print('Trainer reset; einde weerstandstest.')
                                controller = None
                            else:
                                try:
                                    await controller.set_level(float(level))
                                    print('KICKR bevestigt weerstandniveau:', level)
                                except Exception as exc:
                                    print('Weerstandsopdracht mislukt:', exc)
                        else:
                            await asyncio.sleep(0.5)
                finally:
                    if controller is not None:
                        try:
                            await controller.release()
                        except Exception as exc:
                            print('FTMS reset niet bevestigd:', exc)
        except Exception as exc:
            print("KICKR verbindingsfout:", type(exc).__name__, str(exc))
        sender.connected = False
        if sender.devices: sender.devices.connected['trainer'] = ''
        sender.latest.clear()
        if combined is not None:
            combined.connection_lost()
            print('KICKR weggevallen; doelen gewist, bridge blijft zoeken. Na herstel kan een nieuwe wedstrijd sturen.')
        if shifter is not None:
            shifter.enabled = False  # Never resume commanding after disconnect without restart.
            print('Virtueel schakelen uit na verbindingsverlies. Herstart de bridge bewust.')
            if trainer_ready_event is not None:
                trainer_ready_event.clear()
        print("KICKR opnieuw proberen over 5 seconden...")
        await asyncio.sleep(RETRY_SECONDS)


async def ride_loop(device, sender, mapper, shifter=None, combined=None, device_search=None):
    previous = set()
    while True:
        try:
            if device_search is not None:
                device = await device_search()
                # Preserve the proven independent Ride startup spacing.
                await asyncio.sleep(1.5)
            print("Zwift Ride verbinden:", device.name or "(naam via advertentie)", device.address)
            async with BleakClient(device, timeout=18.0) as client:
                print("Ride BLE link verbonden; zoeken naar Zwift service...")
                steering = SteeringState()
                notify_char, write_char, indicate_char, chars = find_characteristics(client)
                print("Ride characteristics:", chars)
                diagnostics = {"received": 0, "decoded": 0}
                counts = {}
                def notification(characteristic, packet):
                    nonlocal previous
                    uuid = str(characteristic.uuid).lower()
                    counts[uuid] = counts.get(uuid, 0) + 1
                    diagnostics["received"] += 1
                    raw = bytes(packet)
                    if counts[uuid] <= 12:
                        print(f"RIDE RAW channel={uuid} len={len(raw)} hex={raw.hex()}")
                    try:
                        state = decode_state(raw)
                    except (ValueError, IndexError) as exc:
                        if counts[uuid] <= 12:
                            print("Ride decode fout:", str(exc))
                        return
                    if state is None:
                        return
                    axis = steering.update(state['paddles'])
                    if axis is not None:
                        sender.send(axis)
                        if abs(axis['value'] - diagnostics.get('steering_value', 0)) >= 10 or (axis['value'] == 0 and diagnostics.get('steering_value', 0) != 0):
                            print(f"Ride analoog: links={steering.paddles[0]} rechts={steering.paddles[1]} -> sturen={axis['value']}")
                            diagnostics['steering_value'] = axis['value']
                    pressed = state['buttons']
                    if pressed is None:
                        return
                    diagnostics["decoded"] += 1
                    if diagnostics["decoded"] <= 12:
                        print("Ride knopstatus:", sorted(pressed))
                    for button in sorted(pressed - previous):
                        sender.send({'type': 'controller_button', 'source_button': button,
                                     'mapped_action': mapper.map_button(button), 'pressed': True})
                        if combined is not None:
                            combined.on_button(button)
                        elif shifter is not None:
                            shifter.on_button(button)
                        packet = mapper.packet(button)
                        if packet:
                            sender.send(packet)
                            print(f"Ride knop: {button} -> {packet['button']}")
                        else:
                            print(f"Ride knop: {button} -> (geen actie)")
                    for button in sorted(previous - pressed):
                        sender.send({'type': 'controller_button', 'source_button': button,
                                     'mapped_action': mapper.map_button(button), 'pressed': False})
                    previous = pressed
                # Reuse the exact known-working subscription sequence from the
                # read-only bridge. Do not subscribe to characteristic 00000006.
                await client.start_notify(notify_char, notification)
                print("Ride knopkanaal actief:", notify_char.uuid)
                if indicate_char and indicate_char.uuid != notify_char.uuid:
                    await client.start_notify(indicate_char, lambda _char, pkt: print("Ride handshake:", bytes(pkt).hex()))
                    print("Ride handshakekanaal actief:", indicate_char.uuid)
                await client.write_gatt_char(write_char, b"RideOn", response=("write" in write_char.properties))
                print("Ride handshake verstuurd")
                sender.send({'type': 'controller_connection', 'connected': True})
                print("Zwift Ride verbonden; probeer de schakelhendels.")
                last_report = time.monotonic()
                while client.is_connected:
                    await asyncio.sleep(0.5)
                    # A lost release/disconnect UDP packet must not leave look-back held.
                    sender.send({'type': 'controller_connection', 'connected': True,
                                 'buttons': sorted(previous)})
                    if time.monotonic() - last_report > 8.0:
                        print(f"Ride BLE diagnose: {diagnostics['received']} meldingen, {diagnostics['decoded']} knopstatussen; per kanaal={counts}")
                        last_report = time.monotonic()
        except Exception as exc:
            print("Zwift Ride verbindingsfout:", type(exc).__name__, str(exc))
        for button in sorted(previous):
            sender.send({'type': 'controller_button', 'source_button': button,
                         'mapped_action': mapper.map_button(button), 'pressed': False})
        sender.send({'type': 'steering', 'value': 0})
        sender.send({'type': 'controller_connection', 'connected': False})
        previous = set()
        await asyncio.sleep(RETRY_SECONDS)


async def shift_input(queue, shifter):
    print("Druk op X om virtueel schakelen te stoppen (geen Enter nodig).")
    try:
        import msvcrt
    except ImportError:
        # Linux fallback, only a console helper; BLE remains in event loop.
        while shifter.enabled:
            value = (await console_input("Typ stop + ENTER > ")).strip().lower()
            if value == 'stop':
                shifter.enabled = False
                await queue.put('stop')
                return
        return
    while shifter.enabled:
        if msvcrt.kbhit():
            ch = msvcrt.getwch().lower()
            if ch == 'x':
                shifter.enabled = False
                await queue.put('stop')
                print("Stop gevraagd: FTMS reset wordt verzonden.")
                return
        await asyncio.sleep(0.15)

async def resistance_input(queue):
    print('VEILIGHEID: stop met trappen bij onverwachte weerstand en typ reset of sluit bridge.')
    while True:
        value = (await console_input('Weerstand 1..15, reset of stop > ')).strip().lower()
        if value in ('reset', 'stop'):
            await queue.put(value)
            if value == 'stop':
                return
        else:
            try:
                level = float(value)
                if 1 <= level <= 15:
                    await queue.put(level)
                else:
                    print('Alleen 1..15 toegestaan')
            except ValueError:
                print('Gebruik 1..15, reset of stop')

async def combined_console(combined):
    print('SIM/ERG commando\'s: sim | grade -20..20 [pct/s] | erg | target 0..1300 [W/s] | status | stop')
    print('Start in SIM. ERG wordt pas actief na expliciet: erg')
    while not combined.disabled:
        try:
            line = (await console_input('SIM/ERG > ')).strip().lower()
        except (EOFError, KeyboardInterrupt):
            combined.request_stop()
            return
        try:
            feedback = combined.handle_command(line)
            print(feedback)
        except ValueError as exc:
            print('ONGELDIG:', exc)
        if combined.disabled:
            return


async def main(args):
    install_shutdown_handler()
    if getattr(args, 'software_test', False):
        print('SOFTWARETEST: geen Bluetooth, ANT+ of trainersturing gestart.', flush=True)
        try:
            await asyncio.Future()
        finally:
            print('SOFTWARETEST: bridge netjes afgesloten.', flush=True)
        return
    if args.list:
        await discover_devices()
        return

    sender = Sender()
    ant_worker = None
    hr_transport = None
    command_transport = None
    try:
        if not args.no_ant:
            # First bind the local HR receiver, then launch ANT+ in a thread.
            # Never let blocking USB reads delay Bluetooth's asyncio event loop.
            loop = asyncio.get_running_loop()
            try:
                hr_transport, _ = await loop.create_datagram_endpoint(
                    lambda: HeartRateUDPProtocol(sender.heart_rate),
                    local_addr=('127.0.0.1', HR_PORT))
            except OSError as exc:
                print(f'ANT+ UDP-poort {HR_PORT} bezet: {exc}')
                print('Sluit de oude ANT+-test/bridge. Start v0.15 opnieuw. Geen FTMS-sturing gestart.')
                return
            print(f'ANT+ lokale ontvangst actief: 127.0.0.1:{HR_PORT}')
            ant_worker = AntWorker()
            ant_worker.start()
        else:
            print('ANT+ overgeslagen (--no-ant). BLE-hartslag kan via Apparaten worden gekozen.')

        discovery = Discovery(discover_devices)
        settings_dir = Path(sys.executable).parent if getattr(sys, 'frozen', False) else Path(__file__).parent
        devices = DeviceRegistry(discovery, sender.heart_rate, settings_dir / 'device_selections.json')
        sender.devices = devices

        combined = CombinedMode(args.erg_ramp_w_per_s)
        sender.combined_mode = combined
        try:
            command_transport, _ = await asyncio.get_running_loop().create_datagram_endpoint(
                lambda: CommandProtocol(combined, devices=devices), local_addr=(COMMAND_HOST, COMMAND_PORT))
        except OSError as exc:
            print(f'UDP-commandopoort {COMMAND_PORT} niet beschikbaar: {exc}. Geen FTMS-sturing gestart.')
            return
        print(f'UDP-commandos: {COMMAND_HOST}:{COMMAND_PORT}; ERG/helling lease 5 s, ACK is acceptatie, geen hardwarebewijs.')
        mapper = ButtonMapper.load()
        print('Ride knoppenmapping:', mapper.mapping)
        print('Bridge wacht op apparaten; KICKR en linker Ride verbinden onafhankelijk zodra ze beschikbaar zijn.')
        def trainer_task():
            search = DeviceSearch(discovery, lambda rows: devices.choose('trainer', rows,
                                  lambda found: select_device(found, args.trainer)), 'Trainer')
            return trainer_loop(None, sender, combined=combined, device_search=search)

        def controller_task():
            search = DeviceSearch(discovery, lambda rows: devices.choose('controller', rows,
                                  lambda found: select_left_ride(found, args.ride)), 'Besturing')
            return ride_loop(None, sender, mapper, combined=combined, device_search=search)

        def clear_trainer():
            sender.connected = False
            sender.latest.clear()
            combined.connection_lost()

        def clear_controller():
            sender.send({'type': 'steering', 'value': 0})
            sender.send({'type': 'controller_connection', 'connected': False})

        def clear_hr():
            devices.ble_hr = HeartRateState()

        tasks = [devices.scan_loop(),
                 devices.supervise('trainer', trainer_task, clear_trainer),
                 devices.supervise('controller', controller_task, clear_controller),
                 devices.supervise('heart_rate', lambda: devices.hr_loop(BleakClient), clear_hr),
                 sender.publish(), combined_console(combined)]
        await asyncio.gather(*tasks)
    finally:
        if command_transport is not None:
            command_transport.close()
        if ant_worker is not None:
            ant_worker.stop()
        if hr_transport is not None:
            hr_transport.close()
        sender.sock.close()


if __name__ == '__main__':
    p = argparse.ArgumentParser(description='Velodrome 250 v0.15: lokale UDP SIM/ERG + ANT+ hartslag')
    p.add_argument('--list', action='store_true', help='Alleen BLE-apparaten tonen (start ANT+ niet)')
    p.add_argument('--check-config', action='store_true', help='Controleer alle configuratiebestanden en sluit af zonder apparaten te starten')
    p.add_argument('--check-runtime', action='store_true', help='Controleer macOS bindings en libusb zonder apparaten te starten')
    p.add_argument('--software-test', action='store_true', help=argparse.SUPPRESS)
    p.add_argument('--no-ant', action='store_true', help='Start alleen KICKR en Zwift Ride, zonder ANT+ dongle')
    p.add_argument('--trainer', default='KICKR', help='Deel van trainernaam')
    p.add_argument('--ride', default='', help='Optioneel BLE-adres of macOS UUID van de LINKER Ride; standaard auto-detectie')
    p.add_argument('--erg-ramp-w-per-s', type=float, default=300.0, help='ERG overgangssnelheid 1..10000 W/s, standaard 300')
    args = p.parse_args()
    from combined_mode import validate_rate
    try:
        validate_rate(args.erg_ramp_w_per_s)
    except ValueError as exc:
        p.error(str(exc))
    if args.check_runtime:
        check_platform_runtime()
    if args.check_config or args.check_runtime:
        # Use the same loaders and module-relative paths as normal startup.
        CombinedMode(args.erg_ramp_w_per_s)
        ButtonMapper.load()
        print('Bridge configuration OK: gear_config.json, simulation_config.json, button_mapping.json')
        p.exit()
    handler = RotatingFileHandler(bridge_log_path(), maxBytes=1000000, backupCount=2, encoding='utf-8')
    logging.basicConfig(level=logging.INFO, handlers=[handler, logging.StreamHandler()],
                        format='%(asctime)s %(levelname)s %(name)s %(message)s')
    try:
        asyncio.run(main(args))
    except (KeyboardInterrupt, asyncio.CancelledError):
        print('Bridge afgesloten.')

