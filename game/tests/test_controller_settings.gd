extends SceneTree
class Model extends "res://main.gd":
    func _bind_bridge(_port: int = UDP_PORT) -> Error:
        return super._bind_bridge(0)

var failures := 0
func check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error(message)

func _initialize() -> void:
    call_deferred("run_test")

func run_test() -> void:
    var game := Model.new()
    root.add_child(game)
    game.set_physics_process(false)
    await process_frame
    await process_frame
    var settings: CanvasLayer = game.get_node("GameSettings")
    settings.toggle_menu()
    var tabs: TabContainer = settings.appearance_tabs
    var controller: Control = settings.controller_test
    tabs.current_tab = controller.get_index()
    await process_frame
    check(settings.controller_test_active(), "Controller tab enters test mode")
    var old_state: String = game.start_state
    game._process_bridge_packet({"type": "controller_button", "source_button": "B", "pressed": true})
    check(controller.pressed_buttons.has("B"), "Button press lights physical button")
    game._process_bridge_packet({"type": "button", "button": "A", "source_button": "A"})
    check(game.start_state == old_state, "Mapped A action is blocked in controller test")
    game._process_bridge_packet({"type": "steering", "value": 60})
    check(controller.steering_bar.value == 60, "Analog steering is displayed")
    game._process_bridge_packet({"type": "controller_button", "source_button": "B", "pressed": false})
    check(not controller.pressed_buttons.has("B"), "Release clears the indicator")
    game._process_bridge_packet({"type": "controller_button", "source_button": "Y", "pressed": true, "mapped_action": ""})
    check(controller.pressed_buttons.has("Y"), "Unmapped buttons are visible")
    game._process_bridge_packet({"type": "controller_connection", "connected": false})
    check(controller.pressed_buttons.is_empty(), "Disconnect clears held buttons")
    settings.toggle_menu()
    check(not settings.controller_test_active(), "Closing settings disables test mode")
    game.queue_free()
    await process_frame
    print("CONTROLLER_SETTINGS_OK" if failures == 0 else "CONTROLLER_SETTINGS_FAILED: %d" % failures)
    quit(0 if failures == 0 else 1)
