class_name ShipState
extends RefCounted
## Mutable per-ship simulation state. Data only (CLAUDE.md Section 3).
## Position and velocity live on the XZ plane; render height never enters sim.

var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
## Radians. Equals the visual Node3D Y rotation: 0 faces -Z, positive turns left.
var heading: float = 0.0


func forward() -> Vector2:
	return Vector2(-sin(heading), -cos(heading))
