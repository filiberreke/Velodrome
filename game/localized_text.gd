extends Node
## Keeps composed Control text current when the player changes language.
var property: StringName
var compose: Callable

static func bind(control: Control, target_property: StringName, formatter: Callable) -> void:
	var binding := new()
	binding.property = target_property
	binding.compose = formatter
	control.add_child(binding, false, Node.INTERNAL_MODE_BACK)

func _ready() -> void:
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()

func _refresh() -> void:
	get_parent().set(property, compose.call())
