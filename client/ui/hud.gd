class_name Hud
extends CanvasLayer
## In-flight ship status HUD. First consumer of the holo UI theme
## (client/ui/holo_theme.tres, wiki/systems/ui.md). Pure presentation:
## everything shown comes from ClientMain, nothing is computed here.

signal halt_pressed
signal grid_toggled(grid_visible: bool)

@onready var _hull_label: Label = %HullLabel
@onready var _status_label: Label = %StatusLabel
@onready var _position_label: Label = %PositionLabel
@onready var _speed_bar: ProgressBar = %SpeedBar
@onready var _halt_button: Button = %HaltButton
@onready var _grid_checkbox: CheckBox = %GridCheckBox


func _ready() -> void:
	_halt_button.disabled = true
	_halt_button.pressed.connect(_on_halt_pressed)
	_grid_checkbox.toggled.connect(_on_grid_toggled)


func set_hull_name(hull_name: String) -> void:
	_hull_label.text = hull_name.to_upper()


func set_status(status: String) -> void:
	_status_label.text = status.to_upper()


func set_kinematics(ship_position: Vector2, speed: float, max_speed: float) -> void:
	_position_label.text = "POS %+07.1f %+07.1f" % [ship_position.x, ship_position.y]
	_speed_bar.max_value = max_speed
	_speed_bar.value = speed


## The halt button is only pressable while the go-to autopilot is steering.
func set_autopilot_active(active: bool) -> void:
	_halt_button.disabled = not active


func _on_halt_pressed() -> void:
	halt_pressed.emit()


func _on_grid_toggled(toggled_on: bool) -> void:
	grid_toggled.emit(toggled_on)
