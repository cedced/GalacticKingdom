class_name WorldLabels
extends Control
## Name tags for in-world objects (gate destinations, stations), drawn in
## the 2D HUD layer and projected each frame with Iso.world_to_screen.
## They used to be Label3Ds, but nothing in the 3D scene may sit above ship
## hover height — ships can never be hidden behind anything (rendering
## wiki), and that includes text.

const FONT_SIZE: int = 15
const MARGIN_PX: float = 80.0
const COLOR_TEXT: Color = Color(0.85, 0.92, 1.0, 0.9)
const COLOR_OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.85)

var _camera: Camera3D = null
## Each entry: {"text": String, "world": Vector2 (XZ plane), "clear": float}.
## "clear" is how many world units of screen height the tag floats above
## the anchor, so it sits just past the object's art at any zoom.
var _labels: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(camera: Camera3D) -> void:
	_camera = camera


func set_labels(labels: Array[Dictionary]) -> void:
	_labels = labels
	queue_redraw()


func _process(_delta: float) -> void:
	# The camera follows the ship, so screen positions move every frame.
	if _camera != null and not _labels.is_empty():
		queue_redraw()


func _draw() -> void:
	if _camera == null:
		return
	var font: Font = ThemeDB.fallback_font
	var viewport_size: Vector2 = get_viewport_rect().size
	for label: Dictionary in _labels:
		var world: Vector2 = label["world"]
		var screen: Vector2 = Iso.world_to_screen(
			Vector3(world.x, 0.0, world.y),
			_camera.global_transform, _camera.size, viewport_size
		)
		screen.y -= float(label["clear"]) * viewport_size.y / _camera.size + 6.0
		if (
			screen.x < -MARGIN_PX or screen.x > viewport_size.x + MARGIN_PX
			or screen.y < -MARGIN_PX or screen.y > viewport_size.y + MARGIN_PX
		):
			continue
		var text: String = label["text"]
		var width: float = font.get_string_size(
			text, HORIZONTAL_ALIGNMENT_CENTER, -1, FONT_SIZE
		).x
		var at: Vector2 = screen - Vector2(width * 0.5, 0.0)
		draw_string_outline(
			font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, COLOR_OUTLINE
		)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_TEXT)
