class_name ServerMain
extends Node
## Headless authoritative server entry point (CLAUDE.md Section 5: server is
## truth, fixed 20 Hz tick). Generates the shard's galaxy from data/shard.json
## and hosts one SystemRoom per star system that currently has ships in it.
## Boot with:
##   godot --headless --path . --main-scene res://server/main.tscn

var _shard: ShardConfig = null
var _galaxy: GalaxyData = null
var _tick: int = 0
var _rooms: Dictionary[int, SystemRoom] = {}
var _sessions: Dictionary[int, PlayerSession] = {}
var _next_entity_id: int = 1
var _gate_radius: float = 0.0

@onready var _rpc: RpcSurface = $Rpc


func _ready() -> void:
	if not Tuning.load_data():
		Log.error("server", "tuning failed to load, aborting", {})
		get_tree().quit(1)
		return
	_shard = ShardConfig.load_file()
	if _shard == null:
		Log.error("server", "shard config failed to load, aborting", {})
		get_tree().quit(1)
		return
	Engine.physics_ticks_per_second = Tuning.value_i("net.tick_hz")
	_gate_radius = Tuning.value_f("warp.gate_radius")
	_galaxy = Galaxy.generate(_shard.seed, GalaxyParams.from_tuning())
	if not _start_listening():
		return
	Log.info("server", "listening", {
		"port": Tuning.value_i("net.port"),
		"tick_hz": Tuning.value_i("net.tick_hz"),
		"seed": _shard.seed,
		"systems": _galaxy.systems.size(),
		"home": _galaxy.system(_galaxy.home_system_id).name,
	})


func _start_listening() -> bool:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var port: int = Tuning.value_i("net.port")
	var err: Error = peer.create_server(port, Tuning.value_i("net.max_peers"))
	if err != OK:
		Log.error("server", "failed to bind", {"port": port, "error": err})
		get_tree().quit(1)
		return false
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_rpc.intent_received.connect(_on_intent_received)
	_rpc.jump_requested.connect(_on_jump_requested)
	return true


func _physics_process(delta: float) -> void:
	_tick += 1
	var snapshots: Dictionary[int, Dictionary] = {}
	for system_id: int in _rooms:
		_rooms[system_id].step(delta)
		snapshots[system_id] = _rooms[system_id].snapshot()
	for peer_id: int in _sessions:
		var session: PlayerSession = _sessions[peer_id]
		if snapshots.has(session.system_id):
			_rpc.receive_snapshot.rpc_id(peer_id, _tick, snapshots[session.system_id])


func _on_peer_connected(peer_id: int) -> void:
	var session: PlayerSession = PlayerSession.new()
	session.peer_id = peer_id
	session.entity_id = _next_entity_id
	_next_entity_id += 1
	session.system_id = _galaxy.home_system_id
	session.fuel = _shard.fuel_start
	session.fuel_updated_at = _now()
	_sessions[peer_id] = session
	_room_for(session.system_id).add_ship(session.entity_id)
	_rpc.receive_welcome.rpc_id(peer_id, {
		"entity_id": session.entity_id,
		"galaxy_seed": _shard.seed,
		"system_id": session.system_id,
		"fuel": session.fuel,
		"fuel_cap": _shard.fuel_cap,
		"fuel_per_minute": _shard.fuel_per_minute,
		"jump_cost": _shard.jump_cost,
	})
	Log.info("server", "peer connected", {"peer": peer_id, "entity": session.entity_id})


func _on_peer_disconnected(peer_id: int) -> void:
	Log.info("server", "peer disconnected", {"peer": peer_id})
	if not _sessions.has(peer_id):
		return
	var session: PlayerSession = _sessions[peer_id]
	_remove_from_room(session)
	_sessions.erase(peer_id)


func _on_intent_received(peer_id: int, thrust: float, turn: float) -> void:
	if not _sessions.has(peer_id):
		return
	var session: PlayerSession = _sessions[peer_id]
	if _rooms.has(session.system_id):
		_rooms[session.system_id].set_intent(session.entity_id, thrust, turn)


func _on_jump_requested(peer_id: int, to_system_id: int) -> void:
	if not _sessions.has(peer_id):
		return
	var session: PlayerSession = _sessions[peer_id]
	var now: float = _now()
	var fuel: float = session.current_fuel(_shard.fuel_cap, _shard.fuel_per_minute, now)
	var denial: String = Galaxy.jump_denial(
		_galaxy, session.system_id,
		_rooms[session.system_id].ship_position(session.entity_id),
		to_system_id, fuel, _shard.jump_cost, _gate_radius
	)
	if denial != "":
		_rpc.receive_jump_denied.rpc_id(peer_id, denial, fuel)
		return
	session.spend_fuel(_shard.jump_cost, _shard.fuel_cap, _shard.fuel_per_minute, now)
	_move_to_system(session, to_system_id)
	_rpc.receive_jump.rpc_id(peer_id, to_system_id, session.fuel)
	Log.info("world", "jump", {
		"entity": session.entity_id, "to": to_system_id, "fuel": session.fuel
	})


## Arrive at the destination's return gate, nudged inside the gate ring so
## the ship is not instantly back in jump range.
func _move_to_system(session: PlayerSession, to_system_id: int) -> void:
	_remove_from_room(session)
	var back_gate: WarpGate = _galaxy.system(to_system_id).gate_to(session.system_id)
	session.system_id = to_system_id
	_room_for(to_system_id).add_ship(session.entity_id, back_gate.position * 0.8)


func _room_for(system_id: int) -> SystemRoom:
	if not _rooms.has(system_id):
		var room: SystemRoom = SystemRoom.new()
		room.name = "Room%d" % system_id
		add_child(room)
		_rooms[system_id] = room
		Log.info("world", "room opened", {"system": system_id})
	return _rooms[system_id]


## Empty rooms are freed so the tick loop only visits live systems.
func _remove_from_room(session: PlayerSession) -> void:
	if not _rooms.has(session.system_id):
		return
	var room: SystemRoom = _rooms[session.system_id]
	room.remove_ship(session.entity_id)
	if room.is_empty():
		_rooms.erase(session.system_id)
		room.queue_free()
		Log.info("world", "room closed", {"system": session.system_id})


func _now() -> float:
	return Time.get_unix_time_from_system()
