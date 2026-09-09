class_name WarpGate
extends RefCounted
## The in-system object a ship flies to and jumps from. One gate per lane
## endpoint; its id is unique within its system only.

var id: int = 0
var to_system_id: int = 0
## Gameplay-space position: on the system_radius ring, in the map-space
## direction of the neighboring system, so the map and the world agree.
var position: Vector2 = Vector2.ZERO
