class_name ClientMain
extends Node3D
## Client entry point: connects to the server, sends intents, predicts the
## local ship with the same sim/ code, and renders snapshots (ADR-002).
## Pass "-- --server=<host>" on the command line to join a remote server.

const SHIP_SCENE: PackedScene = preload("res://client/scenes/ship.tscn")
const DEFAULT_SERVER_ADDRESS: String = "127.0.0.1"

var _hull: HullDef = null
var _my_entity_id: int = 0
var _my_state: ShipState = null
var _my_intent: ShipIntent = ShipIntent.new()
var _views: Dictionary[int, ShipView] = {}
var _got_first_snapshot: bool = false
var _autopilot: AutopilotParams = null
var _reconcile_blend: float = 0.0
var _snap_correction_dist: float = 0.0
var _goto_active: bool = false
var _goto_target: Vector2 = Vector2.ZERO

@onready var _camera: IsoCamera = $IsoCamera
@onready var _goto_marker: Node3D = $GotoMarker
@onready var _rpc: RpcSurface = $Rpc


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
	_reconcile_blend = Tuning.value_f("net.reconcile_blend")
	_snap_correction_dist = Tuning.value_f("net.snap_correction_dist")
	_rpc.welcomed.connect(_on_welcomed)
	_rpc.snapshot_received.connect(_on_snapshot_received)
	$Sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	_connect_to_server(_server_address())


func _physics_process(delta: float) -> void:
	if _my_state == null:
		return
	_my_intent = _resolve_intent()
	_rpc.submit_intent.rpc_id(1, _my_intent.thrust, _my_intent.turn)
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
	if not _views.has(_my_entity_id):
		return
	# The predicted state updates at the 20 Hz sim tick; render through the
	# view's blend (and follow the blended view with the camera) so the local
	# ship stays smooth at any display rate.
	var view: ShipView = _views[_my_entity_id]
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
	_my_entity_id = 0
	_my_state = null
	_got_first_snapshot = false
	for view: ShipView in _views.values():
		view.queue_free()
	_views.clear()


func _on_welcomed(payload: Dictionary) -> void:
	_my_entity_id = int(payload["entity_id"])
	Log.info("net", "welcomed", {"entity_id": _my_entity_id})


func _on_snapshot_received(_tick_num: int, ships: Dictionary) -> void:
	if _my_entity_id == 0:
		return  # Snapshots ride an unreliable channel and can beat the welcome.
	if not _got_first_snapshot:
		_got_first_snapshot = true
		Log.info("net", "first snapshot received", {"ships": ships.size()})
	for entity_id: int in ships:
		var state: ShipState = ShipState.unpack(ships[entity_id])
		if state == null:
			continue
		_ensure_view(entity_id, state)
		if entity_id == _my_entity_id:
			_reconcile_local(state)
		else:
			_views[entity_id].set_target(state.position, state.heading)
	for entity_id: int in _views.keys():
		if not ships.has(entity_id):
			_views[entity_id].queue_free()
			_views.erase(entity_id)


func _ensure_view(entity_id: int, state: ShipState) -> void:
	if _views.has(entity_id):
		return
	var view: ShipView = SHIP_SCENE.instantiate()
	view.name = "Ship%d" % entity_id
	add_child(view)
	view.set_immediate(state.position, state.heading)
	_views[entity_id] = view
	Log.info("net", "ship view created", {
		"entity": entity_id, "remote": entity_id != _my_entity_id
	})
	if entity_id == _my_entity_id and _my_state == null:
		_my_state = Entities.make_ship_state(state.position)
		_my_state.heading = state.heading


## M0 reconciliation: blend gently toward the authoritative state, snap on
## large error. Full rewind-and-replay is an M1+ item (networking wiki page).
func _reconcile_local(server_state: ShipState) -> void:
	if _my_state.position.distance_to(server_state.position) > _snap_correction_dist:
		_my_state.position = server_state.position
		_my_state.velocity = server_state.velocity
		_my_state.heading = server_state.heading
		return
	_my_state.position = _my_state.position.lerp(server_state.position, _reconcile_blend)
	_my_state.velocity = _my_state.velocity.lerp(server_state.velocity, _reconcile_blend)
	_my_state.heading = lerp_angle(_my_state.heading, server_state.heading, _reconcile_blend)
