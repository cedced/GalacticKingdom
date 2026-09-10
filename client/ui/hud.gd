class_name Hud
extends Control
## Minimal M1 HUD: current system, warp fuel, gate hint, and transient
## status messages (server denials must be shown, wiki/systems/networking.md
## player-facing rules).

const MESSAGE_SECONDS: float = 3.0

var _system_label: Label = null
var _fuel_label: Label = null
var _mode_label: Label = null
var _hint_label: Label = null
var _message_label: Label = null
var _message_until: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_system_label = _label(Vector2(16.0, 12.0), Color(0.85, 0.92, 1.0))
	_fuel_label = _label(Vector2(16.0, 36.0), Color(0.55, 0.95, 0.75))
	_mode_label = _label(Vector2(16.0, 60.0), Color(0.95, 0.80, 0.35))
	_hint_label = _label(Vector2(16.0, 88.0), Color(0.45, 0.90, 0.95))
	_message_label = _label(Vector2(16.0, 116.0), Color(1.0, 0.55, 0.45))
	_mode_label.text = ""
	_hint_label.text = ""
	_message_label.text = ""


func set_boarding(active: bool) -> void:
	_mode_label.text = "BOARDING MODE  (E to leave)" if active else ""


func set_system(system: StarSystem) -> void:
	_system_label.text = "%s  [%s, tier %d]" % [
		system.name, system.security, system.danger_tier,
	]


func set_fuel(fuel: float, cap: float) -> void:
	_fuel_label.text = "Warp fuel %.1f / %.0f" % [fuel, cap]


## "" clears the hint.
func set_hint(text: String) -> void:
	_hint_label.text = text


func show_message(text: String) -> void:
	_message_label.text = text
	_message_until = Time.get_ticks_msec() / 1000.0 + MESSAGE_SECONDS


func _process(_delta: float) -> void:
	if _message_label.text != "" and Time.get_ticks_msec() / 1000.0 > _message_until:
		_message_label.text = ""


func _label(at: Vector2, color: Color) -> Label:
	var label: Label = Label.new()
	label.position = at
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label
