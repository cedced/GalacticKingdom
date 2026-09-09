class_name ShipInput
extends RefCounted
## Translates the input map into a ShipIntent. The client only ever sends
## intent; the server resolves it (CLAUDE.md Section 5).


static func gather() -> ShipIntent:
	var thrust: float = Input.get_action_strength("thrust_forward")
	var turn: float = (
		Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right")
	)
	return ShipIntent.make(thrust, turn)
