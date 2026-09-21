extends GutTest
## Tests for sim/motion (CLAUDE.md Section 7.3: sim changes ship with tests).

const DT: float = 0.05

var _hull: HullDef


func before_each() -> void:
	_hull = HullDef.from_dict({
		"id": "test_hull",
		"display_name": "Test Hull",
		"model": "res://assets/ships/test_hull/test_hull.glb",
		"mass": 10.0,
		"accel": 10.0,
		"max_speed": 5.0,
		"turn_rate_deg": 90.0,
		"drag": 0.0,
		"cargo_slots": 8,
	})


func test_zero_intent_zero_velocity_stays_put() -> void:
	var state: ShipState = ShipState.new()
	Motion.step(state, ShipIntent.make(0.0, 0.0), _hull, DT)
	assert_eq(state.position, Vector2.ZERO)
	assert_eq(state.velocity, Vector2.ZERO)
	assert_eq(state.heading, 0.0)


func test_full_thrust_moves_along_facing() -> void:
	var state: ShipState = ShipState.new()
	Motion.step(state, ShipIntent.make(1.0, 0.0), _hull, DT)
	# Heading 0 faces -Z, which is -y in the XZ Vector2 mapping.
	assert_almost_eq(state.velocity.y, -_hull.accel * DT, 0.0001)
	assert_almost_eq(state.velocity.x, 0.0, 0.0001)
	assert_lt(state.position.y, 0.0)


func test_turn_rate_matches_hull() -> void:
	var state: ShipState = ShipState.new()
	# One second of full left rudder at 90 deg/s.
	for _i: int in 20:
		Motion.step(state, ShipIntent.make(0.0, 1.0), _hull, DT)
	assert_almost_eq(state.heading, deg_to_rad(90.0), 0.0001)


func test_speed_is_capped_at_max_speed() -> void:
	var state: ShipState = ShipState.new()
	for _i: int in 200:
		Motion.step(state, ShipIntent.make(1.0, 0.0), _hull, DT)
	assert_almost_eq(state.velocity.length(), _hull.max_speed, 0.0001)


func test_drag_decays_velocity_without_thrust() -> void:
	_hull.drag = 1.0
	var state: ShipState = ShipState.new()
	state.velocity = Vector2(4.0, 0.0)
	Motion.step(state, ShipIntent.make(0.0, 0.0), _hull, DT)
	assert_lt(state.velocity.length(), 4.0)
	assert_gt(state.velocity.length(), 0.0)


func test_integration_is_reproducible() -> void:
	# Same intents in, identical trajectory out (CLAUDE.md Section 5:
	# reproducible from logs).
	var a: ShipState = ShipState.new()
	var b: ShipState = ShipState.new()
	for i: int in 100:
		var intent: ShipIntent = ShipIntent.make(float(i % 2), float(i % 3) - 1.0)
		Motion.step(a, intent, _hull, DT)
		Motion.step(b, intent, _hull, DT)
	assert_eq(a.position, b.position)
	assert_eq(a.velocity, b.velocity)
	assert_eq(a.heading, b.heading)


func test_intent_is_clamped() -> void:
	var intent: ShipIntent = ShipIntent.make(7.0, -9.0)
	assert_eq(intent.thrust, 1.0)
	assert_eq(intent.turn, -1.0)


func test_wall_pushes_ship_out_and_slides() -> void:
	var state: ShipState = ShipState.new()
	state.position = Vector2(2.0, 0.5)  # Inside a radius-3 obstacle at origin.
	state.velocity = Vector2(-4.0, 1.0)
	var walls: Array[Obstacle] = [Obstacle.make(Vector2.ZERO, 3.0, "sun", false)]
	var touched: Obstacle = Motion.resolve_obstacles(state, walls, 0.5, false)
	assert_null(touched, "a wall is not a touch")
	assert_almost_eq(state.position.length(), 3.5, 0.0001, "pushed to radius + ship radius")
	assert_gte(
		state.velocity.dot(state.position.normalized()), 0.0,
		"inward velocity must be removed, tangential kept"
	)
	assert_gt(state.velocity.length(), 0.0, "sliding, not stopped dead")


func test_ship_outside_obstacle_is_untouched() -> void:
	var state: ShipState = ShipState.new()
	state.position = Vector2(10.0, 0.0)
	state.velocity = Vector2(-4.0, 0.0)
	var walls: Array[Obstacle] = [Obstacle.make(Vector2.ZERO, 3.0, "sun", false)]
	Motion.resolve_obstacles(state, walls, 0.5, false)
	assert_eq(state.position, Vector2(10.0, 0.0))
	assert_eq(state.velocity, Vector2(-4.0, 0.0))


func test_enter_mode_passes_enterables_but_never_the_sun() -> void:
	var walls: Array[Obstacle] = [
		Obstacle.make(Vector2.ZERO, 3.0, "sun", false),
		Obstacle.make(Vector2(20.0, 0.0), 2.0, "planet", true),
	]
	var state: ShipState = ShipState.new()
	state.position = Vector2(20.5, 0.0)
	var touched: Obstacle = Motion.resolve_obstacles(state, walls, 0.5, true)
	assert_eq(state.position, Vector2(20.5, 0.0), "enter mode overlaps a planet freely")
	assert_not_null(touched)
	assert_eq(touched.kind, "planet")
	state.position = Vector2(1.0, 0.0)
	Motion.resolve_obstacles(state, walls, 0.5, true)
	assert_almost_eq(state.position.length(), 3.5, 0.0001, "the sun is a wall in every mode")


func test_dead_center_overlap_does_not_nan() -> void:
	var state: ShipState = ShipState.new()
	var walls: Array[Obstacle] = [Obstacle.make(Vector2.ZERO, 3.0, "sun", false)]
	Motion.resolve_obstacles(state, walls, 0.5, false)
	assert_true(state.position.is_finite(), "zero-distance overlap must pick a direction")
	assert_almost_eq(state.position.length(), 3.5, 0.0001)
