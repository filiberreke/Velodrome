extends VBoxContainer
signal back_requested
signal environment_requested(active: bool)
const Session := preload("res://derny_session.gd")
var session := Session.new()
var scene: Node3D
var title: Label
var detail: Label
var result: Label
var start_button: Button
var stop_button: Button
var back_button: Button
func _ready() -> void:
	add_theme_constant_override("separation", 14)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	title = _label("Dernytraining", 34)
	detail = _label("Volg de derny tijdens één aanloopronde. Daarna 30 km/u, elke minuut +1 km/u.\nBlijf in zijn wiel voor sterke beschutting. Naast of vóór de derny vang je de volle wind.\nMeer dan 15 meter achterstand gedurende 5 seconden beëindigt de training.\nStuur links/rechts om uit het wiel te komen of in te halen.", 22)
	result = _label("", 24)
	start_button = _button("Start dernytraining", begin)
	stop_button = _button("Stop training", func(): finish("Handmatig gestopt"))
	back_button = _button("← Pistetraining", leave)
	_refresh()
func _label(text: String, font_size: int) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	add_child(node)
	return node
func _button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 48
	node.pressed.connect(action)
	add_child(node)
	return node
func begin() -> void:
	if session.running(): return
	environment_requested.emit(true)
	if session.running(): stop_button.grab_focus()
func finish(reason: String) -> void:
	session.stop(reason)
	if is_instance_valid(scene): scene.release_trainer()
	_refresh()
func leave() -> void:
	finish("Training verlaten")
	environment_requested.emit(false)
	back_requested.emit()
func _process(_dt: float) -> void: _refresh()
func _refresh() -> void:
	if start_button == null: return
	var running := session.running()
	start_button.visible = not running
	stop_button.visible = running
	detail.visible = not running and session.phase != "RESULT"
	if running and is_instance_valid(scene):
		var phase := "Aanloopronde · nog %.0f m" % maxf(0, 250 - session.runup_distance) if session.phase == "RUNUP" else "Volgende stap over %d s" % int(ceil(60 - fmod(session.elapsed, 60)))
		result.text = "%s\nDerny %.0f km/u · jij %.1f km/u\nAfstand %.1f m · beschutting %d%%" % [phase, session.target_kmh, scene.player_speed * 3.6, scene.gap(), roundi(scene.reduction * 100)]
		if session.loss_seconds > 0: result.text += "\nSluit aan! Nog %.1f s" % maxf(0, 5 - session.loss_seconds)
		if scene.demo: result.text += "\nPC-proefrit · ↑/↓ vermogen · ←/→ sturen"
		elif scene.game.trainer_control.phase == "ACTIVE" and not scene.game.trainer_control.aero_supported: result.text += "\nTrainer ondersteunt geen aangepaste luchtweerstand."
	elif session.phase == "RESULT":
		result.text = "%s\nHoogste voltooide stap: %s\nVolgtijd: %d:%02d" % [session.reason, "%d km/u" % session.completed_kmh if session.completed_kmh > 0 else "nog geen volledige minuut", int(session.elapsed) / 60, int(session.elapsed) % 60]
	else: result.text = "Een vaste pistesessie, zonder import/export. Zonder trainer kun je een PC-proefrit maken."
