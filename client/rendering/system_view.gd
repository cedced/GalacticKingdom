class_name SystemView
extends Node3D
## Builds the visible contents of the current star system from generated
## data: star, bodies, stations, warp gates. Everything is a procedural 3D
## primitive until the art direction lands (wiki/systems/rendering.md);
## presentation only, heights never touch the sim (CLAUDE.md Section 4).

const STAR_COLORS: Dictionary[String, Color] = {
	"yellow": Color(1.0, 0.84, 0.37),
	"orange": Color(1.0, 0.62, 0.26),
	"red_dwarf": Color(1.0, 0.42, 0.31),
	"white": Color(0.95, 0.95, 1.0),
	"blue_giant": Color(0.53, 0.71, 1.0),
	"red_giant": Color(1.0, 0.29, 0.23),
}
const BIOME_COLORS: Dictionary[String, Color] = {
	"rocky": Color(0.54, 0.50, 0.45),
	"desert": Color(0.85, 0.70, 0.42),
	"arctic": Color(0.81, 0.91, 0.96),
	"volcanic": Color(0.84, 0.29, 0.16),
	"oceanic": Color(0.16, 0.44, 0.84),
	"mountainous": Color(0.48, 0.54, 0.60),
	"greenhouse": Color(0.48, 0.82, 0.48),
	"earthlike": Color(0.27, 0.71, 0.43),
	"gas_giant": Color(0.79, 0.64, 0.88),
	"tiny": Color(0.60, 0.60, 0.60),
}
const COLOR_ASTEROIDS: Color = Color(0.42, 0.38, 0.34)
const COLOR_DERELICT: Color = Color(0.35, 0.40, 0.38)
const COLOR_PORT: Color = Color(0.45, 0.62, 0.85)
const COLOR_STARBASE: Color = Color(0.95, 0.78, 0.30)
const COLOR_GATE: Color = Color(0.45, 0.90, 0.95)


func rebuild(system: StarSystem) -> void:
	for child: Node in get_children():
		child.queue_free()
	_add_star(system.star_type)
	for body: SystemBody in system.bodies:
		_add_body(body)
	for station: SystemStation in system.stations:
		_add_station(station)
	for gate: WarpGate in system.gates:
		_add_gate(gate)


func _add_star(star_type: String) -> void:
	var color: Color = STAR_COLORS.get(star_type, Color.WHITE)
	var star: MeshInstance3D = _sphere(4.0, color, true)
	star.position = Vector3(0.0, 0.0, 0.0)
	add_child(star)


func _add_body(body: SystemBody) -> void:
	var pos: Vector2 = body.position()
	var mesh: MeshInstance3D = null
	if body.kind == "planet":
		mesh = _sphere(body.size, BIOME_COLORS.get(body.biome, Color.GRAY), false)
	elif body.kind == "asteroids":
		# A flattened lump reads as a field from the iso camera until real
		# scattered rocks arrive with the art pass.
		mesh = _sphere(body.size, COLOR_ASTEROIDS, false)
		mesh.scale = Vector3(1.6, 0.3, 1.6)
	else:
		mesh = _box(Vector3(body.size, body.size * 0.5, body.size * 2.0), COLOR_DERELICT, false)
	mesh.position = Vector3(pos.x, body.size, pos.y)
	add_child(mesh)


func _add_station(station: SystemStation) -> void:
	var is_starbase: bool = station.kind == "starbase"
	var side: float = 3.0 if is_starbase else 2.0
	var color: Color = COLOR_STARBASE if is_starbase else COLOR_PORT
	var mesh: MeshInstance3D = _box(Vector3(side, side, side), color, true)
	mesh.position = Vector3(station.position.x, side * 0.75, station.position.y)
	mesh.rotation.y = 0.25 * PI
	add_child(mesh)
	_add_label(str(station.kind), mesh.position + Vector3(0.0, side, 0.0))


func _add_gate(gate: WarpGate) -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 1.2
	torus.outer_radius = 1.8
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = torus
	mesh.material_override = _material(COLOR_GATE, true)
	mesh.position = Vector3(gate.position.x, 1.8, gate.position.y)
	# Stand the ring upright, facing back at the system center.
	mesh.rotation = Vector3(0.5 * PI, atan2(-gate.position.x, -gate.position.y), 0.0)
	add_child(mesh)


## Gate labels are set by the caller (destination names live in the galaxy,
## not the gate).
func label_gate(gate: WarpGate, text: String) -> void:
	_add_label(text, Vector3(gate.position.x, 4.5, gate.position.y))


func _sphere(radius: float, color: Color, emissive: bool) -> MeshInstance3D:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = sphere
	mesh.material_override = _material(color, emissive)
	return mesh


func _box(size: Vector3, color: Color, emissive: bool) -> MeshInstance3D:
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = _material(color, emissive)
	return mesh


func _material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.2
	return material


func _add_label(text: String, at: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.02
	label.modulate = Color(0.9, 0.95, 1.0, 0.9)
	label.position = at
	add_child(label)
