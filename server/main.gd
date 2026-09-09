class_name ServerMain
extends Node
## Headless authoritative server entry point (CLAUDE.md Section 5: server is
## truth, fixed 20 Hz tick). Boot with:
##   godot --headless --path . --main-scene res://server/main.tscn

var _room: SystemRoom = null
var _tick: int = 0


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
	Log.info("server", "listening", {"port": port, "tick_hz": Tuning.value_i("net.tick_hz")})


func _physics_process(delta: float) -> void:
	_tick += 1
	_room.step(delta)
	if multiplayer.get_peers().size() > 0:
		receive_snapshot.rpc(_tick, _room.snapshot())


func _on_peer_connected(peer_id: int) -> void:
	Log.info("server", "peer connected", {"peer": peer_id})
	_room.add_ship(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	Log.info("server", "peer disconnected", {"peer": peer_id})
	_room.remove_ship(peer_id)


## Client -> server. RPC config must match client/main.gd exactly.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_intent(thrust: float, turn: float) -> void:
	_room.set_intent(multiplayer.get_remote_sender_id(), thrust, turn)


## Server -> client. Declared here so both peers agree on the RPC table;
## the body only runs on clients.
@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(_tick_num: int, _ships: Dictionary) -> void:
	pass
