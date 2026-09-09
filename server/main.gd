class_name ServerMain
extends Node
## Headless authoritative server entry point (CLAUDE.md Section 5: server is
## truth, fixed 20 Hz tick). Boot with:
##   godot --headless --path . --main-scene res://server/main.tscn

var _room: SystemRoom = null
var _tick: int = 0
## peer id -> server-assigned entity id. Entity ids outlive nothing yet, but
## keeping them distinct from peer ids is what lets NPCs and sleepers share
## the snapshot namespace later.
var _entity_ids: Dictionary[int, int] = {}
var _next_entity_id: int = 1

@onready var _rpc: RpcSurface = $Rpc


func _ready() -> void:
	if not Tuning.load_data():
		Log.error("server", "tuning failed to load, aborting", {})
		get_tree().quit(1)
		return
	Engine.physics_ticks_per_second = Tuning.value_i("net.tick_hz")
	_room = SystemRoom.new()
	_room.name = "Room"
	add_child(_room)

	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var port: int = Tuning.value_i("net.port")
	var err: Error = peer.create_server(port, Tuning.value_i("net.max_peers"))
	if err != OK:
		Log.error("server", "failed to bind", {"port": port, "error": err})
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_rpc.intent_received.connect(_on_intent_received)
	Log.info("server", "listening", {"port": port, "tick_hz": Tuning.value_i("net.tick_hz")})


func _physics_process(delta: float) -> void:
	_tick += 1
	_room.step(delta)
	if multiplayer.get_peers().size() > 0:
		_rpc.receive_snapshot.rpc(_tick, _room.snapshot())


func _on_peer_connected(peer_id: int) -> void:
	var entity_id: int = _next_entity_id
	_next_entity_id += 1
	_entity_ids[peer_id] = entity_id
	Log.info("server", "peer connected", {"peer": peer_id, "entity": entity_id})
	_room.add_ship(entity_id)
	_rpc.receive_welcome.rpc_id(peer_id, entity_id)


func _on_peer_disconnected(peer_id: int) -> void:
	Log.info("server", "peer disconnected", {"peer": peer_id})
	if _entity_ids.has(peer_id):
		_room.remove_ship(_entity_ids[peer_id])
		_entity_ids.erase(peer_id)


func _on_intent_received(peer_id: int, thrust: float, turn: float) -> void:
	if _entity_ids.has(peer_id):
		_room.set_intent(_entity_ids[peer_id], thrust, turn)
