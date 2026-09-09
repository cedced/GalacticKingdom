class_name HullDef
extends RefCounted
## Immutable hull definition loaded from data/ships/<id>.json.
## Schema: data/schemas/ship.schema.json. Data only.

var id: String = ""
var display_name: String = ""
var model: String = ""
var mass: float = 0.0
var accel: float = 0.0
var max_speed: float = 0.0
var turn_rate_deg: float = 0.0
var drag: float = 0.0
var cargo_slots: int = 0


static func from_dict(raw: Dictionary) -> HullDef:
	var hull: HullDef = HullDef.new()
	hull.id = str(raw.get("id", ""))
	hull.display_name = str(raw.get("display_name", ""))
	hull.model = str(raw.get("model", ""))
	hull.mass = float(raw.get("mass", 0.0))
	hull.accel = float(raw.get("accel", 0.0))
	hull.max_speed = float(raw.get("max_speed", 0.0))
	hull.turn_rate_deg = float(raw.get("turn_rate_deg", 0.0))
	hull.drag = float(raw.get("drag", 0.0))
	hull.cargo_slots = int(raw.get("cargo_slots", 0))
	return hull
