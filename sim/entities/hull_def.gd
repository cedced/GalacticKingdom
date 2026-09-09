class_name HullDef
extends RefCounted
## Immutable hull definition loaded from data/ships/<id>.json.
## Schema: data/schemas/ship.schema.json. Data only.

const _REQUIRED_FIELDS: Array[String] = [
	"id", "display_name", "model", "mass", "accel",
	"max_speed", "turn_rate_deg", "drag", "cargo_slots",
]

var id: String = ""
var display_name: String = ""
var model: String = ""
var mass: float = 0.0
var accel: float = 0.0
var max_speed: float = 0.0
var turn_rate_deg: float = 0.0
var drag: float = 0.0
var cargo_slots: int = 0


## Returns null on any missing field or degenerate value. Silently defaulting
## to 0 once let a hull with a typo'd turn_rate_deg produce NaN positions
## (PI / deg_to_rad(0) in the braking envelope) that spread to every peer.
static func from_dict(raw: Dictionary) -> HullDef:
	for field: String in _REQUIRED_FIELDS:
		if not raw.has(field):
			Log.error("entities", "hull is missing a required field", {
				"id": raw.get("id", "?"), "field": field
			})
			return null
	var hull: HullDef = HullDef.new()
	hull.id = str(raw["id"])
	hull.display_name = str(raw["display_name"])
	hull.model = str(raw["model"])
	hull.mass = float(raw["mass"])
	hull.accel = float(raw["accel"])
	hull.max_speed = float(raw["max_speed"])
	hull.turn_rate_deg = float(raw["turn_rate_deg"])
	hull.drag = float(raw["drag"])
	hull.cargo_slots = int(raw["cargo_slots"])
	if (
		hull.mass <= 0.0 or hull.accel <= 0.0 or hull.max_speed <= 0.0
		or hull.turn_rate_deg <= 0.0 or hull.drag < 0.0 or hull.cargo_slots < 0
	):
		Log.error("entities", "hull has a degenerate stat", {"id": hull.id})
		return null
	return hull
