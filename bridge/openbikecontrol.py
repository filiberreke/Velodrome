"""OpenBikeControl v1 controller input over BLE."""
import asyncio

SERVICE_UUID = 'd273f680-d548-419d-b9d1-fa0472345229'
BUTTON_STATE_UUID = 'd273f681-d548-419d-b9d1-fa0472345229'
APP_INFO_UUID = 'd273f683-d548-419d-b9d1-fa0472345229'

SHIFT_BUTTONS = {0x01: 'SHIFT_UP_RIGHT', 0x02: 'SHIFT_DOWN_LEFT'}
NAVIGATION_BUTTONS = {0x10: 'UP', 0x11: 'DOWN', 0x12: 'LEFT', 0x13: 'RIGHT',
                      0x14: 'A', 0x15: 'B'}
# Message type, protocol version, length-prefixed app ID and version, button IDs.
APP_INFO = (b'\x04\x01\x09velodrome\x030.4'
            + bytes([len(SHIFT_BUTTONS) + len(NAVIGATION_BUTTONS)])
            + bytes(SHIFT_BUTTONS) + bytes(NAVIGATION_BUTTONS))


def is_openbikecontrol(advertisement):
    return any(str(uuid).lower() == SERVICE_UUID
               for uuid in (getattr(advertisement, 'service_uuids', None) or ()))


class ControllerInput:
    def __init__(self, send, shift):
        self.send = send
        self.shift = shift
        self.held = set()

    def receive(self, _characteristic, data):
        if not data or data[0] != 0x01 or len(data) % 2 == 0:
            return
        for button, state in zip(data[1::2], data[2::2]):
            if button not in SHIFT_BUTTONS and button not in NAVIGATION_BUTTONS:
                continue
            if state not in (0, 1) or bool(state) == (button in self.held):
                continue
            if state:
                self.held.add(button)
            else:
                self.held.remove(button)
            if button in SHIFT_BUTTONS:
                if state:
                    self.shift(SHIFT_BUTTONS[button])
            else:
                action = NAVIGATION_BUTTONS[button]
                self.send({'type': 'controller_button', 'source_button': action,
                           'mapped_action': action, 'pressed': bool(state)})

    def publish_connection(self):
        self.send({'type': 'controller_connection', 'connected': True,
                   'buttons': sorted(NAVIGATION_BUTTONS[button] for button in self.held
                                     if button in NAVIGATION_BUTTONS)})


async def connect(device, client_type, send, shift):
    # Each BLE session gets fresh button state. The role supervisor clears the
    # game's held state on disconnect, without synthesizing release actions.
    controller = ControllerInput(send, shift)
    async with client_type(device, timeout=18.0) as client:
        await client.start_notify(BUTTON_STATE_UUID, controller.receive)
        await client.write_gatt_char(APP_INFO_UUID, APP_INFO, response=True)
        controller.publish_connection()
        while client.is_connected:
            await asyncio.sleep(0.5)
            if client.is_connected:
                controller.publish_connection()
