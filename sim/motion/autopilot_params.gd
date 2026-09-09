class_name AutopilotParams
extends RefCounted
## Go-to autopilot tunables. Data only; values live in data/tuning.json
## under "autopilot" (CLAUDE.md Section 6: no magic numbers).

## Inside this range the target counts as reached and the intent goes idle.
var arrive_radius: float = 0.0
## Proportional rudder gain on heading error (radians -> full rudder at 1/gain).
var turn_gain: float = 0.0
## Thrust is only applied while the heading error is inside this cone.
var thrust_cone_deg: float = 0.0
## Safety factor padding the computed flip-and-burn braking distance.
## Higher starts braking earlier; must be at least 1.
var brake_margin: float = 1.0
## Rudder stays centered for heading errors under this; stops micro-hunting.
var heading_deadzone_deg: float = 0.0
## Speed deficit (units/s) at which thrust reaches full; smooths bang-bang.
var thrust_softness: float = 1.0


static func from_tuning() -> AutopilotParams:
	var params: AutopilotParams = AutopilotParams.new()
	params.arrive_radius = Tuning.value_f("autopilot.arrive_radius")
	params.turn_gain = Tuning.value_f("autopilot.turn_gain")
	params.thrust_cone_deg = Tuning.value_f("autopilot.thrust_cone_deg")
	params.brake_margin = Tuning.value_f("autopilot.brake_margin")
	params.heading_deadzone_deg = Tuning.value_f("autopilot.heading_deadzone_deg")
	params.thrust_softness = Tuning.value_f("autopilot.thrust_softness")
	return params
