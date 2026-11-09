"""Exercise the actual UI controller and UDP packets without a display or hardware."""
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import tkinter as tk
import unittest
from unittest.mock import MagicMock, patch

SOURCE = Path(__file__).resolve().parents[1] / 'tools' / 'virtual_bridge_ui.py'
spec = importlib.util.spec_from_file_location('virtual_bridge_ui', SOURCE)
ui = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ui)


class VirtualBridgeTests(unittest.TestCase):
    def setUp(self):
        self.receiver = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.receiver.bind(('127.0.0.1', 0))
        self.receiver.settimeout(1)
        self.interpreter = tk.Tcl()
        self.patches = [patch.object(ui, 'COMMAND_PORT', 0),
                        patch.object(ui, 'TELEMETRY_PORT', self.receiver.getsockname()[1]),
                        patch.object(ui, 'ttk', MagicMock()), patch.object(ui.tk, 'Text', MagicMock())]
        for name in ('DoubleVar', 'BooleanVar', 'StringVar'):
            factory = getattr(tk, name)
            self.patches.append(patch.object(ui.tk, name,
                side_effect=lambda _factory=factory, **kwargs: _factory(master=self.interpreter, **kwargs)))
        for replacement in self.patches:
            replacement.start()
        self.bridge = ui.VirtualBridge(MagicMock())
        self.addCleanup(self.cleanup_bridge)

    def cleanup_bridge(self):
        self.bridge.close()
        self.receiver.close()
        for replacement in reversed(self.patches):
            replacement.stop()

    def receive(self, kind=None):
        while True:
            packet = json.loads(self.receiver.recv(4096))
            if kind is not None:
                if packet['type'] == kind:
                    return packet
            elif packet['type'] not in ('steering', 'controller_button', 'controller_connection'):
                return packet

    def test_analog_slider_transmits_pressure_and_release_independently(self):
        self.receive()
        self.bridge.left_paddle.set(-85)
        self.bridge.loop()
        self.assertEqual(self.receive('steering'), dict(type='steering', value=-85))
        self.receive()
        self.bridge.release_paddles()
        self.bridge.loop()
        self.assertEqual(self.receive('steering')['value'], 0)

    def test_paddles_braking_cancellation_and_individual_release(self):
        self.receive()
        for left, right, expected in [(80, -70, 0), (-85, 85, 0), (-85, 40, -45), (0, 40, 40), (-60, 0, -60)]:
            self.bridge.left_paddle.set(left)
            self.bridge.right_paddle.set(right)
            self.bridge.loop()
            self.assertEqual(self.receive('steering')['value'], expected)
            self.receive()

    def test_startup_transmits_valid_stationary_telemetry_and_schedules_next_frame(self):
        packet = self.receive()
        self.assertEqual(packet, dict(type='telemetry', valid=True, power_w=0,
            speed_kmh=0, cadence_rpm=0, heart_rate_bpm=140, sample_id=1, power_sample_id=1, power_age_s=0.0, gear=4))
        self.bridge.root.after.assert_called_once_with(100, self.bridge.loop)
        self.bridge.loop()
        packet = self.receive()
        self.assertEqual(packet['sample_id'], 2)
        self.assertEqual(packet['power_sample_id'], 2)
        self.assertEqual(packet['power_age_s'], 0.0)

    def test_released_trainer_keeps_fresh_zero_power_measurements(self):
        self.receive()
        self.bridge.mode = 'RELEASED'
        self.bridge.desired_mode = 'ERG'
        self.bridge.released = True
        self.bridge.loop()
        packet = self.receive()
        self.assertTrue(packet['valid'])
        self.assertEqual(packet['power_w'], 0)
        self.assertGreater(packet['power_sample_id'], 1)
        self.assertEqual(packet['power_age_s'], 0.0)
        self.assertIsNone(packet['gear'])
        self.bridge.connected.set(False)
        self.bridge.loop()
        packet = self.receive()
        self.assertFalse(packet['valid'])
        self.assertIsNone(packet['power_age_s'])

    @unittest.skipUnless(os.environ.get('GODOT_BIN'), 'Set GODOT_BIN for actual Godot integration')
    def test_derny_starts_from_released_with_zero_power(self):
        self.bridge.mode = 'RELEASED'
        self.bridge.desired_mode = 'ERG'
        self.bridge.released = True
        self.run_integration('test_derny_virtual_bridge.gd')

    def test_transmit_controls_and_drop_recovery(self):
        self.receive()
        self.bridge.power.set(225)
        self.bridge.speed.set(40)
        self.bridge.cadence.set(90)
        self.bridge.loop()
        self.assertEqual(self.receive()['power_w'], 225)
        self.bridge.packet_drop.set(True)
        self.bridge.loop()
        self.receiver.settimeout(.05)
        with self.assertRaises(socket.timeout): self.receive()
        self.bridge.packet_drop.set(False)
        self.bridge.connected.set(False)
        self.bridge.loop()
        self.assertFalse(self.receive()['valid'])
        self.bridge.connected.set(True)
        self.bridge.loop()
        self.assertTrue(self.receive()['valid'])
        self.bridge.button('RIGHT')
        self.assertEqual(self.receive(), dict(type='button', button='RIGHT', source_button='RIGHT'))

    def test_button_press_release_and_unmapped_keys(self):
        self.receive()
        self.bridge.press_button('B')
        self.assertEqual(self.receive('controller_button'),
                         dict(type='controller_button', source_button='B', mapped_action='B', pressed=True))
        self.assertEqual(self.receive(), dict(type='button', button='B', source_button='B'))
        self.bridge.press_button('B')
        self.bridge.release_button('B')
        self.assertEqual(self.receive('controller_button')['pressed'], False)
        self.assertFalse(self.bridge.held_buttons)
        self.bridge.press_button('Y')
        self.assertEqual(self.receive('controller_button'),
                         dict(type='controller_button', source_button='Y', mapped_action='Y', pressed=True))
        self.assertEqual(self.receive(), dict(type='button', button='Y', source_button='Y'))
        self.bridge.release_button('Y')
        self.assertEqual(self.receive('controller_button')['pressed'], False)

    def test_all_shift_keys_use_side_for_gear_direction(self):
        self.receive()
        for key, expected in [('SHIFT_UP_LEFT', 3), ('SHIFT_DOWN_LEFT', 2),
                              ('SHIFT_UP_RIGHT', 3), ('SHIFT_DOWN_RIGHT', 4)]:
            self.bridge.press_button(key)
            self.bridge.press_button(key)
            self.assertEqual(self.bridge.gear, expected, 'Held key only shifts once')
            self.bridge.release_button(key)
        self.bridge.shift(-1)
        self.assertEqual(self.bridge.gear, 3, 'Helper must shift once')

    def test_pause_and_held_button_heartbeat(self):
        self.receive()
        self.bridge.press_button('Z')
        self.assertEqual(self.receive('controller_button')['mapped_action'], 'Z')
        self.assertEqual(self.receive()['button'], 'Z')
        self.bridge.loop()
        heartbeat = self.receive('controller_connection')
        self.assertEqual(heartbeat['buttons'], ['Z'])

    def test_ride_disconnection_releases_held_buttons(self):
        self.receive()
        self.bridge.press_button('B')
        self.receive('controller_button')
        self.receive()
        self.bridge.ride_connected.set(False)
        self.bridge.loop()
        released = self.receive('controller_button')
        self.assertEqual((released['source_button'], released['pressed']), ('B', False))
        self.assertEqual(self.receive('controller_connection')['connected'], False)
        self.assertFalse(self.bridge.held_buttons)

    def test_closed_godot_socket_does_not_stop_scheduled_loop(self):
        self.receive()
        with patch.object(self.bridge, 'rx') as receiver:
            receiver.recvfrom.side_effect = ConnectionResetError(10054, 'Godot socket closed')
            self.bridge.loop()
        self.assertEqual(self.receive()['sample_id'], 2)
        self.bridge.root.after.assert_called_with(100, self.bridge.loop)
        for error in (ConnectionResetError, ConnectionRefusedError):
            with patch.object(self.bridge, 'tx') as sender:
                sender.sendto.side_effect = error()
                self.bridge.loop()
        self.bridge.loop()
        self.assertEqual(self.receive()['sample_id'], 5)

    @unittest.skipUnless(os.environ.get('GODOT_BIN'), 'Set GODOT_BIN for actual Godot integration')
    def test_godot_configurable_mapping(self):
        self.run_integration('test_ride_mapping_udp.gd', require_commands=False)

    @unittest.skipUnless(os.environ.get('GODOT_BIN'), 'Set GODOT_BIN for actual Godot integration')
    def test_godot_pursuit_settings_and_start_navigation(self):
        self.run_integration('test_ride_pursuit_udp.gd', require_commands=False)

    @unittest.skipUnless(os.environ.get('GODOT_BIN'), 'Set GODOT_BIN for actual Godot integration')
    def test_godot_phase2_from_physical_button_bytes(self):
        from ride_protocol import decode_packet
        wire = {'A': '2308efffffff0f', 'B': '2308dfffffff0f', 'Z': '2308fffeffff0f'}
        original_press = self.bridge.press_button
        original_release = self.bridge.release_button

        def physical_name(name):
            decoded = decode_packet(bytes.fromhex(wire[name]))
            self.assertEqual(decoded, {name})
            return next(iter(decoded))

        with patch.object(self.bridge, 'press_button', side_effect=lambda name: original_press(physical_name(name))), \
             patch.object(self.bridge, 'release_button', side_effect=lambda name: original_release(physical_name(name))):
            self.run_integration('test_ride_phase2_udp.gd')

    @unittest.skipUnless(os.environ.get('GODOT_BIN'), 'Set GODOT_BIN for actual Godot integration')
    def test_godot_phase2_with_phase1_mapping(self):
        mapping = dict(self.bridge.mapping)
        mapping.pop('Z')
        self.bridge.close()
        # Exercise the simulator's actual startup loader with the old file.
        with patch.object(ui.Path, 'read_text', return_value=json.dumps(mapping)):
            self.bridge = ui.VirtualBridge(MagicMock())
        self.assertEqual(self.bridge.mapping['Z'], 'Z')
        self.run_integration('test_ride_phase2_udp.gd')

    @unittest.skipUnless(os.environ.get('GODOT_BIN'), 'Set GODOT_BIN for actual Godot integration')
    def test_godot_phase2_controller_flow(self):
        self.run_integration('test_ride_phase2_udp.gd')

    @unittest.skipUnless(os.environ.get('GODOT_BIN'), 'Set GODOT_BIN for actual Godot integration')
    def test_godot_detection_countdown_and_three_races(self):
        self.run_integration('test_virtual_bridge.gd')

    @unittest.skipUnless(os.environ.get('GODOT_BIN'), 'Set GODOT_BIN for actual Godot integration')
    def test_manual_team_gears_and_erg_return(self):
        # A simulator left RELEASED by a previous Godot process must be usable
        # after an explicit new race start, without restarting the simulator.
        self.bridge.mode = 'RELEASED'
        self.bridge.desired_mode = 'ERG'
        self.bridge.released = True
        self.run_integration('test_team_bridge.gd')

    def run_integration(self, script, require_commands=True):
        # Bind the game on the receiver's ephemeral port, avoiding any running game.
        port = self.receiver.getsockname()[1]
        self.receiver.close()
        repo = SOURCE.parents[2]
        command_port = self.bridge.rx.getsockname()[1]
        command = [os.environ['GODOT_BIN'], '--headless', '--path', os.environ.get('GODOT_PROJECT', str(repo/'game')),
                   '--script', 'res://tests/'+script, '--',
                   str(port), str(command_port)]
        with tempfile.TemporaryDirectory() as folder:
            log_path = Path(folder) / 'godot.log'
            with log_path.open('w+b') as log:
                self.run_godot(command, log, log_path, require_commands=require_commands)

    def run_godot(self, command, log, log_path, require_commands=True):
        with subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT) as proc:
            deadline = time.monotonic() + 45
            shifted = False
            steered = False
            flow_steps = set()
            try:
                while proc.poll() is None and time.monotonic() < deadline:
                    progress = log_path.read_text(errors='replace')
                    for step, button, edge in [('CAPTURE', 'POWER_LEFT', 'tap'),
                                               ('LOOK_DOWN', 'A', 'down'), ('LOOK_UP', 'A', 'up'),
                                               ('INFO_DOWN', 'POWER_LEFT', 'down'), ('INFO_UP', 'POWER_LEFT', 'up')]:
                        marker = 'RIDE_MAP_' + step
                        if marker in progress and marker not in flow_steps:
                            if edge == 'tap': self.bridge.button(button)
                            elif edge == 'down': self.bridge.press_button(button)
                            else: self.bridge.release_button(button)
                            flow_steps.add(marker)
                    for step in ['MODE_RIGHT', 'MODE_A', 'OPPONENT_A', 'STRENGTH_UP',
                                 'CAROUSEL_UP', 'OPPONENT_RIGHT', 'PERCENT_DOWN',
                                 'PERCENT_RIGHT', 'START_DOWN', 'START_A']:
                        marker = 'PURSUIT_FLOW_'+step
                        if marker in progress and marker not in flow_steps:
                            self.bridge.button(step.rsplit('_', 1)[1])
                            flow_steps.add(marker)
                    for step, button in [('SETTINGS', 'Z'), ('CLOSE', 'B'), ('SELECT', 'A'),
                                         ('CONFIG', 'A'), ('START', 'A'), ('SKIP', 'A'),
                                         ('LOOK_DOWN', 'B'), ('LOOK_UP', 'B'), ('PAUSE', 'Z'),
                                         ('RESUME', 'A'), ('RESULTS', 'B')]:
                        if 'RIDE_FLOW_'+step in progress and step not in flow_steps:
                            if step == 'LOOK_DOWN': self.bridge.press_button(button)
                            elif step == 'LOOK_UP': self.bridge.release_button(button)
                            else: self.bridge.button(button)
                            flow_steps.add(step)
                    self.bridge.packet_drop.set('VIRTUAL_BRIDGE_DROP' in progress and 'VIRTUAL_BRIDGE_RESTORE' not in progress)
                    if 'TEAM_BRIDGE_POWER' in progress:
                        self.bridge.power.set(300)
                        self.bridge.speed.set(35)
                        self.bridge.cadence.set(90)
                    if ('VIRTUAL_BRIDGE_SHIFT' in progress or 'TEAM_BRIDGE_SHIFT' in progress) and not shifted:
                        self.bridge.shift(1)
                        shifted = True
                    if ('TEAM_BRIDGE_STEER' in progress or 'VIRTUAL_BRIDGE_STEER' in progress) and not steered:
                        self.bridge.right_paddle.set(25)
                        steered = True
                    self.bridge.loop()
                    time.sleep(.02)
                if proc.poll() is None:
                    proc.kill()
                    proc.wait()
                    log.seek(0)
                    self.fail('Godot integration timed out: '+log.read().decode(errors='replace'))
                log.seek(0)
                output = log.read().decode(errors='replace')
                self.assertEqual(proc.returncode, 0, output)
                self.assertNotIn('SCRIPT ERROR', output)
                self.assertIn('VIRTUAL_BRIDGE_OK', output)
                if require_commands:
                    self.assertGreater(self.bridge.counter, 0, 'Godot must send actual trainer commands')
            finally:
                if proc.poll() is None: proc.kill(); proc.wait()


if __name__ == '__main__':
    unittest.main()
