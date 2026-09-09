class_name Entities
extends RefCounted
## Facade for the entities module (CLAUDE.md Section 6: other modules call
## only the facade). Loads immutable definitions from data/ and builds states.

const SHIPS_DIR: String = "res://data/ships/"

static var _hull_cache: Dictionary[String, HullDef] = {}


static func load_hull(hull_id: String) -> HullDef:
	if _hull_cache.has(hull_id):
		return _hull_cache[hull_id]
	var path: String = SHIPS_DIR + hull_id + ".json"
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		Log.error("entities", "hull file missing or empty", {"path": path})
		return null
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		Log.error("entities", "hull file is not a JSON object", {"path": path})
		return null
	var hull: HullDef = HullDef.from_dict(parsed)
	if hull == null:
		return null  # already logged; not cached so a fixed file loads next call
	_hull_cache[hull_id] = hull
	return hull


static func make_ship_state(spawn_position: Vector2 = Vector2.ZERO) -> ShipState:
	var state: ShipState = ShipState.new()
	state.position = spawn_position
	return state
