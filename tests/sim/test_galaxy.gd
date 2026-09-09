extends GutTest
## Galaxy generator invariants (wiki/systems/galaxy-generator.md test plan).
## Params are constructed explicitly so data/tuning.json changes never move
## the goldens; an intentional generation change bumps
## GalaxyData.GENERATION_VERSION and re-records the hashes below (the assert
## failure message prints the new hash).

const GOLDEN_HASHES: Dictionary[int, String] = {
	1: "acb60d01d5c1f7d2c6db7928efd14912dd091ed94cad2d09f4a8efa1093e7484",
	42: "316363fce3050dc960911d7c0956b25a75fd4ba58786ee89065f5e163d48772b",
	12345: "182f2ed31e79108d7f1a855daadf44200c2cc02d9e4cc5defba3b6559a1996fa",
}


func _params() -> GalaxyParams:
	var params: GalaxyParams = GalaxyParams.new()
	params.system_count = 60
	params.radius = 200.0
	params.spacing_factor = 1.4
	params.long_edge_ratio = 0.1
	params.safe_depth = 2
	params.starbase_count = 3
	params.max_bodies = 5
	params.port_probability_by_tier = [0.9, 0.7, 0.5, 0.4, 0.3]
	params.system_radius = 40.0
	return params


func test_golden_seeds() -> void:
	for seed_value: int in GOLDEN_HASHES:
		var galaxy: GalaxyData = Galaxy.generate(seed_value, _params())
		assert_eq(
			galaxy.content_hash(), GOLDEN_HASHES[seed_value],
			"golden hash moved for seed %d — unintended, or bump GENERATION_VERSION" % seed_value
		)


func test_different_seeds_differ() -> void:
	assert_ne(
		Galaxy.generate(1, _params()).content_hash(),
		Galaxy.generate(2, _params()).content_hash()
	)


func test_every_system_reachable_from_home() -> void:
	var galaxy: GalaxyData = Galaxy.generate(7, _params())
	for system: StarSystem in galaxy.systems:
		assert_gt(
			galaxy.shortest_path(galaxy.home_system_id, system.id).size(), 0,
			"system %d unreachable from home" % system.id
		)


func test_system_names_are_unique() -> void:
	var galaxy: GalaxyData = Galaxy.generate(7, _params())
	var seen: Dictionary[String, bool] = {}
	for system: StarSystem in galaxy.systems:
		assert_false(seen.has(system.name), "duplicate system name %s" % system.name)
		seen[system.name] = true


func test_home_is_safe_and_frontier_is_lawless() -> void:
	var galaxy: GalaxyData = Galaxy.generate(7, _params())
	var home: StarSystem = galaxy.system(galaxy.home_system_id)
	assert_eq(home.danger_tier, 0)
	assert_eq(home.security, "safe")
	var lawless: int = 0
	for system: StarSystem in galaxy.systems:
		if system.security == "lawless":
			lawless += 1
			assert_gt(system.danger_tier, 0, "lawless system %d has tier 0" % system.id)
	assert_gt(lawless, 0, "a galaxy with no lawless space has no game in it")


func test_gates_mirror_lanes() -> void:
	var galaxy: GalaxyData = Galaxy.generate(7, _params())
	var expected_gates: int = 0
	for lane: WarpLane in galaxy.lanes:
		expected_gates += 2
		assert_not_null(
			galaxy.system(lane.a).gate_to(lane.b), "lane %d-%d missing a-side gate" % [lane.a, lane.b]
		)
		assert_not_null(
			galaxy.system(lane.b).gate_to(lane.a), "lane %d-%d missing b-side gate" % [lane.a, lane.b]
		)
	var actual_gates: int = 0
	for system: StarSystem in galaxy.systems:
		actual_gates += system.gates.size()
	assert_eq(actual_gates, expected_gates, "stray gates without a lane")


func test_home_supports_a_new_player() -> void:
	var galaxy: GalaxyData = Galaxy.generate(7, _params())
	var home: StarSystem = galaxy.system(galaxy.home_system_id)
	assert_true(home.has_station("starbase"), "home must sell ships")
	assert_true(home.has_station("port"), "home must trade commodities")


func test_starbase_count_matches_params() -> void:
	var galaxy: GalaxyData = Galaxy.generate(7, _params())
	var count: int = 0
	for system: StarSystem in galaxy.systems:
		for station: SystemStation in system.stations:
			if station.kind == "starbase":
				count += 1
				assert_eq(system.security, "safe", "starbase in lawless system %d" % system.id)
	assert_eq(count, _params().starbase_count)


func test_bodies_are_well_formed() -> void:
	var galaxy: GalaxyData = Galaxy.generate(7, _params())
	for system: StarSystem in galaxy.systems:
		assert_between(system.bodies.size(), 1, _params().max_bodies)
		for body: SystemBody in system.bodies:
			assert_true(body.kind in ["planet", "asteroids", "derelict"], "bad kind " + body.kind)
			if body.kind == "planet":
				assert_true(SystemGen.BIOMES.has(body.biome), "bad biome " + body.biome)
			else:
				assert_false(body.colonizable, "only planets are colonizable")
			assert_lt(
				body.orbit_radius, _params().system_radius,
				"body outside the gate ring in system %d" % system.id
			)
			for richness: float in body.resources.values():
				assert_between(richness, 0.0, 1.0)


func test_shortest_path_walks_lanes() -> void:
	var galaxy: GalaxyData = Galaxy.generate(7, _params())
	var far_id: int = 0
	for system: StarSystem in galaxy.systems:
		if system.danger_tier > galaxy.system(far_id).danger_tier:
			far_id = system.id
	var path: Array[int] = galaxy.shortest_path(galaxy.home_system_id, far_id)
	assert_eq(path[0], galaxy.home_system_id)
	assert_eq(path[path.size() - 1], far_id)
	for i: int in path.size() - 1:
		assert_has(galaxy.neighbors(path[i]), path[i + 1], "path hops a missing lane")


func test_jump_denial_reasons() -> void:
	var galaxy: GalaxyData = Galaxy.generate(7, _params())
	var home_id: int = galaxy.home_system_id
	var neighbor_id: int = galaxy.neighbors(home_id)[0]
	var gate: WarpGate = galaxy.system(home_id).gate_to(neighbor_id)
	var stranger_id: int = -1
	for system: StarSystem in galaxy.systems:
		if system.id != home_id and not galaxy.neighbors(home_id).has(system.id):
			stranger_id = system.id
			break
	assert_eq(
		Galaxy.jump_denial(galaxy, home_id, gate.position, neighbor_id, 10.0, 5.0, 6.0), "",
		"a fueled ship at the gate must be allowed through"
	)
	assert_eq(
		Galaxy.jump_denial(galaxy, home_id, gate.position, stranger_id, 10.0, 5.0, 6.0),
		"no lane to that system"
	)
	assert_eq(
		Galaxy.jump_denial(galaxy, home_id, Vector2.ZERO, neighbor_id, 10.0, 5.0, 6.0),
		"too far from the gate"
	)
	assert_eq(
		Galaxy.jump_denial(galaxy, home_id, gate.position, neighbor_id, 4.9, 5.0, 6.0),
		"not enough warp fuel"
	)


func test_system_obstacles_cover_the_solid_things() -> void:
	var galaxy: GalaxyData = Galaxy.generate(7, _params())
	var home: StarSystem = galaxy.system(galaxy.home_system_id)
	var obstacles: Array[Obstacle] = Galaxy.system_obstacles(home, 4.8, 2.0)
	assert_eq(obstacles[0].kind, "sun")
	assert_false(obstacles[0].enterable, "the sun is never enterable")
	var expected: int = 1 + home.stations.size()
	for body: SystemBody in home.bodies:
		if body.kind != "asteroids":
			expected += 1
	assert_eq(obstacles.size(), expected, "asteroid fields and gates must not be walls")
	for i: int in range(1, obstacles.size()):
		assert_true(obstacles[i].enterable, "everything but the sun is enterable")
		assert_gt(obstacles[i].radius, 0.0)


func test_fuel_accrues_and_caps() -> void:
	assert_almost_eq(Galaxy.accrued_fuel(10.0, 50.0, 6.0, 60.0), 16.0, 0.0001)
	assert_eq(Galaxy.accrued_fuel(10.0, 50.0, 6.0, 36000.0), 50.0)
	assert_eq(Galaxy.accrued_fuel(10.0, 50.0, 6.0, -5.0), 10.0)
	assert_eq(Galaxy.accrued_fuel(50.0, 50.0, 6.0, 60.0), 50.0)
