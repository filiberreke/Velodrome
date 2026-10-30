"""Convert the two Ride analog paddles to an independent signed steering axis."""


class SteeringState:
    def __init__(self):
        self.paddles = {0: 0, 1: 0}
        self.value = 0

    def update(self, paddles):
        if not paddles:
            return None
        self.paddles.update(paddles)
        # Left outward is negative, right outward positive. Inward pressure
        # is braking and must not be interpreted as opposite-side steering.
        left = max(0, -self.paddles[0])
        right = max(0, self.paddles[1])
        self.value = right - left
        return {'type': 'steering', 'value': self.value}
