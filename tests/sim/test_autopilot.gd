extends GutTest
## Go-to autopilot: emits only regular intents and actually reaches the target.

const DT: float = 0.05

var _hull: HullDef
var _params: AutopilotParams


func before_each() -> void:
	_hull = HullDef.from_dict({
		"id": "test_hull",
		"display_name": "Test Hull",
		"model": "res://assets/ships/test_hull/test_hull.glb",
		"mass": 10.0,
		"accel": 12.0,
		"max_speed": 14.0,
		"turn_rate_deg": 180.0,
		"drag": 0.6,
		"cargo_slots": 8,
	})
	_params = AutopilotParams.new()
	_params.arrive_radius = 0.75
	_params.turn_gain = 4.0
	_params.thrust_cone_deg = 60.0
	_params.brake_margin = 1.3
	_params.heading_deadzone_deg = 2.0
	_params.thrust_softness = 2.0


func test_heading_to_matches_forward() -> void:
	var directions: Array[Vector2] = [
		Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.7, 0.7),
	]
	for direction: Vector2 in directions:
		var state: ShipState = ShipState.new()
		state.heading = Motion.heading_to(direction)
		assert_almost_eq(state.forward().x, direction.normalized().x, 0.0001)
		assert_almost_eq(state.forward().y, direction.normalized().y, 0.0001)


func test_turns_toward_target_on_the_right() -> void:
	var state: ShipState = ShipState.new()  # heading 0, facing (0, -1)
	var intent: ShipIntent = Motion.autopilot_intent(
		state, _hull, Vector2(10.0, 0.0), _params
	)
	assert_lt(intent.turn, 0.0, "target to the +x side needs a right turn")


func test_no_thrust_when_facing_away() -> void:
	var state: ShipState = ShipState.new()  # facing (0, -1)
	var intent: ShipIntent = Motion.autopilot_intent(
		state, _hull, Vector2(0.0, 10.0), _params
	)
	assert_eq(intent.thrust, 0.0)


func test_idle_inside_arrive_radius() -> void:
	var state: ShipState = ShipState.new()
	var intent: ShipIntent = Motion.autopilot_intent(
		state, _hull, Vector2(0.3, 0.3), _params
	)
	assert_eq(intent.thrust, 0.0)
	assert_eq(intent.turn, 0.0)


func test_reaches_target_and_halts_ahead_and_behind() -> void:
	for target: Vector2 in [Vector2(0.0, -20.0), Vector2(15.0, 25.0)]:
		var state: ShipState = ShipState.new()
		_assert_arrives_and_halts(state, target)


func test_tangential_flyby_does_not_orbit() -> void:
	# Regression: a ship passing the target at full speed used to circle it
	# forever because steering ignored velocity.
	var state: ShipState = ShipState.new()
	state.position = Vector2(5.0, 0.0)
	state.velocity = Vector2(0.0, -_hull.max_speed)
	state.heading = Motion.heading_to(state.velocity)
	_assert_arrives_and_halts(state, Vector2.ZERO)


func _assert_arrives_and_halts(state: ShipState, target: Vector2) -> void:
	var reached: bool = false
	for _i: int in 2000:  # 100 simulated seconds, far more than needed
		var intent: ShipIntent = Motion.autopilot_intent(state, _hull, target, _params)
		Motion.step(state, intent, _hull, DT)
		if state.position.distance_to(target) <= _params.arrive_radius:
			reached = true
			break
	assert_true(reached, "never arrived at %s" % target)
	# After arrival the autopilot goes idle and drag must bleed the rest off.
	for _i: int in 100:
		var intent: ShipIntent = Motion.autopilot_intent(state, _hull, target, _params)
		Motion.step(state, intent, _hull, DT)
	assert_lt(state.velocity.length(), 0.5, "still moving near %s" % target)
	assert_lt(
		state.position.distance_to(target),
		_params.arrive_radius * 2.0,
		"drifted away from %s" % target
	)


func test_degenerate_hull_never_yields_nan() -> void:
	# Loader rejects these, but the math must still be safe by construction.
	var broken: HullDef = HullDef.new()  # every stat zero
	assert_eq(Motion.braking_limited_speed(broken, 10.0), 0.0)
	var state: ShipState = ShipState.new()
	var intent: ShipIntent = Motion.autopilot_intent(state, broken, Vector2(10.0, 0.0), _params)
	assert_true(is_finite(intent.thrust) and is_finite(intent.turn))


func test_braking_limited_speed_is_monotonic_and_stops_at_zero() -> void:
	assert_eq(Motion.braking_limited_speed(_hull, 0.0), 0.0)
	var previous: float = 0.0
	for dist: float in [1.0, 5.0, 20.0, 100.0]:
		var speed: float = Motion.braking_limited_speed(_hull, dist)
		assert_gt(speed, previous, "not monotonic at dist %s" % dist)
		previous = speed


func test_cruises_at_max_speed_when_target_is_far() -> void:
	# The autopilot must fly the hull flat out until the braking envelope,
	# not creep along; max_speed itself is per-hull data (data/ships/).
	var state: ShipState = ShipState.new()
	var target: Vector2 = Vector2(0.0, -300.0)
	var top_speed: float = 0.0
	for _i: int in 600:  # 30 simulated seconds
		var intent: ShipIntent = Motion.autopilot_intent(state, _hull, target, _params)
		Motion.step(state, intent, _hull, DT)
		top_speed = maxf(top_speed, state.velocity.length())
	assert_gt(top_speed, _hull.max_speed * 0.95, "never reached cruise speed")
	assert_lte(top_speed, _hull.max_speed + 0.001, "exceeded the per-hull speed cap")


func test_cruise_does_not_weave() -> void:
	# Regression: small lateral velocity errors used to swing the aim wildly,
	# so the ship twitched left/right all the way to the target.
	var target: Vector2 = Vector2(0.0, -300.0)
	var state: ShipState = ShipState.new()  # heading 0 already faces the target
	state.velocity = Vector2(0.6, 0.0)  # slight sideways drift
	var max_cruise_turn: float = 0.0
	for i: int in 400:
		var intent: ShipIntent = Motion.autopilot_intent(state, _hull, target, _params)
		Motion.step(state, intent, _hull, DT)
		if i >= 40:  # allow 2 s to absorb the initial drift
			max_cruise_turn = maxf(max_cruise_turn, absf(intent.turn))
	assert_lt(max_cruise_turn, 0.35, "rudder still swinging during cruise")


func test_autopilot_params_load_from_tuning() -> void:
	Tuning.load_data()
	var params: AutopilotParams = AutopilotParams.from_tuning()
	assert_gt(params.arrive_radius, 0.0)
	assert_gt(params.turn_gain, 0.0)
	assert_gt(params.thrust_cone_deg, 0.0)
	assert_gte(params.brake_margin, 1.0)
	assert_gt(params.heading_deadzone_deg, 0.0)
	assert_gt(params.thrust_softness, 0.0)
