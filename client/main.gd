class_name ClientMain
extends Node3D
## Client entry point: connects to the server, sends intents, predicts the
## local ship with the same sim/ code, and renders snapshots (ADR-002). The
## whole galaxy is regenerated locally from the seed in the server's welcome.
## Pass "-- --server=<host>" on the command line to join a remote server.

const SHIP_SCENE: PackedScene = preload("res://client/scenes/ship.tscn")
const DEFAULT_SERVER_ADDRESS: String = "127.0.0.1"
## Enter-mode contact messages until the real actions exist.
const TOUCH_HINTS: Dictionary[String, String] = {
	"station": "Docking arrives with M2",
	"planet": "Landing arrives with M4",
	"derelict": "Boarding derelicts arrives with M4",
}

var _hull: HullDef = null
var _my_entity_id: int = 0
var _my_state: ShipState = null
var _my_intent: ShipIntent = ShipIntent.new()
var _views: Dictionary[int, ShipView] = {}
var _got_first_snapshot: bool = false
var _autopilot: AutopilotParams = null
var _reconcile_blend: float = 0.0
var _snap_correction_dist: float = 0.0
var _gate_radius: float = 0.0
var _ship_radius: float = 0.0
## Enter/boarding mode (wiki/Glossary.md): planets and stations stop being
## walls, and touching a gate jumps without pressing J. Toggled with E.
var _enter_mode: bool = false
var _obstacles: Array[Obstacle] = []
var _touching: Obstacle = null
var _auto_jump_ready_at: float = 0.0
var _goto_active: bool = false
var _goto_target: Vector2 = Vector2.ZERO
## Debug: "-- --screenshot=<path>" saves a frame shortly after the first
## snapshot and quits. Lets tooling eyeball the rendered scene.
var _screenshot_path: String = ""
var _screenshot_frames_left: int = 90

var _galaxy: GalaxyData = null
var _system_id: int = -1
## Authoritative fuel as of _fuel_updated_at; displayed with local accrual.
var _fuel: float = 0.0
var _fuel_updated_at: float = 0.0
var _fuel_cap: float = 0.0
var _fuel_per_minute: float = 0.0
var _jump_cost: float = 0.0

@onready var _camera: IsoCamera = $IsoCamera
@onready var _goto_marker: Node3D = $GotoMarker
@onready var _rpc: RpcSurface = $Rpc
@onready var _system_view: SystemView = $SystemView
@onready var _hud: Hud = $UI/Hud
@onready var _map: GalaxyMap = $UI/GalaxyMap
@onready var _world_labels: WorldLabels = $UI/WorldLabels


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
	_gate_radius = Tuning.value_f("warp.gate_radius")
	_ship_radius = Tuning.value_f("collision.ship_radius")
	_rpc.welcomed.connect(_on_welcomed)
	_rpc.snapshot_received.connect(_on_snapshot_received)
	_rpc.jumped.connect(_on_jumped)
	_rpc.jump_denied.connect(_on_jump_denied)
	_world_labels.setup(_camera)
	$Sun.rotation_degrees = Vector3(-50.0, -30.0, 0.0)
	_screenshot_path = _user_arg("screenshot", "")
	_connect_to_server(_server_address())


func _physics_process(delta: float) -> void:
	if _my_state == null:
		return
	_my_intent = _resolve_intent()
	_my_intent.enter = _enter_mode
	_rpc.submit_intent.rpc_id(1, _my_intent.thrust, _my_intent.turn, _my_intent.enter)
	# Prediction: same integrator and walls the server runs
	# (wiki/systems/networking.md) — unpredicted walls would rubber-band.
	Motion.step(_my_state, _my_intent, _hull, delta)
	_touching = Motion.resolve_obstacles(_my_state, _obstacles, _ship_radius, _enter_mode)
	_maybe_auto_jump()


## Enter mode's gate behavior (wiki/Glossary.md): flying into a gate jumps
## without pressing J. Throttled so a denial does not spam the server.
func _maybe_auto_jump() -> void:
	if not _enter_mode or _nearest_gate_in_range() == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now < _auto_jump_ready_at:
		return
	_auto_jump_ready_at = now + 2.0
	_try_jump()


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
	if event.is_action_pressed("toggle_map"):
		_map.visible = not _map.visible
		return
	if event.is_action_pressed("jump"):
		_try_jump()
		return
	if event.is_action_pressed("toggle_enter_mode"):
		_enter_mode = not _enter_mode
		_hud.set_boarding(_enter_mode)
		return
	if event.is_action_pressed("go_to") and _my_state != null:
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
	if _galaxy != null:
		var fuel: float = _displayed_fuel()
		_hud.set_fuel(fuel, _fuel_cap)
		if _map.visible:
			_map.set_fuel_info(fuel, _jump_cost)
	_update_gate_hint()
	_maybe_take_screenshot()
	if _my_state == null or not _views.has(_my_entity_id):
		return
	# The predicted state updates at the 20 Hz sim tick; render through the
	# view's blend (and follow the blended view with the camera) so the local
	# ship stays smooth at any display rate.
	var view: ShipView = _views[_my_entity_id]
	view.set_target(_my_state.position, _my_state.heading)
	_camera.set_target(Vector3(view.position.x, 0.0, view.position.z))


## The server only reports fuel on change; between reports the client runs
## the same accrual math for display. Never trusted for a jump — the server
## re-derives fuel itself (ADR-002).
func _displayed_fuel() -> float:
	var elapsed: float = Time.get_unix_time_from_system() - _fuel_updated_at
	return Galaxy.accrued_fuel(_fuel, _fuel_cap, _fuel_per_minute, elapsed)


func _maybe_take_screenshot() -> void:
	if _screenshot_path == "" or not _got_first_snapshot:
		return
	_screenshot_frames_left -= 1
	if _screenshot_frames_left > 0:
		return
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(_screenshot_path)
	Log.info("client", "screenshot saved", {"path": _screenshot_path})
	_screenshot_path = ""
	get_tree().quit()


func _update_gate_hint() -> void:
	var gate: WarpGate = _nearest_gate_in_range()
	if gate != null:
		var how: String = "In the gate — jumping" if _enter_mode else "J: jump"
		_hud.set_hint("%s to %s  (%.0f fuel)" % [
			how, _galaxy.system(gate.to_system_id).name, _jump_cost,
		])
		return
	if _touching != null:
		_hud.set_hint(TOUCH_HINTS.get(_touching.kind, ""))
		return
	_hud.set_hint("")


func _nearest_gate_in_range() -> WarpGate:
	if _galaxy == null or _my_state == null or _system_id < 0:
		return null
	var best: WarpGate = null
	var best_dist: float = _gate_radius
	for gate: WarpGate in _galaxy.system(_system_id).gates:
		var dist: float = _my_state.position.distance_to(gate.position)
		if dist <= best_dist:
			best_dist = dist
			best = gate
	return best


func _try_jump() -> void:
	var gate: WarpGate = _nearest_gate_in_range()
	if gate == null:
		_hud.show_message("No warp gate in range")
		return
	_rpc.request_jump.rpc_id(1, gate.to_system_id)


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
	return _user_arg("server", DEFAULT_SERVER_ADDRESS)


func _user_arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _on_connected() -> void:
	Log.info("net", "connected", {"peer_id": multiplayer.get_unique_id()})


func _on_connection_failed() -> void:
	Log.error("net", "connection failed", {})


func _on_server_disconnected() -> void:
	Log.warn("net", "server disconnected", {})
	_my_entity_id = 0
	_my_state = null
	_got_first_snapshot = false
	_clear_views()


func _on_welcomed(payload: Dictionary) -> void:
	_my_entity_id = int(payload["entity_id"])
	_fuel = float(payload["fuel"])
	_fuel_cap = float(payload["fuel_cap"])
	_fuel_per_minute = float(payload["fuel_per_minute"])
	_jump_cost = float(payload["jump_cost"])
	_fuel_updated_at = Time.get_unix_time_from_system()
	# Deterministic generation: the seed is the entire map download.
	_galaxy = Galaxy.generate(int(payload["galaxy_seed"]), GalaxyParams.from_tuning())
	_map.setup(_galaxy)
	_enter_system(int(payload["system_id"]))
	Log.info("net", "welcomed", {
		"entity_id": _my_entity_id, "system": _system_id, "fuel": _fuel,
	})


func _on_jumped(system_id: int, fuel: float) -> void:
	_fuel = fuel
	_fuel_updated_at = Time.get_unix_time_from_system()
	# Drop stale views and prediction; the new room's first snapshot rebuilds
	# them at the arrival gate.
	_clear_views()
	_my_state = null
	_enter_system(system_id)
	Log.info("net", "jumped", {"system": system_id, "fuel": fuel})


func _on_jump_denied(reason: String, fuel: float) -> void:
	_fuel = fuel
	_fuel_updated_at = Time.get_unix_time_from_system()
	_hud.show_message("Jump denied: %s" % reason)


func _enter_system(system_id: int) -> void:
	_system_id = system_id
	_clear_goto()
	var system: StarSystem = _galaxy.system(system_id)
	_obstacles = Galaxy.system_obstacles(
		system,
		Tuning.value_f("collision.sun_radius"),
		Tuning.value_f("collision.station_radius")
	)
	_touching = null
	_system_view.rebuild(system)
	var labels: Array[Dictionary] = []
	for gate: WarpGate in system.gates:
		labels.append({
			"text": _galaxy.system(gate.to_system_id).name,
			"world": gate.position,
			"clear": 1.4,
		})
	for station: SystemStation in system.stations:
		var quad: float = (
			SystemView.STARBASE_QUAD_SIZE if station.kind == "starbase"
			else SystemView.PORT_QUAD_SIZE
		)
		labels.append({
			"text": str(station.kind), "world": station.position, "clear": quad * 0.55,
		})
	_world_labels.set_labels(labels)
	_hud.set_system(system)
	_map.set_current(system_id)


func _clear_views() -> void:
	for view: ShipView in _views.values():
		view.queue_free()
	_views.clear()


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
