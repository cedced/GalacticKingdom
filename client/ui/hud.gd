class_name Hud
extends Control
## Minimal M1 HUD: current system, warp fuel, gate hint, and transient
## status messages (server denials must be shown, wiki/systems/networking.md
## player-facing rules). Persistent status lives in a panel styled by the
## shared holo theme (wiki/systems/ui.md); transient lines float below it
## so the panel never resizes mid-flight.

const HOLO_THEME: Theme = preload("res://client/ui/holo_theme.tres")
const MESSAGE_SECONDS: float = 3.0

var _system_label: Label = null
var _fuel_bar: ProgressBar = null
var _fuel_label: Label = null
var _mode_label: Label = null
var _hint_label: Label = null
var _message_label: Label = null
var _message_until: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_status_panel()
	_mode_label = _floating_label(Vector2(16.0, 122.0), Color(0.95, 0.80, 0.35))
	_hint_label = _floating_label(Vector2(16.0, 150.0), Color(0.45, 0.90, 0.95))
	_message_label = _floating_label(Vector2(16.0, 178.0), Color(1.0, 0.55, 0.45))


func set_boarding(active: bool) -> void:
	_mode_label.text = "BOARDING MODE  (E to leave)" if active else ""


func set_system(system: StarSystem) -> void:
	_system_label.text = "%s  [%s, tier %d]" % [
		system.name, system.security, system.danger_tier,
	]


func set_fuel(fuel: float, cap: float) -> void:
	_fuel_bar.max_value = cap
	_fuel_bar.value = fuel
	_fuel_label.text = "%.1f / %.0f" % [fuel, cap]


## "" clears the hint.
func set_hint(text: String) -> void:
	_hint_label.text = text


func show_message(text: String) -> void:
	_message_label.text = text
	_message_until = Time.get_ticks_msec() / 1000.0 + MESSAGE_SECONDS


func _process(_delta: float) -> void:
	if _message_label.text != "" and Time.get_ticks_msec() / 1000.0 > _message_until:
		_message_label.text = ""


func _build_status_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme = HOLO_THEME
	panel.position = Vector2(12.0, 12.0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 8)
	panel.add_child(rows)
	_system_label = Label.new()
	_system_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	rows.add_child(_system_label)
	rows.add_child(_build_fuel_row())


func _build_fuel_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var caption: Label = Label.new()
	caption.text = "FUEL"
	caption.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75))
	row.add_child(caption)
	_fuel_bar = ProgressBar.new()
	_fuel_bar.custom_minimum_size = Vector2(150.0, 23.0)
	_fuel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fuel_bar.show_percentage = false
	_fuel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_fuel_bar)
	_fuel_label = Label.new()
	_fuel_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.75))
	row.add_child(_fuel_label)
	return row


func _floating_label(at: Vector2, color: Color) -> Label:
	var label: Label = Label.new()
	label.position = at
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	return label
