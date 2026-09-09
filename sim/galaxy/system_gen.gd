class_name SystemGen
extends RefCounted
## Internal to sim/galaxy: fills one StarSystem from its own child RNG, so a
## single system regenerates identically no matter what its siblings did.
## Distribution tables live here, documented on the wiki page; move one to
## data/ the day a designer needs to retune it without a version bump.

const STAR_TYPES: Array[String] = [
	"yellow", "orange", "red_dwarf", "white", "blue_giant", "red_giant",
]
const _STAR_WEIGHTS: Array[float] = [30.0, 20.0, 25.0, 10.0, 8.0, 7.0]

const BIOMES: Array[String] = [
	"rocky", "desert", "arctic", "volcanic", "oceanic",
	"mountainous", "greenhouse", "earthlike", "gas_giant", "tiny",
]
const _BIOME_WEIGHTS: Array[float] = [
	18.0, 14.0, 12.0, 10.0, 10.0, 10.0, 8.0, 6.0, 8.0, 4.0,
]
## Gas giants and tiny worlds hold artifacts and sleepers but no colonies
## (wiki/systems/planets.md); paradise is placed by hand at M4, never rolled.
const _UNCOLONIZABLE_BIOMES: Array[String] = ["gas_giant", "tiny"]

## What each biome tends to be rich in, from the launch commodity set
## (wiki/systems/planets.md).
const _BIOME_RESOURCES: Dictionary[String, Array] = {
	"arctic": ["medicine", "organics"],
	"volcanic": ["anaerobes", "metal_ore"],
	"desert": ["spice", "oil"],
	"mountainous": ["metal_ore", "uranium"],
	"greenhouse": ["medicine", "organics"],
	"oceanic": ["organics", "medicine"],
	"rocky": ["metal_ore", "oil"],
	"earthlike": ["organics", "equipment"],
	"gas_giant": ["anaerobes", "oil"],
	"tiny": ["uranium"],
}
const _ASTEROIDS_RESOURCES: Array[String] = ["metal_ore", "uranium"]
const _DERELICT_RESOURCES: Array[String] = ["equipment"]

const _BODY_KINDS: Array[String] = ["planet", "asteroids", "derelict"]
const _BODY_KIND_WEIGHTS: Array[float] = [70.0, 25.0, 5.0]


## Fills star type, bodies, and (maybe) a port. Gates and starbases need
## galaxy-wide knowledge and are placed by the facade.
static func populate(
	system: StarSystem, rng: RandomNumberGenerator, params: GalaxyParams
) -> void:
	system.star_type = _weighted_pick(rng, STAR_TYPES, _STAR_WEIGHTS)
	var body_count: int = rng.randi_range(1, params.max_bodies)
	for i: int in body_count:
		system.bodies.append(_make_body(rng, i, body_count, params))
	var tier_index: int = clampi(
		system.danger_tier, 0, params.port_probability_by_tier.size() - 1
	)
	if rng.randf() < params.port_probability_by_tier[tier_index]:
		add_station(system, rng, "port", params)


static func add_station(
	system: StarSystem, rng: RandomNumberGenerator, kind: String, params: GalaxyParams
) -> void:
	var station: SystemStation = SystemStation.new()
	station.id = system.stations.size()
	station.kind = kind
	var angle: float = rng.randf() * TAU
	station.position = Vector2(cos(angle), sin(angle)) * params.system_radius * 0.5
	system.stations.append(station)


static func _make_body(
	rng: RandomNumberGenerator, index: int, body_count: int, params: GalaxyParams
) -> SystemBody:
	var body: SystemBody = SystemBody.new()
	body.id = index
	body.kind = _weighted_pick(rng, _BODY_KINDS, _BODY_KIND_WEIGHTS)
	# Evenly spaced orbit rings with jitter, all inside the gate ring.
	var ring_step: float = params.system_radius * 0.7 / float(body_count + 1)
	body.orbit_radius = ring_step * float(index + 1) + rng.randf_range(-0.2, 0.2) * ring_step
	body.orbit_angle = rng.randf() * TAU
	var candidates: Array = _ASTEROIDS_RESOURCES
	if body.kind == "planet":
		body.biome = _weighted_pick(rng, BIOMES, _BIOME_WEIGHTS)
		body.colonizable = not _UNCOLONIZABLE_BIOMES.has(body.biome)
		body.size = _planet_size(rng, body.biome)
		candidates = _BIOME_RESOURCES[body.biome]
	elif body.kind == "asteroids":
		body.size = rng.randf_range(0.8, 1.5)
	else:
		body.size = rng.randf_range(0.4, 0.8)
		candidates = _DERELICT_RESOURCES
	for commodity: String in candidates:
		# Every candidate rolls richness; weak deposits drop off entirely.
		var richness: float = rng.randf()
		if richness >= 0.25:
			body.resources[commodity] = richness
	return body


static func _planet_size(rng: RandomNumberGenerator, biome: String) -> float:
	if biome == "gas_giant":
		return rng.randf_range(2.0, 3.5)
	if biome == "tiny":
		return rng.randf_range(0.3, 0.5)
	return rng.randf_range(0.7, 1.8)


static func _weighted_pick(
	rng: RandomNumberGenerator, values: Array[String], weights: Array[float]
) -> String:
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = rng.randf() * total
	for i: int in values.size():
		roll -= weights[i]
		if roll <= 0.0:
			return values[i]
	return values[values.size() - 1]
