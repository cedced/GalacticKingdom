class_name SystemRoom
extends Node
## One star system instance: owns the authoritative ship states for every
## peer in it and advances them with sim/ code each tick. M0 hosts exactly
## one empty system; instancing N rooms per process comes with M1.

const M0_HULL_ID: String = "merchant_mk1"
const SPAWN_RING_RADIUS: float = 4.0

var _hull: HullDef = null
var _ships: Dictionary[int, ShipState] = {}
var _intents: Dictionary[int, ShipIntent] = {}
var _spawn_counter: int = 0


func _ready() -> void:
	_hull = Entities.load_hull(M0_HULL_ID)


func add_ship(peer_id: int) -> void:
	# Spread spawns around a small ring so two clients don't overlap.
	var angle: float = float(_spawn_counter) * PI * 0.5
	_spawn_counter += 1
	var spawn: Vector2 = Vector2(cos(angle), sin(angle)) * SPAWN_RING_RADIUS
	_ships[peer_id] = Entities.make_ship_state(spawn)
	_intents[peer_id] = ShipIntent.new()
	Log.info("world", "ship spawned", {"peer": peer_id})


func remove_ship(peer_id: int) -> void:
	_ships.erase(peer_id)
	_intents.erase(peer_id)
	Log.info("world", "ship removed", {"peer": peer_id})


func set_intent(peer_id: int, thrust: float, turn: float) -> void:
	if _intents.has(peer_id):
		_intents[peer_id] = ShipIntent.make(thrust, turn)


func step(dt: float) -> void:
	for peer_id: int in _ships:
		Motion.step(_ships[peer_id], _intents[peer_id], _hull, dt)


## Snapshot delta payload (wiki/systems/networking.md). M0 sends full state;
## real deltas are an M1+ concern.
func snapshot() -> Dictionary:
	var ships: Dictionary = {}
	for peer_id: int in _ships:
		var state: ShipState = _ships[peer_id]
		ships[peer_id] = PackedFloat32Array([
			state.position.x, state.position.y,
			state.heading,
			state.velocity.x, state.velocity.y,
		])
	return ships
