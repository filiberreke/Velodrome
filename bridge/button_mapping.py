"""Configurable Zwift Ride button -> existing Godot actions.

No keyboard emulation: this bridge emits localhost UDP packets.
"""
import json
from pathlib import Path

DEFAULT_MAPPING = {
    "SHIFT_UP_LEFT": "LEFT",
    "SHIFT_DOWN_LEFT": "LEFT",
    "SHIFT_UP_RIGHT": "RIGHT",
    "SHIFT_DOWN_RIGHT": "RIGHT",
    "LEFT": "LEFT",
    "RIGHT": "RIGHT",
    "UP": "UP",
    "DOWN": "DOWN",
    "A": "A",
    "B": "B",
    "Y": "Y",
}
ALLOWED_ACTIONS = {"LEFT", "RIGHT", "UP", "DOWN", "A", "B", "Y", ""}


class ButtonMapper:
    def __init__(self, mapping):
        self.mapping = mapping

    @classmethod
    def load(cls, path=None):
        path = Path(path) if path else Path(__file__).with_name("button_mapping.json")
        if not path.exists():
            raise FileNotFoundError(f"Mappingbestand ontbreekt: {path}")
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            raise ValueError("button_mapping.json moet een JSON-object zijn")
        unknown = set(data.values()) - ALLOWED_ACTIONS
        if unknown:
            raise ValueError(f"Onbekende Godot-acties: {sorted(unknown)}")
        return cls(data)

    def map_button(self, button):
        return self.mapping.get(button, "")

    def packet(self, button):
        action = self.map_button(button)
        if not action:
            return None
        return {"type": "button", "button": action, "source_button": button}
