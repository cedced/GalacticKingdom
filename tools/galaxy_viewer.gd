extends SceneTree
## Renders a generated galaxy to a PNG for eyeballing seeds (CLAUDE.md
## Section 8: generation changes get checked in the seed viewer).
##
##   godot --headless --path . -s tools/galaxy_viewer.gd -- --seed=12345 --out=galaxy.png
##
## Params come from data/tuning.json, same as the server.

const IMAGE_SIZE: int = 1024
const MARGIN: float = 40.0

const COLOR_BG: Color = Color(0.02, 0.02, 0.05)
const COLOR_LANE: Color = Color(0.25, 0.25, 0.35)
const COLOR_HOME: Color = Color(1.0, 1.0, 1.0)
const COLOR_SAFE: Color = Color(0.3, 0.9, 0.4)
const COLOR_STARBASE: Color = Color(0.3, 0.8, 1.0)

var _scale: float = 1.0


func _init() -> void:
	var seed_value: int = int(_arg("seed", "12345"))
	var out_path: String = _arg("out", "galaxy.png")
	if not Tuning.load_data():
		print("galaxy_viewer: failed to load tuning")
		quit(1)
		return
	var params: GalaxyParams = GalaxyParams.from_tuning()
	var galaxy: GalaxyData = Galaxy.generate(seed_value, params)
	_scale = (float(IMAGE_SIZE) / 2.0 - MARGIN) / params.radius
	var image: Image = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGB8)
	image.fill(COLOR_BG)
	for lane: WarpLane in galaxy.lanes:
		_line(image, galaxy.system(lane.a).position, galaxy.system(lane.b).position)
	for system: StarSystem in galaxy.systems:
		_disc(image, system.position, 2, _system_color(galaxy, system))
	_disc(image, galaxy.system(galaxy.home_system_id).position, 4, COLOR_HOME)
	image.save_png(out_path)
	print("galaxy_viewer: seed=%d systems=%d lanes=%d hash=%s -> %s" % [
		seed_value, galaxy.systems.size(), galaxy.lanes.size(),
		galaxy.content_hash().substr(0, 12), out_path,
	])
	quit(0)


func _system_color(galaxy: GalaxyData, system: StarSystem) -> Color:
	if system.has_station("starbase"):
		return COLOR_STARBASE
	if system.security == "safe":
		return COLOR_SAFE
	# Lawless shades yellow -> red with danger.
	return Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.15, 0.1), minf(system.danger_tier / 8.0, 1.0))


func _to_px(map_pos: Vector2) -> Vector2i:
	var center: float = float(IMAGE_SIZE) / 2.0
	return Vector2i(int(center + map_pos.x * _scale), int(center + map_pos.y * _scale))


func _line(image: Image, from_map: Vector2, to_map: Vector2) -> void:
	var from_px: Vector2i = _to_px(from_map)
	var to_px: Vector2i = _to_px(to_map)
	var steps: int = maxi(absi(to_px.x - from_px.x), absi(to_px.y - from_px.y))
	for i: int in steps + 1:
		var t: float = float(i) / float(maxi(steps, 1))
		var p: Vector2 = Vector2(from_px).lerp(Vector2(to_px), t)
		_put(image, int(p.x), int(p.y), COLOR_LANE)


func _disc(image: Image, map_pos: Vector2, radius: int, color: Color) -> void:
	var center: Vector2i = _to_px(map_pos)
	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				_put(image, center.x + dx, center.y + dy, color)


func _put(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < IMAGE_SIZE and y >= 0 and y < IMAGE_SIZE:
		image.set_pixel(x, y, color)


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback
