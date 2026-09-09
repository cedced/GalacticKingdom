class_name ClientMain
extends Node3D
## Client entry point: connects to the server, sends intents, predicts the
## local ship with the same sim/ code, and renders snapshots (ADR-002).
## Pass "-- --server=<host>" on the command line to join a remote server.

const SHIP_SCENE: PackedScene = preload("res://client/scenes/ship.tscn")
const DEFAULT_SERVER_ADDRESS: String = "127.0.0.1"
const RECONCILE_BLEND: float = 0.15

var _hull: HullDef = null
var _my_state: ShipState = null
var _my_intent: ShipIntent = ShipIntent.new()
var _views: Dictionary[int, ShipView] = {}
var _got_first_snapshot: bool = false
var _autopilot: AutopilotParams = null
var _goto_active: bool = false
var _goto_target: Vector2 = Vector2.ZERO

@onready var _camera: IsoCamera = $IsoCamera
@onready var _goto_marker: Node3D = $GotoMarker


func _ready() -> void:
	if not Tuning.load_data():
		Log.error("client", "tuning failed to load, aborting", {})
		get_tree().quit(1)
		return
	# Prediction must integrate at the same fixed tick the server runs
	# (CLAUDE.md Section 5); Motion.step is not dt-invariant, so a 60 Hz
	# client fights a permanent bias against a 20 Hz server.
	Engine.physics_ticks_per_second = Tuning.value_i("net.tick_hz")
	_hull = Entities.load_hull(str(Tuning.value("world.starter_hull_id")))
	if _hull == null:
		Log.error("client", "starter hull failed to load, aborting", {})
		get_tree().quit(1)
		return
	_autopilot = AutopilotParams.from_tuning()
	$Sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	_connect_to_server(_server_address())


func _physics_process(delta: float) -> void:
	if _my_state == null:
		return
	_my_intent = _resolve_intent()
	submit_intent.rpc_id(1, _my_intent.thrust, _my_intent.turn)
	# Prediction: same integrator the server runs (wiki/systems/networking.md).
	Motion.step(_my_state, _my_intent, _hull, delta)


## Manual input wins and cancels the go-to; otherwise the autopilot steers.
func _resolve_intent() -> ShipIntent:
	var manual: ShipIntent = ShipInput.gather()
	if manual.thrust > 0.0 or manual.turn != 0.0:
		_clear_goto()
		return manual
	if not _goto_active:
		return manual
	if _my_state.position.distance_to(_goto_target) <= _autopilot.arrive_radius:
		_clear_goto()
		return manual
	return Motion.autopilot_intent(_my_state, _hull, _goto_target, _autopilot)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("go_to") or _my_state == null:
		return
	var mouse: InputEventMouseButton = event
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_goto_target = Iso.screen_to_world_plane(
		mouse.position, _camera.global_transform, _camera.size, viewport_size
	)
	_goto_active = true
	_goto_marker.position = Vector3(_goto_target.x, _goto_marker.position.y, _goto_target.y)
	_goto_marker.visible = true


func _clear_goto() -> void:
	_goto_active = false
	_goto_marker.visible = false


func _process(_delta: float) -> void:
	if _my_state == null:
		return
	var my_id: int = multiplayer.get_unique_id()
	if not _views.has(my_id):
		return
	# The predicted state updates at the 20 Hz sim tick; render through the
	# view's blend (and follow the blended view with the camera) so the local
	# ship stays smooth at any display rate.
	var view: ShipView = _views[my_id]
	view.set_target(_my_state.position, _my_state.heading)
	_camera.set_target(Vector3(view.position.x, 0.0, view.position.z))


func _connect_to_server(address: String) -> void:
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var port: int = Tuning.value_i("net.port")
	var err: Error = peer.create_client(address, port)
	if err != OK:
		Log.error("net", "failed to create client peer", {"address": address, "error": err})
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	Log.info("net", "connecting", {"address": address, "port": port})


func _server_address() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--server="):
			return arg.trim_prefix("--server=")
	return DEFAULT_SERVER_ADDRESS


func _on_connected() -> void:
	Log.info("net", "connected", {"peer_id": multiplayer.get_unique_id()})


func _on_connection_failed() -> void:
	Log.error("net", "connection failed", {})


func _on_server_disconnected() -> void:
	Log.warn("net", "server disconnected", {})
	_my_state = null
	_got_first_snapshot = false
	for view: ShipView in _views.values():
		view.queue_free()
	_views.clear()


## Server -> client. RPC config must match server/main.gd exactly.
@rpc("authority", "call_remote", "unreliable_ordered")
func receive_snapshot(_tick_num: int, ships: Dictionary) -> void:
	if not _got_first_snapshot:
		_got_first_snapshot = true
		Log.info("net", "first snapshot received", {"ships": ships.size()})
	var my_id: int = multiplayer.get_unique_id()
	for peer_id: int in ships:
		var packed: PackedFloat32Array = ships[peer_id]
		_ensure_view(peer_id, packed)
		if peer_id == my_id:
			_reconcile_local(packed)
		else:
			_views[peer_id].set_target(Vector2(packed[0], packed[1]), packed[2])
	for peer_id: int in _views.keys():
		if not ships.has(peer_id):
			_views[peer_id].queue_free()
			_views.erase(peer_id)


## Client -> server. Declared here so both peers agree on the RPC table;
## the body only runs on the server.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_intent(_thrust: float, _turn: float) -> void:
	pass


func _ensure_view(peer_id: int, packed: PackedFloat32Array) -> void:
	if _views.has(peer_id):
		return
	var view: ShipView = SHIP_SCENE.instantiate()
	view.name = "Ship%d" % peer_id
	add_child(view)
	view.set_immediate(Vector2(packed[0], packed[1]), packed[2])
	_views[peer_id] = view
	Log.info("net", "ship view created", {
		"peer": peer_id, "remote": peer_id != multiplayer.get_unique_id()
	})
	if peer_id == multiplayer.get_unique_id() and _my_state == null:
		_my_state = Entities.make_ship_state(Vector2(packed[0], packed[1]))
		_my_state.heading = packed[2]


## M0 reconciliation: blend gently toward the authoritative state, snap on
## large error. Full rewind-and-replay is an M1+ item (networking wiki page).
func _reconcile_local(packed: PackedFloat32Array) -> void:
	var server_pos: Vector2 = Vector2(packed[0], packed[1])
	var server_vel: Vector2 = Vector2(packed[3], packed[4])
	if _my_state.position.distance_to(server_pos) > Tuning.value_f("net.snap_correction_dist"):
		_my_state.position = server_pos
		_my_state.velocity = server_vel
		_my_state.heading = packed[2]
		return
	_my_state.position = _my_state.position.lerp(server_pos, RECONCILE_BLEND)
	_my_state.velocity = _my_state.velocity.lerp(server_vel, RECONCILE_BLEND)
	_my_state.heading = lerp_angle(_my_state.heading, packed[2], RECONCILE_BLEND)
