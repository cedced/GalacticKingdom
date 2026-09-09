class_name ShipView
extends Node3D
## Visual representation of one ship. Presentation only: sim positions are XZ
## Vector2s; the hover height here never feeds back into gameplay.

const HOVER_HEIGHT: float = 0.5

var _blend_rate: float = 0.0
var _target_position: Vector3 = Vector3.ZERO
var _target_heading: float = 0.0


func _ready() -> void:
	position.y = HOVER_HEIGHT
	_blend_rate = Tuning.value_f("net.view_blend_rate")


func _process(delta: float) -> void:
	# Framerate-independent exponential blend toward the latest network state.
	var weight: float = 1.0 - exp(-_blend_rate * delta)
	position = position.lerp(_target_position, weight)
	rotation.y = lerp_angle(rotation.y, _target_heading, weight)


func set_target(sim_position: Vector2, heading: float) -> void:
	_target_position = Vector3(sim_position.x, HOVER_HEIGHT, sim_position.y)
	_target_heading = heading


func set_immediate(sim_position: Vector2, heading: float) -> void:
	set_target(sim_position, heading)
	position = _target_position
	rotation.y = heading
