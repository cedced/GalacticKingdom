class_name ShipState
extends RefCounted
## Mutable per-ship simulation state. Data only (CLAUDE.md Section 3).
## Position and velocity live on the XZ plane; render height never enters sim.

## Floats per packed ship. Bump alongside pack()/unpack() when the wire
## format grows a field.
const PACK_STRIDE: int = 5

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
## Radians. Equals the visual Node3D Y rotation: 0 faces -Z, positive turns left.
var heading: float = 0.0


func forward() -> Vector2:
	return Vector2(-sin(heading), -cos(heading))


## Wire codec for snapshots. The layout used to be hand-decoded at five call
## sites; every producer and consumer must go through this pair instead.
func pack() -> PackedFloat32Array:
	return PackedFloat32Array([
		position.x, position.y, heading, velocity.x, velocity.y,
	])


static func unpack(packed: PackedFloat32Array) -> ShipState:
	if packed.size() != PACK_STRIDE:
		Log.error("entities", "bad packed ship size", {"size": packed.size()})
		return null
	var state: ShipState = ShipState.new()
	state.position = Vector2(packed[0], packed[1])
	state.heading = packed[2]
	state.velocity = Vector2(packed[3], packed[4])
	return state
