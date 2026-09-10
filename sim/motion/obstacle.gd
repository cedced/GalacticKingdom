class_name Obstacle
extends RefCounted
## One circular no-fly zone on the XZ plane. Data only. Radii come from sim
## data (body sizes, tuning), never from render scales (CLAUDE.md Section 4:
## render height and visuals never affect collision).

var position: Vector2 = Vector2.ZERO
var radius: float = 0.0
## sun | planet | derelict | station. What enter-mode contact means (dock,
## land, board) dispatches on this.
var kind: String = ""
## True for things enter mode may touch (planets, stations, derelicts —
## contact is how docking and landing will trigger). False for the sun,
## which is a wall in every mode.
var enterable: bool = false


static func make(
	p_position: Vector2, p_radius: float, p_kind: String, p_enterable: bool
) -> Obstacle:
	var obstacle: Obstacle = Obstacle.new()
	obstacle.position = p_position
	obstacle.radius = p_radius
	obstacle.kind = p_kind
	obstacle.enterable = p_enterable
	return obstacle
