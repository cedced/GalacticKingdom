class_name SystemView
extends Node3D
## Builds the visible contents of the current star system from generated
## data: star, bodies, stations, warp gates, and a backdrop crop of the
## galaxy master image. Suns and planets draw as animated billboards from
## data/bodies/ (assets/README.md Bodies pipeline) and fall back to
## procedural primitives for anything without a sprite; stations and gates
## stay primitives until the art direction lands (wiki/systems/rendering.md).
## Presentation only, heights never touch the sim (CLAUDE.md Section 4).

const BODY_SHADER: Shader = preload("res://client/rendering/body_billboard.gdshader")
const BACKDROP_SHADER: Shader = preload("res://client/rendering/backdrop.gdshader")
## Just past what the camera can see at max zoom-out around the gate ring.
const BACKDROP_SIZE: float = 240.0
## The procedural nebula haze leans this much toward the system's star
## color, so skies vary with the star overhead.
const BACKDROP_STAR_TINT: float = 0.35
## Sprite canvases keep a transparent margin around the ball, so the quad
## is larger than the sphere it replaces.
const PLANET_QUAD_PER_SIZE: float = 3.0
const SUN_QUAD_SIZE: float = 13.0

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
	_add_backdrop(system)
	_add_star(system.star_type)
	for body: SystemBody in system.bodies:
		_add_body(body)
	for station: SystemStation in system.stations:
		_add_station(station)
	for gate: WarpGate in system.gates:
		_add_gate(gate)


func _add_backdrop(system: StarSystem) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(BACKDROP_SIZE, BACKDROP_SIZE)
	var star_color: Color = STAR_COLORS.get(system.star_type, Color.WHITE)
	var haze: Color = Color(0.10, 0.14, 0.25).lerp(star_color, BACKDROP_STAR_TINT)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = BACKDROP_SHADER
	material.set_shader_parameter("nebula_color", haze)
	# Map position as seed: unique sky per system, same sky every visit.
	material.set_shader_parameter("star_seed", system.position)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = material
	mesh.position = Vector3(0.0, -0.5, 0.0)
	add_child(mesh)


func _add_star(star_type: String) -> void:
	var def: BodySpriteDef = BodyCatalog.for_star_type(star_type)
	var color: Color = STAR_COLORS.get(star_type, Color.WHITE)
	if def == null:
		var star: MeshInstance3D = _sphere(4.0, color, true)
		star.position = Vector3(0.0, 0.0, 0.0)
		add_child(star)
		return
	# The quad grows with corona_spread; the ball inside it does not, so it
	# keeps matching collision.sun_radius.
	var quad: float = SUN_QUAD_SIZE * def.corona_spread
	var sprite: MeshInstance3D = _billboard(def, color, quad)
	# High enough that the camera-tilted quad never dips under the backdrop
	# plane, which would depth-clip the corona to a straight edge.
	sprite.position = Vector3(0.0, quad * 0.45, 0.0)
	add_child(sprite)


func _add_body(body: SystemBody) -> void:
	var pos: Vector2 = body.position()
	if body.kind == "planet":
		var def: BodySpriteDef = BodyCatalog.for_biome(body.biome)
		var color: Color = BIOME_COLORS.get(body.biome, Color.GRAY)
		if def != null:
			var quad: float = body.size * PLANET_QUAD_PER_SIZE
			var sprite: MeshInstance3D = _billboard(def, color, quad)
			# Same backdrop-clearance rule as the sun.
			sprite.position = Vector3(pos.x, maxf(body.size + 0.6, quad * 0.45), pos.y)
			add_child(sprite)
			return
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
	var mesh: MeshInstance3D = _box(Vector3(side, side, side), color, false)
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


func _billboard(def: BodySpriteDef, tint: Color, quad_size: float) -> MeshInstance3D:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(quad_size, quad_size)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter("sheet", def.texture)
	material.set_shader_parameter("frames", def.frames)
	material.set_shader_parameter("fps", def.fps)
	material.set_shader_parameter("spin_speed", def.spin_speed)
	material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	material.set_shader_parameter("tint_mix", def.tint_mix)
	material.set_shader_parameter("corona", def.corona)
	material.set_shader_parameter("corona_spread", def.corona_spread)
	material.set_shader_parameter("pulse", def.pulse)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material
	return mesh


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
	label.pixel_size = 0.011
	label.modulate = Color(0.9, 0.95, 1.0, 0.9)
	label.position = at
	add_child(label)
