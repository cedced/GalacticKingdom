class_name ShipIntent
extends RefCounted
## One tick of player (or NPC driver) input. The client sends this; the server
## resolves it (CLAUDE.md Section 5: server is truth). Data only.

## 0..1 forward thrust.
var thrust: float = 0.0
## -1..1 rudder; positive turns left (positive Y rotation).
var turn: float = 0.0


static func make(p_thrust: float, p_turn: float) -> ShipIntent:
	var intent: ShipIntent = ShipIntent.new()
	intent.thrust = clampf(p_thrust, 0.0, 1.0)
	intent.turn = clampf(p_turn, -1.0, 1.0)
	return intent
