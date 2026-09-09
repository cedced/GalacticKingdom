class_name Motion
extends RefCounted
## Facade for ship motion integration. Runs identically on the server
## (authority) and the client (prediction) — see wiki/systems/networking.md.
## Pure: no nodes, no randomness, dt-parameterized.

## Below this steering magnitude (units/s) the autopilot coasts; numerical
## deadband, not a gameplay tunable.
const STEERING_DEADBAND: float = 0.05


## Heading whose forward() points along the given direction.
static func heading_to(direction: Vector2) -> float:
	return atan2(-direction.x, -direction.y)


## Fastest speed from which this hull can still stop within dist: flip 180
## degrees at full rudder, then burn against the motion. Drag is ignored,
## which only makes the estimate conservative. Solves
##   dist = v * flip_time + v^2 / (2 * accel)   for v.
static func braking_limited_speed(hull: HullDef, dist: float) -> float:
	# Degenerate hulls are rejected at load, but a zero here would put
	# PI / 0 -> NaN into every ship position; never let it through.
	if dist <= 0.0 or hull.accel <= 0.0 or hull.turn_rate_deg <= 0.0:
		return 0.0
	var flip_time: float = PI / deg_to_rad(hull.turn_rate_deg)
	var accel_flip: float = hull.accel * flip_time
	return -accel_flip + sqrt(accel_flip * accel_flip + 2.0 * hull.accel * dist)


## Go-to autopilot: produce the intent that steers toward target and comes to
## a halt there. Runs on the client, but only ever emits regular intents, so
## the server stays authoritative and the prediction path is unchanged.
##
## Steering is velocity-aware (steer toward desired velocity, not at the
## target): excess tangential or overshooting speed makes the steering vector
## point against the motion, so the ship flips and burns to brake instead of
## orbiting the target forever.
static func autopilot_intent(
	state: ShipState, hull: HullDef, target: Vector2, params: AutopilotParams
) -> ShipIntent:
	var to_target: Vector2 = target - state.position
	var dist: float = to_target.length()
	if dist <= params.arrive_radius:
		return ShipIntent.make(0.0, 0.0)
	var target_dir: Vector2 = to_target / dist
	# Full speed for as long as a flip-and-burn can still stop in time; the
	# braking envelope shrinks the desired speed only near the target.
	var stop_dist: float = maxf(dist - params.arrive_radius, 0.0) / params.brake_margin
	var desired_speed: float = minf(hull.max_speed, braking_limited_speed(hull, stop_dist))
	var steering: Vector2 = target_dir * desired_speed - state.velocity
	if steering.length() < STEERING_DEADBAND:
		return ShipIntent.make(0.0, 0.0)
	# Chasing small velocity errors nose-first makes the ship weave: near
	# cruise the steering vector is tiny and its direction is noisy. Aim at
	# the target while the error is small and only rotate toward the raw
	# correction (flip-and-burn included) as the error grows.
	var correction_weight: float = clampf(
		steering.length() / maxf(desired_speed, STEERING_DEADBAND), 0.0, 1.0
	)
	var aim: Vector2 = target_dir.lerp(steering.normalized(), correction_weight)
	if aim.length_squared() < STEERING_DEADBAND * STEERING_DEADBAND:
		aim = steering.normalized()
	var heading_error: float = wrapf(heading_to(aim) - state.heading, -PI, PI)
	# Centered rudder inside the deadzone, proportional beyond it.
	var effective_error: float = signf(heading_error) * maxf(
		absf(heading_error) - deg_to_rad(params.heading_deadzone_deg), 0.0
	)
	var turn: float = clampf(effective_error * params.turn_gain, -1.0, 1.0)
	var thrust: float = 0.0
	if absf(heading_error) < deg_to_rad(params.thrust_cone_deg):
		# Feed-forward the thrust that holds desired_speed against drag, plus
		# a proportional term on the deficit; pure-proportional droops below
		# max_speed because its output fades as the deficit closes.
		var hold: float = hull.drag * desired_speed / hull.accel
		thrust = clampf(
			hold + steering.dot(state.forward()) / params.thrust_softness, 0.0, 1.0
		)
	return ShipIntent.make(thrust, turn)


static func step(state: ShipState, intent: ShipIntent, hull: HullDef, dt: float) -> void:
	state.heading = wrapf(
		state.heading + intent.turn * deg_to_rad(hull.turn_rate_deg) * dt, -PI, PI
	)
	state.velocity += state.forward() * hull.accel * intent.thrust * dt
	state.velocity = state.velocity.lerp(Vector2.ZERO, minf(hull.drag * dt, 1.0))
	if state.velocity.length() > hull.max_speed:
		state.velocity = state.velocity.normalized() * hull.max_speed
	state.position += state.velocity * dt
