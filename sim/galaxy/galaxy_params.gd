class_name GalaxyParams
extends RefCounted
## Generation knobs for one galaxy (wiki/systems/galaxy-generator.md). Tests
## construct these explicitly so golden hashes never depend on data/tuning.json.

var system_count: int = 0
## Radius of the galaxy disc in map units (map-space, not gameplay-space).
var radius: float = 0.0
## Multiplier on the max-packing spacing; higher spreads systems more evenly
## but makes placement retry (and eventually relax) more.
var spacing_factor: float = 0.0
## Extra random long lanes added on top of the neighborhood graph, as a
## fraction of its lane count. These are the loops and shortcuts.
var long_edge_ratio: float = 0.0
## Systems within this many jumps of home are safe space.
var safe_depth: int = 0
## Starbases per galaxy, home always included.
var starbase_count: int = 0
var max_bodies: int = 0
## Chance of a trade port per system, indexed by danger tier (clamped to the
## last entry).
var port_probability_by_tier: Array[float] = []
## Gameplay-space radius of a system: warp gates sit on this ring and bodies
## orbit inside it.
var system_radius: float = 0.0
## Innermost body orbit; keeps everything outside the sun's exclusion zone
## (collision.sun_radius, cross-checked by validate_data.py).
var min_orbit_radius: float = 0.0


static func from_tuning() -> GalaxyParams:
	var params: GalaxyParams = GalaxyParams.new()
	params.system_count = Tuning.value_i("galaxy.system_count")
	params.radius = Tuning.value_f("galaxy.radius")
	params.spacing_factor = Tuning.value_f("galaxy.spacing_factor")
	params.long_edge_ratio = Tuning.value_f("galaxy.long_edge_ratio")
	params.safe_depth = Tuning.value_i("galaxy.safe_depth")
	params.starbase_count = Tuning.value_i("galaxy.starbase_count")
	params.max_bodies = Tuning.value_i("galaxy.max_bodies")
	params.port_probability_by_tier.assign(Tuning.value("galaxy.port_probability_by_tier"))
	params.system_radius = Tuning.value_f("galaxy.system_radius")
	params.min_orbit_radius = Tuning.value_f("galaxy.min_orbit_radius")
	return params
