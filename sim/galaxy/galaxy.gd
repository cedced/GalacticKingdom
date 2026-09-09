class_name Galaxy
extends RefCounted
## Facade for the galaxy module (CLAUDE.md Section 6: other modules call only
## the facade). One seed in, one identical GalaxyData out, on every machine —
## the server and every client each regenerate the galaxy locally and only
## mutable state crosses the wire. RNG draw order is part of the output
## contract: reordering draws bumps GalaxyData.GENERATION_VERSION and the
## golden hashes with it.


static func generate(galaxy_seed: int, params: GalaxyParams) -> GalaxyData:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = galaxy_seed
	var galaxy: GalaxyData = GalaxyData.new()
	galaxy.seed = galaxy_seed
	var points: PackedVector2Array = GalaxyGraphGen.place_systems(rng, params)
	galaxy.lanes = GalaxyGraphGen.build_lanes(rng, points, params)
	galaxy.home_system_id = GalaxyGraphGen.home_system(points)
	var depths: Array[int] = GalaxyGraphGen.jump_depths(
		points.size(), galaxy.lanes, galaxy.home_system_id
	)
	var taken_names: Dictionary[String, bool] = {}
	for i: int in points.size():
		galaxy.systems.append(
			_make_system(galaxy_seed, i, points[i], depths[i], params, taken_names)
		)
	_place_gates(galaxy, params)
	_place_starbases(galaxy, rng, params)
	return galaxy


## "" when the jump is allowed, otherwise the denial reason shown to the
## player. The server is the only caller that matters (ADR-002); the client
## may call it for a pre-flight UI hint but never trusts its own answer.
static func jump_denial(
	galaxy: GalaxyData,
	from_system_id: int,
	ship_position: Vector2,
	to_system_id: int,
	fuel: float,
	jump_cost: float,
	gate_radius: float,
) -> String:
	var from_sys: StarSystem = galaxy.system(from_system_id)
	if from_sys == null:
		return "unknown system"
	var gate: WarpGate = from_sys.gate_to(to_system_id)
	if gate == null:
		return "no lane to that system"
	if ship_position.distance_to(gate.position) > gate_radius:
		return "too far from the gate"
	if fuel < jump_cost:
		return "not enough warp fuel"
	return ""


## Warp fuel accrues in real time, online or not; recomputed lazily from a
## timestamp, never ticked (CLAUDE.md Section 5: offline accrual).
static func accrued_fuel(
	last_fuel: float, cap: float, per_minute: float, elapsed_s: float
) -> float:
	return minf(cap, last_fuel + per_minute * maxf(elapsed_s, 0.0) / 60.0)


static func _make_system(
	galaxy_seed: int,
	id: int,
	point: Vector2,
	depth: int,
	params: GalaxyParams,
	taken_names: Dictionary[String, bool],
) -> StarSystem:
	var system: StarSystem = StarSystem.new()
	system.id = id
	system.position = point
	# Each system generates from its own child RNG so it regenerates
	# identically no matter what its siblings rolled.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _child_seed(galaxy_seed, id)
	system.danger_tier = 0 if depth == 0 else maxi(depth + rng.randi_range(-1, 1), 1)
	system.security = "safe" if depth <= params.safe_depth else "lawless"
	system.name = _unique_name(rng, taken_names)
	SystemGen.populate(system, rng, params)
	return system


static func _unique_name(
	rng: RandomNumberGenerator, taken_names: Dictionary[String, bool]
) -> String:
	var name: String = NameGen.system_name(rng)
	var tries: int = 0
	while taken_names.has(name) and tries < 10:
		name = NameGen.system_name(rng)
		tries += 1
	while taken_names.has(name):  # Grammar exhausted; numbered variants are rare.
		name += " %d" % (rng.randi_range(2, 9))
	taken_names[name] = true
	return name


## One gate per lane endpoint, sitting on the system_radius ring in the
## map-space direction of the neighbor, so the local view and the galaxy map
## agree about which way "toward Veldor" is.
static func _place_gates(galaxy: GalaxyData, params: GalaxyParams) -> void:
	for lane: WarpLane in galaxy.lanes:
		_add_gate(galaxy.system(lane.a), galaxy.system(lane.b), params)
		_add_gate(galaxy.system(lane.b), galaxy.system(lane.a), params)


static func _add_gate(from_sys: StarSystem, to_sys: StarSystem, params: GalaxyParams) -> void:
	var gate: WarpGate = WarpGate.new()
	gate.id = from_sys.gates.size()
	gate.to_system_id = to_sys.id
	gate.position = (to_sys.position - from_sys.position).normalized() * params.system_radius
	from_sys.gates.append(gate)


## Home always gets a starbase (and a port: a new player must be able to
## trade); the rest are drawn randomly from safe space, ties broken toward
## calm systems. A tiny safe zone just gets fewer starbases.
static func _place_starbases(
	galaxy: GalaxyData, rng: RandomNumberGenerator, params: GalaxyParams
) -> void:
	var home: StarSystem = galaxy.system(galaxy.home_system_id)
	SystemGen.add_station(home, rng, "starbase", params)
	if not home.has_station("port"):
		SystemGen.add_station(home, rng, "port", params)
	var candidates: Array[StarSystem] = []
	for system: StarSystem in galaxy.systems:
		if system.security == "safe" and system.id != galaxy.home_system_id:
			candidates.append(system)
	candidates.sort_custom(func(x: StarSystem, y: StarSystem) -> bool:
		return x.danger_tier < y.danger_tier if x.danger_tier != y.danger_tier else x.id < y.id)
	for i: int in mini(params.starbase_count - 1, candidates.size()):
		var pick: int = rng.randi_range(i, candidates.size() - 1)
		var chosen: StarSystem = candidates[pick]
		candidates[pick] = candidates[i]
		candidates[i] = chosen
		SystemGen.add_station(chosen, rng, "starbase", params)


## SplitMix64-style mixing; arithmetic shifts are fine here, this only needs
## to be well-spread and identical everywhere, not the canonical sequence.
static func _child_seed(galaxy_seed: int, salt: int) -> int:
	var z: int = galaxy_seed ^ (salt * -7046029254386353131)
	z = (z ^ (z >> 30)) * -4658895280553007687
	z = (z ^ (z >> 27)) * -7723592293110705685
	return z ^ (z >> 31)
