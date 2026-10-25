"""FTMS 0x11 road model with virtual gearing and one serialized writer.

At physical speed v and virtual ratio k, requested power scales road forces
by k and aerodynamic force by k**3. Trainer-internal mass/physics remain unknown;
this is an approximation of virtual gearing, not mechanical gear shifting.
"""
import json
import math
from pathlib import Path
import struct
import time

SIMULATION_FEATURE = 1 << 13
CONFIG_PATH = Path(__file__).with_name('simulation_config.json')

def finite_number(value, minimum, maximum):
    return type(value) in (int, float) and minimum <= value <= maximum and math.isfinite(value)

def grade_units(value):
    if not finite_number(value, -20, 20):
        raise ValueError('grade_pct moet een eindig getal van -20.00 t/m 20.00 zijn')
    scaled = value * 100
    if abs(scaled - round(scaled)) > 0.000001:
        raise ValueError('grade_pct heeft maximaal twee decimalen')
    return round(scaled)

def validate_grade_rate(value):
    if not finite_number(value, 0.1, 100):
        raise ValueError('ramp_pct_per_s moet 0.1..100 zijn')
    return float(value)

def encode_simulation(grade_pct, crr, cw):
    # These values are already modelled, not the incoming game grade.
    if not (finite_number(grade_pct, -327.68, 327.67)
            and finite_number(crr, 0, 0.0255) and finite_number(cw, 0, 2.55)):
        raise ValueError('Simulatieparameters passen niet in FTMS; geen stille begrenzing')
    return b'\x11' + struct.pack('<hhBB', 0, round(grade_pct * 100), round(crr * 10000), round(cw * 100))

def model(grade_pct, factor, crr, cw):
    theta = math.atan(grade_pct / 100)
    sin_effective = factor * math.sin(theta)
    if abs(sin_effective) >= 1:
        raise ValueError('Effectieve helling niet representeerbaar')
    effective_theta = math.asin(sin_effective)
    return (math.tan(effective_theta) * 100,
            crr * factor * math.cos(theta) / math.cos(effective_theta), cw * factor**3)

class RoadSimulation:
    def __init__(self, clock=time.monotonic, config_path=CONFIG_PATH):
        config = json.loads(Path(config_path).read_text(encoding='utf-8'))
        factors = config.get('gear_factors')
        if not isinstance(factors, list) or len(factors) != 12 or any(not finite_number(x, 0.5, 2) for x in factors):
            raise ValueError('simulation_config: twaalf gear_factors van 0.5..2 vereist')
        if any(b <= a for a, b in zip(factors, factors[1:])):
            raise ValueError('simulation_config: gear_factors moeten strikt oplopen')
        self.factors = factors
        self.crr = config.get('rolling_resistance')
        self.cw = config.get('wind_resistance')
        self.rate = validate_grade_rate(config.get('grade_ramp_pct_per_s'))
        self.factor_rate = config.get('gear_factor_per_s')
        if not (finite_number(self.crr, 0, .0255) and finite_number(self.cw, 0, 2.55)
                and finite_number(self.factor_rate, 0.01, 5)):
            raise ValueError('simulation_config: ongeldige weerstandscoefficienten/versnellingsramp')
        # Verify the entire permitted domain, not just the current gear/grade.
        for factor in [*self.factors, 1.0]:
            for grade in (-20, 0, 20):
                encode_simulation(*model(grade, factor, self.crr, self.cw))
        self.clock = clock
        self.reset()

    def reset(self):
        self.grade = 0.0
        self.factor = 1.0
        self.last_time = self.clock()
        self.last_packet = None

    def target(self, grade, gear):
        return model(grade, self.factors[gear - 1], self.crr, self.cw)

    def confirmed(self):
        if self.last_packet is None:
            return None
        wind, grade, crr, cw = struct.unpack('<hhBB', self.last_packet[1:])
        return {'grade_pct': grade / 100, 'wind_mps': wind / 1000,
                'crr': crr / 10000, 'cw': cw / 100}

    async def tick(self, controller, target_grade, gear):
        now = self.clock()
        dt = min(0.35, max(0.0, now - self.last_time))
        self.last_time = now
        target_factor = self.factors[gear - 1]
        def approach(current, target, step):
            return current + max(-step, min(step, target - current))
        grade = approach(self.grade, target_grade, self.rate * dt)
        factor = approach(self.factor, target_factor, self.factor_rate * dt)
        packet = encode_simulation(*model(grade, factor, self.crr, self.cw))
        if packet != self.last_packet:
            await controller.command(packet)
            self.last_packet = packet
        self.grade, self.factor = grade, factor
        return abs(grade - target_grade) < 1e-8 and abs(factor - target_factor) < 1e-8
