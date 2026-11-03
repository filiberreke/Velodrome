"""Velodrome virtual bridge: offline Zwift Ride/KICKR test, Python stdlib only.

Run ONLY when the real bridge is stopped. No Bluetooth or trainer commands.
"""
import json
from pathlib import Path
import socket
import time
import tkinter as tk
from tkinter import ttk, messagebox

HOST = "127.0.0.1"
TELEMETRY_PORT = 51723
COMMAND_PORT = 51725

class VirtualBridge:
    def __init__(self, root):
        self.root = root
        root.title("Velodrome - virtuele bridge (geen hardware)")
        self.tx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.rx = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            self.rx.bind((HOST, COMMAND_PORT))
        except OSError as exc:
            self.rx.close()
            self.tx.close()
            messagebox.showerror("Poort bezet", f"Kan UDP {COMMAND_PORT} niet openen. Sluit eerst de echte bridge.\n{exc}")
            raise
        self.rx.setblocking(False)
        mapping_path = Path(__file__).resolve().parents[1] / "button_mapping.json"
        self.mapping = json.loads(mapping_path.read_text(encoding="utf-8"))
        self.held_buttons = set()
        self.ride_connected = tk.BooleanVar(value=True)
        self.last_ride_connection = None
        self.gear = 4
        self.sample = 0
        self.power = tk.DoubleVar(value=0)
        self.speed = tk.DoubleVar(value=0)
        self.cadence = tk.DoubleVar(value=0)
        self.hr = tk.DoubleVar(value=140)
        self.steering = tk.DoubleVar(value=0)
        self.left_paddle = tk.DoubleVar(value=0)
        self.right_paddle = tk.DoubleVar(value=0)
        self.connected = tk.BooleanVar(value=True)
        self.send_gear = tk.BooleanVar(value=True)
        self.packet_drop = tk.BooleanVar(value=False)
        self.mode = "SIM"
        self.desired_mode = "SIM"
        self.backend = "resistance"
        self.owner = None
        self.lease = 0.
        self.target = 0
        self.grade = 0.
        self.aero = 1.
        self.released = False
        self.counter = 0
        self.last_received = 0.
        self.status = tk.StringVar(value="Wacht op Godot...")
        self.gear_text = tk.StringVar()
        frm = ttk.Frame(root, padding=14)
        frm.pack(fill="both", expand=True)
        ttk.Label(frm, text="Virtuele bridge - start Godot en rijd in testmodus", font=("", 12, "bold")).pack(anchor="w")
        ttk.Label(frm, text="Geen Zwift Ride of KICKR vereist. Sluit de echte bridge vooraf.").pack(anchor="w")
        for name, var, lo, hi in (("Vermogen (W)", self.power, 0, 900),
                                  ("Snelheid (km/u)", self.speed, 0, 70),
                                  ("Cadans (rpm)", self.cadence, 0, 140),
                                  ("Hartslag (bpm)", self.hr, 0, 210),
                                  ("Linker paddle (buiten - / rem +)", self.left_paddle, -100, 100),
                                  ("Rechter paddle (rem - / buiten +)", self.right_paddle, -100, 100)):
            row = ttk.Frame(frm)
            row.pack(fill="x", pady=3)
            ttk.Label(row, text=name, width=32).pack(side="left")
            ttk.Scale(row, from_=lo, to=hi, variable=var).pack(side="left", fill="x", expand=True)
            ttk.Label(row, textvariable=var, width=6).pack(side="right")
        paddles = ttk.Frame(frm)
        paddles.pack(fill="x", pady=4)
        for caption, variable in (("Links loslaten", self.left_paddle), ("Rechts loslaten", self.right_paddle)):
            ttk.Button(paddles, text=caption, command=lambda v=variable: v.set(0)).pack(side="left", padx=3)
        ttk.Button(paddles, text="Beide loslaten", command=self.release_paddles).pack(side="left", padx=3)
        ttk.Label(paddles, text="Stuurwaarde:").pack(side="left", padx=3)
        ttk.Label(paddles, textvariable=self.steering).pack(side="left")
        ttk.Label(frm, text="Ride-knoppen: houd de muis ingedrukt en laat los").pack(anchor="w")
        button_grid = ttk.Frame(frm)
        button_grid.pack(fill="x", pady=6)
        ride_buttons = [
            ("Links", "LEFT"), ("Rechts", "RIGHT"), ("Omhoog", "UP"), ("Omlaag", "DOWN"),
            ("A", "A"), ("B", "B"), ("Y", "Y"), ("Z", "Z"),
            ("Shift L+", "SHIFT_UP_LEFT"), ("Shift L-", "SHIFT_DOWN_LEFT"),
            ("Shift R+", "SHIFT_UP_RIGHT"), ("Shift R-", "SHIFT_DOWN_RIGHT"),
            ("Power L", "POWER_LEFT"), ("Power R", "POWER_RIGHT"),
            ("Aan/uit L", "ONOFF_LEFT"), ("Aan/uit R", "ONOFF_RIGHT"),
        ]
        for index, (caption, key) in enumerate(ride_buttons):
            button_widget = ttk.Button(button_grid, text=caption)
            button_widget.grid(row=index // 4, column=index % 4, sticky="ew", padx=3, pady=3)
            button_widget.bind("<ButtonPress-1>", lambda _event, b=key: self.press_button(b))
            button_widget.bind("<ButtonRelease-1>", lambda _event, b=key: self.release_button(b))
        for column in range(4):
            button_grid.columnconfigure(column, weight=1)
        shift = ttk.Frame(frm)
        shift.pack(fill="x", pady=4)
        ttk.Button(shift, text="Schakel lichter", command=lambda: self.shift(-1)).pack(side="left")
        ttk.Label(shift, textvariable=self.gear_text, width=20, anchor="center").pack(side="left")
        ttk.Button(shift, text="Schakel zwaarder", command=lambda: self.shift(1)).pack(side="left")
        ttk.Checkbutton(frm, text="Zwift Ride verbonden", variable=self.ride_connected).pack(anchor="w")
        ttk.Checkbutton(frm, text="KICKR telemetrie geldig", variable=self.connected).pack(anchor="w")
        ttk.Checkbutton(frm, text="Versnelling opnemen in telemetrie", variable=self.send_gear).pack(anchor="w")
        ttk.Checkbutton(frm, text="Simuleer verlies van bridge -> Godot UDP-telemetrie", variable=self.packet_drop).pack(anchor="w")
        ttk.Label(frm, textvariable=self.status, wraplength=600).pack(anchor="w", pady=6)
        ttk.Label(frm, text="Godot -> bridge commando's (UDP 51725):").pack(anchor="w")
        self.log = tk.Text(frm, height=10, width=78, state="disabled")
        self.log.pack(fill="both", expand=True)
        self.gear_text.set("Versnelling 4/12")
        root.protocol("WM_DELETE_WINDOW", self.close)
        self.running = True
        self.loop()

    def write(self, line):
        self.log.configure(state="normal")
        self.log.insert("end", time.strftime("%H:%M:%S ") + line + "\n")
        if int(self.log.index("end-1c").split(".")[0]) > 140:
            self.log.delete("1.0", "30.0")
        self.log.see("end")
        self.log.configure(state="disabled")

    def release_paddles(self):
        self.left_paddle.set(0)
        self.right_paddle.set(0)

    def transmit(self, obj):
        if not self.packet_drop.get():
            self.send_udp(self.tx, obj, (HOST, TELEMETRY_PORT))

    @staticmethod
    def send_udp(sock, obj, address):
        try:
            sock.sendto(json.dumps(obj).encode("utf-8"), address)
        except (ConnectionResetError, ConnectionRefusedError):
            # A Godot socket can close between receive and reply. Keep polling.
            pass

    def press_button(self, button):
        if not self.ride_connected.get() or button in self.held_buttons:
            return
        self.held_buttons.add(button)
        mapped = self.mapping.get(button, "")
        self.transmit({"type": "controller_button", "source_button": button,
                       "mapped_action": mapped, "pressed": True})
        if mapped:
            self.transmit({"type": "button", "button": mapped, "source_button": button})
        self.write("Ride ingedrukt: " + button + (" -> " + mapped if mapped else ""))

    def release_button(self, button):
        if button not in self.held_buttons:
            return
        self.held_buttons.remove(button)
        self.transmit({"type": "controller_button", "source_button": button,
                       "mapped_action": self.mapping.get(button, ""), "pressed": False})
        self.write("Ride losgelaten: " + button)

    def button(self, button):
        """Complete press/release for automated tests."""
        self.press_button(button)
        self.release_button(button)

    def shift(self, delta):
        self.gear = min(12, max(1, self.gear + delta))
        self.gear_text.set(f"Versnelling {self.gear}/12")
        self.button("SHIFT_UP_RIGHT" if delta > 0 else "SHIFT_DOWN_LEFT")

    def snapshot(self):
        now = time.monotonic()
        return {
            "started": True, "disabled": False, "waiting_for_feedback": False,
            "reconnect_ready": False, "release_confirmed": self.released,
            "mode": self.mode, "desired_mode": self.desired_mode,
            "sim_backend": self.backend, "desired_sim_backend": self.backend,
            "simulation_supported": True, "aero_scale_supported": True,
            "udp_owned": self.owner is not None, "lease_remaining_s": max(0., self.lease-now) if self.owner else 0.,
            "grade_pct": self.grade, "aero_scale": self.aero,
            "target_w": self.target, "confirmed_target_w": self.target,
            "last_error": ""
        }

    def command(self, data, address):
        request_id = None
        try:
            obj = json.loads(data.decode("utf-8"))
            if not isinstance(obj, dict):
                return
            request_id = obj.get("id")
            if obj.get("type") != "command" or obj.get("v") != 1:
                raise ValueError("invalid_envelope")
            action = obj.get("command")
            now = time.monotonic()
            if self.owner and now > self.lease:
                self.owner = None
                self.mode = "RELEASED"
                self.desired_mode = "ERG"
                self.target = 0
                self.released = True
                self.write("Lease verlopen: gesimuleerde regeling vrijgegeven")
            if action == "status":
                pass
            elif action == "set_mode":
                mode = obj.get("mode")
                if mode not in ("SIM", "ERG"):
                    raise ValueError("invalid_mode")
                if self.owner and self.owner != address:
                    raise ValueError("control_busy")
                self.desired_mode = mode
                self.mode = mode
                self.backend = "resistance"
                self.owner = None
                self.released = False
            elif action == "set_grade":
                if self.desired_mode != "SIM":
                    raise ValueError("wrong_mode")
                if self.owner and self.owner != address:
                    raise ValueError("control_busy")
                self.grade = float(obj["grade_pct"])
                self.aero = float(obj.get("aero_scale", 1.))
                if not -20 <= self.grade <= 20 or not 0 <= self.aero <= 1:
                    raise ValueError("invalid_grade")
                self.backend = "simulation"
                self.owner = address
                self.lease = now+5.
            elif action == "set_target_power":
                watts = int(obj["watts"])
                if not 0 <= watts <= 1300:
                    raise ValueError("unsupported_power")
                if watts == 0:
                    if self.owner and self.owner != address:
                        raise ValueError("control_busy")
                    self.owner = None
                    self.mode = "RELEASED"
                    self.desired_mode = "ERG"
                    self.target = 0
                    self.released = True
                else:
                    if self.desired_mode != "ERG":
                        raise ValueError("wrong_mode")
                    if self.owner and self.owner != address:
                        raise ValueError("control_busy")
                    self.owner = address
                    self.lease = now+5.
                    self.target = watts
            elif action == "heartbeat":
                if self.owner != address:
                    raise ValueError("no_lease")
                self.lease = now+5.
            elif action == "stop":
                self.owner = None
                self.mode = "RELEASED"
                self.desired_mode = "ERG"
                self.released = True
            else:
                raise ValueError("unknown_command")
            reply = {"type": "ack", "v": 1, "id": request_id, "ok": True, "state": self.snapshot()}
            if action != "status" and action != "heartbeat":
                self.write(f"Godot -> bridge: {action} {obj}")
        except (ValueError, KeyError, TypeError) as exc:
            reply = {"type": "error", "v": 1, "id": request_id, "ok": False,
                     "code": str(exc), "state": self.snapshot()}
            self.write("COMMAND ERROR: " + str(exc))
        self.send_udp(self.rx, reply, address)
        self.counter += 1

    def loop(self):
        if not self.running:
            return
        self.sample += 1
        ride_ready = bool(self.ride_connected.get())
        if ride_ready != self.last_ride_connection:
            if not ride_ready:
                for button in sorted(self.held_buttons):
                    self.release_button(button)
            self.transmit({"type": "controller_connection", "connected": ride_ready})
            self.last_ride_connection = ride_ready
        self.steering.set(max(0, round(self.right_paddle.get())) - max(0, -round(self.left_paddle.get())))
        self.transmit({'type': 'steering', 'value': round(self.steering.get())})
        if not self.packet_drop.get():
            self.transmit({"type": "telemetry", "valid": self.connected.get(),
                           "power_w": round(self.power.get()), "speed_kmh": self.speed.get(),
                           "cadence_rpm": round(self.cadence.get()), "heart_rate_bpm": round(self.hr.get()),
                           "sample_id": self.sample,
                           "gear": self.gear if self.send_gear.get() and self.mode == self.desired_mode == "SIM" else None})
        try:
            while True:
                data, address = self.rx.recvfrom(4096)
                if address[0] == HOST:
                    self.command(data, address)
        except (BlockingIOError, ConnectionResetError, ConnectionRefusedError):
            pass
        self.status.set(f"Verzonden: {self.sample} telemetrieframes | Godot commando's: {self.counter} | "
                        f"Trainer: {self.mode} / {self.backend} | {self.target} W ERG | "
                        f"helling {self.grade:.2f}% | aero {self.aero:.2f} | eigenaar: {bool(self.owner)}")
        self.root.after(100, self.loop)

    def close(self):
        for button in sorted(self.held_buttons):
            self.release_button(button)
        self.transmit({"type": "controller_connection", "connected": False})
        self.running = False
        self.rx.close()
        self.tx.close()
        self.root.destroy()

if __name__ == "__main__":
    root = tk.Tk()
    VirtualBridge(root)
    root.mainloop()

