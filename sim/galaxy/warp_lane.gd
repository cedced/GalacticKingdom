class_name WarpLane
extends RefCounted
## An undirected edge between two systems. Stored once with a < b.

var a: int = 0
var b: int = 0
## Map-space distance between the two systems (route display; jumps cost
## flat fuel for now).
var length: float = 0.0


static func make(p_a: int, p_b: int, p_length: float) -> WarpLane:
	var lane: WarpLane = WarpLane.new()
	lane.a = mini(p_a, p_b)
	lane.b = maxi(p_a, p_b)
	lane.length = p_length
	return lane
