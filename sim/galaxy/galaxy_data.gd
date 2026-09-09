class_name GalaxyData
extends RefCounted
## A complete generated galaxy. Deterministic for a seed, so the server and
## every client regenerate an identical copy from the seed alone and only
## mutable state ever crosses the wire.

## Bump when generation output changes on purpose; golden hashes include it
## so a stale golden fails loudly instead of mysteriously.
const GENERATION_VERSION: int = 1

var seed: int = 0
## Indexed by system id: systems[i].id == i always holds.
var systems: Array[StarSystem] = []
var lanes: Array[WarpLane] = []
var home_system_id: int = 0

var _adjacency: Dictionary[int, Array] = {}


func system(system_id: int) -> StarSystem:
	if system_id < 0 or system_id >= systems.size():
		return null
	return systems[system_id]


func neighbors(system_id: int) -> Array[int]:
	_build_adjacency()
	var out: Array[int] = []
	out.assign(_adjacency.get(system_id, []))
	return out


## Fewest-jumps route including both endpoints; empty when unreachable.
## Jumps cost flat fuel, so hop count is the thing to minimize.
func shortest_path(from_id: int, to_id: int) -> Array[int]:
	if system(from_id) == null or system(to_id) == null:
		return []
	if from_id == to_id:
		return [from_id]
	_build_adjacency()
	var came_from: Dictionary[int, int] = {from_id: from_id}
	var frontier: Array[int] = [from_id]
	while not frontier.is_empty():
		var next_frontier: Array[int] = []
		for current: int in frontier:
			for neighbor: int in _adjacency.get(current, []):
				if came_from.has(neighbor):
					continue
				came_from[neighbor] = current
				if neighbor == to_id:
					return _walk_back(came_from, from_id, to_id)
				next_frontier.append(neighbor)
		frontier = next_frontier
	return []


## Canonical text form, floats rounded so the golden hash survives
## last-ulp float differences between platforms.
func serialize() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("galaxy v%d seed=%d home=%d" % [GENERATION_VERSION, seed, home_system_id])
	for sys: StarSystem in systems:
		lines.append("system id=%d name=%s pos=%s star=%s tier=%d sec=%s" % [
			sys.id, sys.name, _vec(sys.position), sys.star_type, sys.danger_tier, sys.security,
		])
		for body: SystemBody in sys.bodies:
			lines.append(" body id=%d kind=%s biome=%s size=%.3f orbit=%.3f,%.3f col=%s res=%s" % [
				body.id, body.kind, body.biome, body.size,
				body.orbit_radius, body.orbit_angle, body.colonizable, _res(body.resources),
			])
		for station: SystemStation in sys.stations:
			lines.append(" station id=%d kind=%s pos=%s" % [
				station.id, station.kind, _vec(station.position),
			])
		for gate: WarpGate in sys.gates:
			lines.append(" gate id=%d to=%d pos=%s" % [gate.id, gate.to_system_id, _vec(gate.position)])
	for lane: WarpLane in lanes:
		lines.append("lane %d-%d len=%.3f" % [lane.a, lane.b, lane.length])
	return "\n".join(lines)


func content_hash() -> String:
	return serialize().sha256_text()


func _build_adjacency() -> void:
	if not _adjacency.is_empty() or lanes.is_empty():
		return
	for lane: WarpLane in lanes:
		if not _adjacency.has(lane.a):
			_adjacency[lane.a] = []
		if not _adjacency.has(lane.b):
			_adjacency[lane.b] = []
		_adjacency[lane.a].append(lane.b)
		_adjacency[lane.b].append(lane.a)


func _walk_back(came_from: Dictionary[int, int], from_id: int, to_id: int) -> Array[int]:
	var path: Array[int] = [to_id]
	var current: int = to_id
	while current != from_id:
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path


func _vec(v: Vector2) -> String:
	return "%.3f,%.3f" % [v.x, v.y]


func _res(resources: Dictionary[String, float]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var keys: Array = resources.keys()
	keys.sort()
	for key: String in keys:
		parts.append("%s:%.3f" % [key, resources[key]])
	return ",".join(parts) if parts.size() > 0 else "-"
