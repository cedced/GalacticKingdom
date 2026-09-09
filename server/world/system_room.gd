class_name SystemRoom
extends Node
## One star system instance: owns the authoritative ship states for every
## entity in it and advances them with sim/ code each tick. Rooms know nothing
## about peers — the server maps peer ids to entity ids at the RPC boundary,
## so NPCs and sleeper ships can live here without a connection behind them.

## Successive spawn angles step by the golden angle so any number of joins
## land on distinct ring positions (a quarter-turn step repeated after 4).
const GOLDEN_ANGLE: float = 2.399963229728653

var _hull: HullDef = null
var _spawn_radius: float = 0.0
var _ship_radius: float = 0.0
var _intent_timeout_ticks: int = 0
var _obstacles: Array[Obstacle] = []
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
	_ship_radius = Tuning.value_f("collision.ship_radius")
	_intent_timeout_ticks = int(ceil(
		Tuning.value_f("net.intent_timeout_ms") / 1000.0 * float(Tuning.value_i("net.tick_hz"))
	))


## Rooms are usable without a system (sim-level tests): no system means no
## obstacles, everything else behaves the same.
func set_system(system: StarSystem) -> void:
	_obstacles = Galaxy.system_obstacles(
		system,
		Tuning.value_f("collision.sun_radius"),
		Tuning.value_f("collision.station_radius")
	)


func add_ship(entity_id: int, spawn_at: Vector2 = Vector2.INF) -> void:
	var spawn: Vector2 = spawn_at
	if spawn == Vector2.INF:
		var angle: float = float(_spawn_counter) * GOLDEN_ANGLE
		_spawn_counter += 1
		spawn = Vector2(cos(angle), sin(angle)) * _spawn_radius
	_ships[entity_id] = Entities.make_ship_state(spawn)
	_intents[entity_id] = ShipIntent.new()
	_ticks_since_intent[entity_id] = 0
	Log.info("world", "ship spawned", {"entity": entity_id})


func remove_ship(entity_id: int) -> void:
	_ships.erase(entity_id)
	_intents.erase(entity_id)
	_ticks_since_intent.erase(entity_id)
	Log.info("world", "ship removed", {"entity": entity_id})


func has_ship(entity_id: int) -> bool:
	return _ships.has(entity_id)


func is_empty() -> bool:
	return _ships.is_empty()


func set_intent(entity_id: int, thrust: float, turn: float, enter: bool) -> void:
	if _intents.has(entity_id):
		_intents[entity_id] = ShipIntent.make(thrust, turn, enter)
		_ticks_since_intent[entity_id] = 0


func step(dt: float) -> void:
	for entity_id: int in _ships:
		_ticks_since_intent[entity_id] += 1
		# Dead-man's switch: a frozen or lossy client must not leave its ship
		# burning at full thrust forever (intents ride an unreliable channel).
		var intent: ShipIntent = _intents[entity_id]
		if _ticks_since_intent[entity_id] > _intent_timeout_ticks:
			intent = _idle_intent
		Motion.step(_ships[entity_id], intent, _hull, dt)
		Motion.resolve_obstacles(_ships[entity_id], _obstacles, _ship_radius, intent.enter)


## Full state, entity id -> ShipState.pack(). Deltas are a later optimization
## (wiki/systems/networking.md).
func snapshot() -> Dictionary:
	var ships: Dictionary = {}
	for entity_id: int in _ships:
		ships[entity_id] = _ships[entity_id].pack()
	return ships


func ship_position(entity_id: int) -> Vector2:
	return _ships[entity_id].position if _ships.has(entity_id) else Vector2.ZERO
