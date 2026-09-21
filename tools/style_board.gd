extends SceneTree
## Style-round comparison board (assets/ART_WORKFLOW.md step 1): lays every
## PNG from a folder side by side as in-game ground decals, with the real
## backdrop shader and the starter ship for scale, and saves a screenshot.
## Needs a window (rendering):
##   godot --path . -s tools/style_board.gd -- --dir=<folder> --out=board.png
## Candidates are placed left to right in filename order.

const SETTLE_FRAMES: int = 30
const QUAD_SIZE: float = 9.0
const SPACING: float = 12.0

var _frames_left: int = SETTLE_FRAMES
var _out_path: String = "style_board.png"


func _init() -> void:
	if not Tuning.load_data():
		print("style_board: tuning failed to load")
		quit(1)
		return
	var dir_path: String = _arg("dir", "assets/dump")
	_out_path = _arg("out", "style_board.png")
	var candidates: Array[String] = _list_pngs(dir_path)
	if candidates.is_empty():
		print("style_board: no .png files in %s" % dir_path)
		quit(1)
		return
	var world: Node3D = Node3D.new()
	root.add_child.call_deferred(world)
	_build_scene.call_deferred(world, candidates)
	process_frame.connect(_on_frame)


func _build_scene(world: Node3D, candidates: Array[String]) -> void:
	var row_width: float = SPACING * float(candidates.size() - 1)
	_add_camera(world, row_width)
	_add_light(world)
	_add_backdrop(world)
	# Lay the row along the camera's screen-horizontal ground axis so the
	# board reads as one straight line.
	var yaw: float = deg_to_rad(Tuning.value_f("render.yaw_deg"))
	var screen_right: Vector2 = Vector2(cos(yaw), -sin(yaw))
	for i: int in candidates.size():
		var offset: float = -row_width * 0.5 + SPACING * float(i)
		_add_candidate(world, candidates[i], screen_right * offset)
		print("style_board: slot %d (left to right) = %s" % [i + 1, candidates[i]])
	_add_ship(world, Vector3(0.0, 0.5, 8.0))


func _on_frame() -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	process_frame.disconnect(_on_frame)
	var image: Image = root.get_texture().get_image()
	image.save_png(_out_path)
	print("style_board: saved %s" % _out_path)
	quit(0)


func _add_camera(world: Node3D, row_width: float) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.transform.basis = Iso.camera_basis(
		Tuning.value_f("render.pitch_deg"), Tuning.value_f("render.yaw_deg")
	)
	camera.position = camera.transform.basis * Vector3(0.0, 0.0, 60.0)
	camera.size = maxf(18.0, row_width * 0.75)
	world.add_child(camera)
	camera.make_current()


func _add_light(world: Node3D) -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	world.add_child(light)


func _add_backdrop(world: Node3D) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(240.0, 240.0)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://client/rendering/backdrop.gdshader")
	material.set_shader_parameter("star_seed", Vector2(120.0, -80.0))
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = material
	mesh.position = Vector3(0.0, -0.5, 0.0)
	world.add_child(mesh)


## Same flat-decal placement the game uses (SystemView._sprite_quad),
## minus the data plumbing: candidates are loose files, not assets.
func _add_candidate(world: Node3D, path: String, at: Vector2) -> void:
	var image: Image = Image.load_from_file(path)
	if image == null:
		print("style_board: failed to load %s" % path)
		return
	var quad: QuadMesh = QuadMesh.new()
	var pitch: float = deg_to_rad(Tuning.value_f("render.pitch_deg"))
	quad.size = Vector2(QUAD_SIZE, QUAD_SIZE / sin(pitch))
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://client/rendering/body_billboard.gdshader")
	material.set_shader_parameter("billboard_enabled", false)
	material.set_shader_parameter("sheet", ImageTexture.create_from_image(image))
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	mesh.rotation = Vector3(
		-0.5 * PI, deg_to_rad(Tuning.value_f("render.yaw_deg")), 0.0
	)
	mesh.position = Vector3(at.x, 0.1, at.y)
	world.add_child(mesh)


func _add_ship(world: Node3D, at: Vector3) -> void:
	var hull: HullDef = Entities.load_hull(str(Tuning.value("world.starter_hull_id")))
	if hull == null:
		return
	var scene: PackedScene = load(hull.model)
	if scene == null:
		return
	var ship: Node3D = scene.instantiate()
	ship.position = at
	world.add_child(ship)


func _list_pngs(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	for file: String in DirAccess.get_files_at(dir_path):
		if file.to_lower().ends_with(".png"):
			out.append(dir_path.path_join(file))
	out.sort()
	return out


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback
