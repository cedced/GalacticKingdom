class_name GalaxyMap
extends Control
## Full-screen galaxy map (M to toggle). Shows every system and lane, the
## current system, and a fewest-jumps route to a clicked target with its
## fuel bill. Pure presentation over GalaxyData; the sim owns the pathing.

const COLOR_BG: Color = Color(0.01, 0.01, 0.04, 0.92)
const COLOR_LANE: Color = Color(0.25, 0.25, 0.35)
const COLOR_SAFE: Color = Color(0.3, 0.9, 0.4)
const COLOR_STARBASE: Color = Color(0.3, 0.8, 1.0)
const COLOR_CURRENT: Color = Color(1.0, 1.0, 1.0)
const COLOR_ROUTE: Color = Color(0.5, 0.95, 1.0)
const COLOR_TEXT: Color = Color(0.85, 0.92, 1.0)
const CLICK_RADIUS_PX: float = 14.0

var _galaxy: GalaxyData = null
var _current_system_id: int = -1
var _selected_system_id: int = -1
var _route: Array[int] = []
var _fuel: float = 0.0
var _jump_cost: float = 0.0
var _map_radius: float = 1.0


func setup(galaxy: GalaxyData) -> void:
	_galaxy = galaxy
	_map_radius = 1.0
	for system: StarSystem in galaxy.systems:
		_map_radius = maxf(_map_radius, system.position.length())
	queue_redraw()


func set_current(system_id: int) -> void:
	_current_system_id = system_id
	if _selected_system_id == system_id:
		_selected_system_id = -1
	_replot()


func set_fuel_info(fuel: float, jump_cost: float) -> void:
	_fuel = fuel
	_jump_cost = jump_cost
	queue_redraw()


## The plotted route's next system id, or -1 when no route is plotted.
func next_hop() -> int:
	return _route[1] if _route.size() > 1 else -1


func _replot() -> void:
	_route = []
	if _galaxy != null and _selected_system_id >= 0 and _current_system_id >= 0:
		_route = _galaxy.shortest_path(_current_system_id, _selected_system_id)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = event
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT or _galaxy == null:
		return
	var best_id: int = -1
	var best_dist: float = CLICK_RADIUS_PX
	for system: StarSystem in _galaxy.systems:
		var dist: float = _to_px(system.position).distance_to(mouse.position)
		if dist < best_dist:
			best_dist = dist
			best_id = system.id
	if best_id >= 0:
		_selected_system_id = -1 if best_id == _selected_system_id else best_id
		_replot()
	accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	if _galaxy == null:
		return
	for lane: WarpLane in _galaxy.lanes:
		draw_line(
			_to_px(_galaxy.system(lane.a).position),
			_to_px(_galaxy.system(lane.b).position),
			COLOR_LANE, 1.0
		)
	_draw_route()
	for system: StarSystem in _galaxy.systems:
		draw_circle(_to_px(system.position), 3.0, _system_color(system))
	_draw_markers()
	_draw_header()


func _draw_route() -> void:
	if _route.size() < 2:
		return
	for i: int in _route.size() - 1:
		draw_line(
			_to_px(_galaxy.system(_route[i]).position),
			_to_px(_galaxy.system(_route[i + 1]).position),
			COLOR_ROUTE, 3.0
		)


func _draw_markers() -> void:
	var font: Font = ThemeDB.fallback_font
	if _current_system_id >= 0:
		var current: StarSystem = _galaxy.system(_current_system_id)
		draw_arc(_to_px(current.position), 7.0, 0.0, TAU, 24, COLOR_CURRENT, 2.0)
		draw_string(
			font, _to_px(current.position) + Vector2(10.0, 4.0), current.name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_CURRENT
		)
	if _selected_system_id >= 0:
		var selected: StarSystem = _galaxy.system(_selected_system_id)
		draw_arc(_to_px(selected.position), 7.0, 0.0, TAU, 24, COLOR_ROUTE, 2.0)
		draw_string(
			font, _to_px(selected.position) + Vector2(10.0, 4.0), selected.name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_ROUTE
		)


func _draw_header() -> void:
	var font: Font = ThemeDB.fallback_font
	var line: String = "Galaxy map — click a system to plot a route, M to close"
	if _route.size() > 1:
		var jumps: int = _route.size() - 1
		var cost: float = float(jumps) * _jump_cost
		var verdict: String = "" if cost <= _fuel else "  (not enough fuel!)"
		line = "Route to %s: %d jump%s, %.0f fuel of %.1f%s — next hop: %s" % [
			_galaxy.system(_selected_system_id).name, jumps, "s" if jumps > 1 else "",
			cost, _fuel, verdict, _galaxy.system(next_hop()).name,
		]
	elif _route.size() == 1:
		line = "You are already there."
	draw_string(font, Vector2(16.0, 24.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COLOR_TEXT)


func _system_color(system: StarSystem) -> Color:
	if system.has_station("starbase"):
		return COLOR_STARBASE
	if system.security == "safe":
		return COLOR_SAFE
	return Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.15, 0.1), minf(system.danger_tier / 8.0, 1.0))


func _to_px(map_pos: Vector2) -> Vector2:
	var scale_px: float = (minf(size.x, size.y) * 0.5 - 50.0) / _map_radius
	return size * 0.5 + map_pos * scale_px
