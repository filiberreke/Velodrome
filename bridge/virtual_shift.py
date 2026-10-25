"""Opt-in 12-gear controller, independent of the game button mapping."""
import asyncio
import time
import json
from pathlib import Path

# Hard boundaries apply even if the configuration file contains invalid values.
MIN_LEVEL = 1.5
MAX_LEVEL = 5.0
LEVELS = (1.5, 1.6, 1.7, 1.8, 2.0, 2.2, 2.5, 2.8, 3.2, 3.7, 4.3, 5.0)
INITIAL_GEAR = 4
CONFIG_PATH = Path(__file__).with_name('gear_config.json')

def load_config(path=CONFIG_PATH):
    raw = json.loads(Path(path).read_text(encoding='utf-8'))
    levels = raw.get('levels')
    gear = raw.get('initial_gear', INITIAL_GEAR)
    if not isinstance(levels, list) or len(levels) != 12:
        raise ValueError('gear_config.json: levels moet exact 12 waarden bevatten')
    if any(type(x) not in (int, float) or not MIN_LEVEL <= x <= MAX_LEVEL for x in levels):
        raise ValueError('gear_config.json: elk niveau moet tussen 1.5 en 5.0 liggen')
    if any(round(float(x)*10, 5) != round(float(x)*10) for x in levels):
        raise ValueError('gear_config.json: FTMS heeft stappen van 0.1')
    if any(float(b) <= float(a) for a,b in zip(levels, levels[1:])):
        raise ValueError('gear_config.json: niveaus moeten strikt oplopen')
    if type(gear) is not int or not 1 <= gear <= 12:
        raise ValueError('gear_config.json: initial_gear moet 1..12 zijn')
    return tuple(float(x) for x in levels), gear
STEP_PER_COMMAND = 0.5
RAMP_PERIOD = 0.35

class VirtualShifter:
    def __init__(self, config_path=CONFIG_PATH):
        self.levels, self.initial_gear = load_config(config_path)
        self.gear = self.initial_gear
        self.enabled = True
        self.last_button_at = 0.0
        self.target = self.levels[self.gear - 1]
        self.current = None

    def on_button(self, button, announce=True):
        # Each pressed-edge is handled once by ride_loop. All left paddles down;
        # all right paddles up. Never use directional pad LEFT/RIGHT here.
        direction = -1 if button in ('SHIFT_UP_LEFT', 'SHIFT_DOWN_LEFT') else (1 if button in ('SHIFT_UP_RIGHT', 'SHIFT_DOWN_RIGHT') else 0)
        if not direction or not self.enabled:
            return False
        now = time.monotonic()
        if now - self.last_button_at < 0.18:
            return False
        self.last_button_at = now
        new_gear = max(1, min(len(self.levels), self.gear + direction))
        if new_gear == self.gear:
            return False
        self.gear = new_gear
        self.target = self.levels[self.gear - 1]
        if announce:
            print(f'SCHAKELVERZOEK {self.gear}/12 -> gewenst FTMS niveau {self.target:.1f} (nog niet bevestigd)')
        return True

    async def tick(self, controller):
        if not self.enabled:
            return
        if self.current is None:
            next_level = self.target
        else:
            if abs(self.current - self.target) < 0.01:
                return
            next_level = self.current + max(-STEP_PER_COMMAND, min(STEP_PER_COMMAND, self.target - self.current))
        next_level = max(MIN_LEVEL, min(MAX_LEVEL, next_level))
        print(f'FTMS VERZEND weerstand {next_level:.1f} (doel: {self.target:.1f}, versnelling {self.gear}/12)', flush=True)
        await controller.set_level(next_level)
        self.current = next_level
        print(f'FTMS BEVESTIGD weerstand {next_level:.1f} (Control Point succes; fysieke weerstand nog te beoordelen)', flush=True)

    def reset_local(self):
        self.current = None
        self.gear = self.initial_gear
        self.target = self.levels[self.gear - 1]
