class_name IsoCamera
extends Camera3D
## Fixed-angle orthographic camera (CLAUDE.md Section 4). Never rotates in
## gameplay; zoom changes size only; follows a target on the XZ plane.

var _zoom_levels: Array = []
var _zoom_index: int = 0
var _offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	var pitch: float = Tuning.value_f("render.pitch_deg")
	var yaw: float = Tuning.value_f("render.yaw_deg")
	transform.basis = Iso.camera_basis(pitch, yaw)
	_offset = transform.basis * Vector3(0.0, 0.0, Tuning.value_f("render.camera_distance"))
	_zoom_levels = Tuning.value("render.zoom_levels")
	_zoom_index = Tuning.value_i("render.default_zoom_index")
	_apply_zoom()
	set_target(Vector3.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		_zoom_index = maxi(_zoom_index - 1, 0)
		_apply_zoom()
	elif event.is_action_pressed("zoom_out"):
		_zoom_index = mini(_zoom_index + 1, _zoom_levels.size() - 1)
		_apply_zoom()


func set_target(world_point: Vector3) -> void:
	position = world_point + _offset


func _apply_zoom() -> void:
	size = float(_zoom_levels[_zoom_index])
