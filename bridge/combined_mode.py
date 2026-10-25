"""Single trainer-loop writer. Console/UDP only change desired state, never do BLE I/O."""
import logging
import math
import time
from virtual_shift import VirtualShifter, RAMP_PERIOD
from erg_protocol import encode_target_power, parse_power_range, POWER_RANGE, TARGET_POWER_FEATURE
from resistance import FEATURE
from simulation import RoadSimulation, SIMULATION_FEATURE, grade_units, validate_grade_rate

log = logging.getLogger(__name__)
LEASE_SECONDS = 5.0

class CommandError(ValueError):
    def __init__(self, code, message):
        super().__init__(message)
        self.code = code

def validate_rate(value):
    if type(value) not in (int, float) or not 1 <= value <= 10000 or not math.isfinite(value):
        raise CommandError('invalid_ramp', 'ramp_w_per_s moet 1..10000 zijn')
    return float(value)

class CombinedMode:
    def __init__(self, ramp_w_per_s=300.0, clock=time.monotonic):
        self.shifter = VirtualShifter()
        self.mode = 'SIM'
        self.desired_mode = 'SIM'
        self.target_w = 100
        self.sent_w = None
        self.disabled = False
        self.started = False
        self.power_supported = False
        self.simulation_supported = False
        self.sim_backend = self.desired_sim_backend = 'resistance'
        self.grade_pct = 0.0
        self.road = RoadSimulation(clock=clock)
        self.power_range = None
        self.range_state = 'unknown'
        self.last_error = None
        self.release_confirmed = False
        self.ramp_w_per_s = validate_rate(ramp_w_per_s)
        self.clock = clock
        self.revision = 0
        self.applied_revision = -1
        self.owner = None
        self.lease_until = 0.0
        self._ramp_at = clock()
        self._credit = 0.0
        self._sim_at = -math.inf

    def selected_gear(self):
        if self.started and not self.disabled and self.mode == self.desired_mode == 'SIM' and self.shifter.enabled:
            return self.shifter.gear
        return None

    async def check_supported(self, client):
        raw = bytes(await client.read_gatt_char(FEATURE))
        self.power_supported = len(raw) >= 8 and bool(int.from_bytes(raw[4:8], 'little') & TARGET_POWER_FEATURE)
        self.simulation_supported = len(raw) >= 8 and bool(int.from_bytes(raw[4:8], 'little') & SIMULATION_FEATURE)
        # Missing characteristic is tolerated. A present but unreadable/malformed
        # range blocks positive ERG requests; SIM remains available.
        characteristic = client.services.get_characteristic(POWER_RANGE)
        if characteristic is not None:
            try:
                self.power_range = parse_power_range(bytes(await client.read_gatt_char(POWER_RANGE)))
                self.range_state = 'known'
            except Exception as exc:
                self.range_state = 'invalid'
                log.error('FTMS 0x2AD8 niet bruikbaar: %s', exc)
        else:
            self.range_state = 'unavailable'
            log.warning('FTMS 0x2AD8 ontbreekt; positieve doelen worden door trainer beoordeeld')
        self.started = True
        log.info('FTMS power_supported=%s power_range=%s range_state=%s simulation_supported=%s',
                 self.power_supported, self.power_range, self.range_state, self.simulation_supported)

    def validate_target(self, watts):
        try:
            encode_target_power(watts)
        except ValueError as exc:
            raise CommandError('invalid_power', str(exc)) from exc
        if watts == 0:
            return  # Release is Reset, not Set Target Power 0.
        if not self.power_supported:
            raise CommandError('erg_unsupported', 'Trainer ondersteunt geen Target Power')
        if self.range_state == 'invalid':
            raise CommandError('range_unavailable', 'Trainerbereik aanwezig maar niet leesbaar/geldig; ERG geblokkeerd')
        if self.power_range is not None:
            minimum, maximum, increment = self.power_range
            if not minimum <= watts <= maximum or (watts - minimum) % increment:
                raise CommandError('unsupported_power', f'{watts} W niet ondersteund: min={minimum}, max={maximum}, stap={increment} W; doel niet aangepast')

    def on_button(self, button):
        if self.selected_gear() is not None:
            simulation = self.desired_sim_backend == 'simulation'
            if self.shifter.on_button(button, announce=not simulation) and simulation:
                self.revision += 1
                log.info('Virtuele simulatieversnelling=%s factor=%s', self.shifter.gear, self.road.factors[self.shifter.gear - 1])

    def request_stop(self, reason='stop'):
        if self.disabled:
            return
        self.disabled = True
        self.owner = None
        self.revision += 1
        self.last_error = reason
        log.warning('Regeling gestopt: %s; reset volgt via trainer-loop', reason)

    def status(self):
        limits = None
        if self.power_range is not None:
            limits = dict(zip(('min_w', 'max_w', 'increment_w'), self.power_range))
        return {'started': self.started, 'disabled': self.disabled,
                'mode': self.mode, 'desired_mode': self.desired_mode,
                'target_w': self.target_w, 'confirmed_target_w': self.sent_w,
                'ramp_w_per_s': self.ramp_w_per_s, 'revision': self.revision,
                'applied_revision': self.applied_revision, 'release_confirmed': self.release_confirmed,
                'power_supported': self.power_supported, 'power_range': limits,
                'range_state': self.range_state, 'last_error': self.last_error,
                'simulation_supported': self.simulation_supported,
                'sim_backend': self.sim_backend, 'desired_sim_backend': self.desired_sim_backend,
                'grade_pct': self.grade_pct, 'grade_ramp_pct_per_s': self.road.rate,
                'gear_factor': self.road.factors[self.shifter.gear - 1],
                'effective_grade_pct': round(self.road.target(self.grade_pct, self.shifter.gear)[0], 2),
                'confirmed_simulation': self.road.confirmed() if self.mode == 'SIM' and self.sim_backend == 'simulation' else None,
                'udp_owned': self.owner is not None,
                'lease_remaining_s': round(max(0.0, self.lease_until - self.clock()), 2) if self.owner else 0.0}

    def accept(self, command, params=None, source=None):
        """Synchronous on the asyncio thread; accepted != physically applied."""
        params = params or {}
        if command == 'status':
            return self.status()
        if command == 'stop':
            self.request_stop('udp_stop' if source else 'console_stop')
            return self.status()
        if not self.started or self.disabled:
            raise CommandError('not_active', 'FTMS-control niet actief; wacht op verbinding of herstart na STOP/fout')
        if self.owner is not None and self.clock() >= self.lease_until:
            self.request_stop('udp_timeout')
            raise CommandError('not_active', 'UDP-lease verlopen; herstart nodig')
        if source is not None and self.owner not in (None, source):
            raise CommandError('control_busy', 'Een andere UDP-client bestuurt de trainer; stop/status blijven beschikbaar')
        if command == 'heartbeat':
            if source is None or self.owner != source:
                raise CommandError('no_lease', 'Deze UDP-client heeft geen actieve lease')
            self.lease_until = self.clock() + LEASE_SECONDS
            return self.status()
        if command == 'set_mode':
            mode = params.get('mode')
            if mode not in ('SIM', 'ERG'):
                raise CommandError('invalid_mode', 'mode moet SIM of ERG zijn')
            if mode == 'ERG':
                self.validate_target(self.target_w)
            self.desired_mode = mode
            self.desired_sim_backend = 'resistance'
            self.grade_pct = 0.0
        elif command == 'set_grade':
            if self.desired_mode != 'SIM':
                raise CommandError('wrong_mode', 'Helling alleen in SIM; schakel eerst expliciet naar SIM')
            if not self.simulation_supported:
                raise CommandError('simulation_unsupported', 'Trainer meldt geen FTMS Indoor Bike Simulation-ondersteuning')
            try:
                grade = grade_units(params.get('grade_pct')) / 100
                rate = validate_grade_rate(params.get('ramp_pct_per_s', self.road.rate))
            except ValueError as exc:
                raise CommandError('invalid_grade', str(exc)) from exc
            self.grade_pct, self.road.rate = grade, rate
            self.desired_sim_backend = 'simulation'
        elif command == 'set_target_power':
            watts = params.get('watts')
            self.validate_target(watts)
            rate = validate_rate(params.get('ramp_w_per_s', self.ramp_w_per_s))
            if rate != self.ramp_w_per_s:
                self._credit = 0.0
            self.target_w, self.ramp_w_per_s = watts, rate
            if watts == 0:
                self.desired_mode = 'ERG'  # Always release, including when in SIM.
        else:
            raise CommandError('unknown_command', 'Onbekend commando')
        # Console explicitly takes over. Staging a positive target in SIM does
        # not acquire a lease. A fresh ERG control command renews its owner's lease.
        remote_control = ((self.desired_mode == 'ERG' and self.target_w > 0)
                          or (self.desired_mode == 'SIM' and self.desired_sim_backend == 'simulation'))
        self.owner = source if remote_control else None
        self.lease_until = self.clock() + LEASE_SECONDS if self.owner else 0.0
        self.revision += 1
        log.info('ACCEPT source=%s command=%s params=%s revision=%s', source or 'console', command, params, self.revision)
        return self.status()

    def handle_command(self, line):
        fields = line.split()
        if line in ('sim', 'erg'):
            result = self.accept('set_mode', {'mode': line.upper()})
        elif line in ('stop', 'x', 'quit', 'exit'):
            result = self.accept('stop')
        elif line == 'status':
            result = self.status()
        elif len(fields) in (2, 3) and fields[0] == 'grade':
            try:
                params = {'grade_pct': float(fields[1])}
                if len(fields) == 3:
                    params['ramp_pct_per_s'] = float(fields[2])
            except ValueError as exc:
                raise ValueError('Gebruik grade -20..20 [procentpunt_per_seconde]') from exc
            result = self.accept('set_grade', params)
        elif len(fields) in (2, 3) and fields[0] == 'target':
            try:
                params = {'watts': int(fields[1])}
                if len(fields) == 3:
                    params['ramp_w_per_s'] = float(fields[2])
            except ValueError as exc:
                raise ValueError('Gebruik target 0..1300 [watt_per_seconde]') from exc
            result = self.accept('set_target_power', params)
        else:
            raise ValueError('Gebruik sim, grade -20..20 [pct/s], erg, target 0..1300 [W/s], status of stop')
        return str(result)

    async def tick(self, controller, sender):
        now = self.clock()
        if self.owner is not None and now >= self.lease_until:
            self.request_stop('udp_timeout')
        if self.disabled:
            if controller.active:
                await controller.release()
                self.release_confirmed = True
                self.mode, self.sent_w = 'RELEASED', None
            return
        if not self.started:
            return
        feedback_required = ((self.desired_mode == 'ERG' and self.target_w > 0)
                             or (self.desired_mode == 'SIM' and self.desired_sim_backend == 'simulation'))
        if feedback_required and (
                not sender.connected or now - sender.last_received > 3.0 or now - sender.last_power > 3.0):
            self.request_stop('trainer_data_timeout')
            await self.tick(controller, sender)
            return
        revision = self.revision
        # 0 is a release request. Never send a possibly unsupported 0 W target.
        destination = 'RELEASED' if self.desired_mode == 'ERG' and self.target_w == 0 else self.desired_mode
        requested_backend = self.desired_sim_backend
        def route_still_current():
            current = 'RELEASED' if self.desired_mode == 'ERG' and self.target_w == 0 else self.desired_mode
            return (not self.disabled and current == destination
                    and (destination != 'SIM' or self.desired_sim_backend == requested_backend))
        backend_changed = destination == 'SIM' and self.desired_sim_backend != self.sim_backend
        if destination != self.mode or backend_changed or (destination == 'RELEASED' and controller.active):
            await controller.release()
            self.mode, self.sent_w = 'RELEASED', None
            self.release_confirmed = True
            self.shifter.current = None
            self._credit = 0.0
            self._ramp_at = self.clock()
            self.road.reset()
            if not route_still_current():
                return  # Newer request wins before sending any new-mode command.
            if destination != 'RELEASED':
                await controller.initialize()
                self.release_confirmed = False
                if not route_still_current():
                    return
                self.mode = destination
                if destination == 'SIM':
                    self.sim_backend = requested_backend
        if destination == 'RELEASED':
            self.applied_revision = revision
            return
        if self.mode == 'SIM':
            if self.sim_backend == 'simulation':
                complete = await self.road.tick(controller, self.grade_pct, self.shifter.gear)
                if complete and revision == self.revision:
                    self.applied_revision = revision
                return
            if now - self._sim_at >= RAMP_PERIOD:
                await self.shifter.tick(controller)
                self._sim_at = now
            if revision == self.revision:
                self.applied_revision = revision
            return
        # Time-based slew with fractional credit; no fixed 10 W limit. Do not
        # catch up a long BLE stall with a large resistance jump.
        dt = min(0.35, max(0.0, self.clock() - self._ramp_at))
        self._ramp_at = self.clock()
        self._credit += self.ramp_w_per_s * dt
        minimum, maximum, quantum = self.power_range or (0, 1300, 1)
        first = minimum if minimum > 0 else minimum + ((-minimum) // quantum + 1) * quantum
        if self.sent_w is None:
            next_w = first
        else:
            if self.sent_w == self.target_w:
                self._credit = 0.0
                self.applied_revision = revision
                return
            step = int(self._credit // quantum) * quantum
            if step == 0:
                return
            diff = self.target_w - self.sent_w
            next_w = self.sent_w + max(-step, min(step, diff))
        self.validate_target(next_w)
        await controller.command(encode_target_power(next_w))
        self._credit = max(0.0, self._credit - abs(next_w - (self.sent_w or 0)))
        self.sent_w = next_w
        log.info('FTMS bevestigd ERG=%s W revision=%s', next_w, revision)
        if next_w == self.target_w and revision == self.revision:
            self.applied_revision = revision
