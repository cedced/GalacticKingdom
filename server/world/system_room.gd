class_name SystemRoom
extends Node
## One star system instance: owns the authoritative ship states for every
## peer in it and advances them with sim/ code each tick. M0 hosts exactly
## one empty system; instancing N rooms per process comes with M1.

## Successive spawn angles step by the golden angle so any number of joins
## land on distinct ring positions (a quarter-turn step repeated after 4).
const GOLDEN_ANGLE: float = 2.399963229728653

var _hull: HullDef = null
var _spawn_radius: float = 0.0
var _intent_timeout_ticks: int = 0
var _ships: Dictionary[int, ShipState] = {}
var _intents: Dictionary[int, ShipIntent] = {}
var _ticks_since_intent: Dictionary[int, int] = {}
var _idle_intent: ShipIntent = ShipIntent.new()
var _spawn_counter: int = 0


func _ready() -> void:
	_hull = Entities.load_hull(str(Tuning.value("world.starter_hull_id")))
	if _hull == null:
		Log.error("world", "starter hull failed to load, aborting", {})
		get_tree().quit(1)
		return
	_spawn_radius = Tuning.value_f("world.spawn_ring_radius")
	_intent_timeout_ticks = int(ceil(
		Tuning.value_f("net.intent_timeout_ms") / 1000.0 * float(Tuning.value_i("net.tick_hz"))
	))


func add_ship(peer_id: int) -> void:
	var angle: float = float(_spawn_counter) * GOLDEN_ANGLE
	_spawn_counter += 1
	var spawn: Vector2 = Vector2(cos(angle), sin(angle)) * _spawn_radius
	_ships[peer_id] = Entities.make_ship_state(spawn)
	_intents[peer_id] = ShipIntent.new()
	_ticks_since_intent[peer_id] = 0
	Log.info("world", "ship spawned", {"peer": peer_id})


func remove_ship(peer_id: int) -> void:
	_ships.erase(peer_id)
	_intents.erase(peer_id)
	_ticks_since_intent.erase(peer_id)
	Log.info("world", "ship removed", {"peer": peer_id})


func set_intent(peer_id: int, thrust: float, turn: float) -> void:
	if _intents.has(peer_id):
		_intents[peer_id] = ShipIntent.make(thrust, turn)
		_ticks_since_intent[peer_id] = 0


func step(dt: float) -> void:
	for peer_id: int in _ships:
		_ticks_since_intent[peer_id] += 1
		# Dead-man's switch: a frozen or lossy client must not leave its ship
		# burning at full thrust forever (intents ride an unreliable channel).
		var intent: ShipIntent = _intents[peer_id]
		if _ticks_since_intent[peer_id] > _intent_timeout_ticks:
			intent = _idle_intent
		Motion.step(_ships[peer_id], intent, _hull, dt)


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


func ship_position(peer_id: int) -> Vector2:
	return _ships[peer_id].position if _ships.has(peer_id) else Vector2.ZERO
