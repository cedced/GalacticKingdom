extends SceneTree
## Headless end-to-end check of the M1 loop: connect, receive the welcome,
## regenerate the galaxy from the seed, autopilot to the nearest warp gate
## using the real sim/ code, and jump. Prints "JUMP_BOT OK" on success.
## Run against a live server:
##   godot --headless --path . -s tools/jump_bot.gd -- --server=127.0.0.1
## CI uses this to prove a fresh client can actually leave the home system.

const TIMEOUT_S: float = 30.0

var _rpc: RpcSurface = null
var _hull: HullDef = null
var _autopilot: AutopilotParams = null
var _galaxy: GalaxyData = null
var _entity_id: int = 0
var _system_id: int = -1
var _start_system_id: int = -1
var _gate: WarpGate = null
var _gate_radius: float = 0.0
var _jump_sent: bool = false
var _started_at: float = 0.0


func _init() -> void:
	if not Tuning.load_data():
		_fail("tuning failed to load")
		return
	Engine.physics_ticks_per_second = Tuning.value_i("net.tick_hz")
	_hull = Entities.load_hull(str(Tuning.value("world.starter_hull_id")))
	_autopilot = AutopilotParams.from_tuning()
	_gate_radius = Tuning.value_f("warp.gate_radius")
	_started_at = Time.get_ticks_msec() / 1000.0
	# The RPC surface must sit at the same path as in both real scenes.
	var main: Node = Node.new()
	main.name = "Main"
	_rpc = RpcSurface.new()
	_rpc.name = "Rpc"
	main.add_child(_rpc)
	root.add_child.call_deferred(main)
	_rpc.welcomed.connect(_on_welcomed)
	_rpc.snapshot_received.connect(_on_snapshot)
	_rpc.jumped.connect(_on_jumped)
	_rpc.jump_denied.connect(func(reason: String, _fuel: float) -> void:
		print("jump_bot: denied: %s" % reason)
		_jump_sent = false)
	physics_frame.connect(_on_physics_frame)
	var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	peer.create_client(_arg("server", "127.0.0.1"), Tuning.value_i("net.port"))
	get_multiplayer().multiplayer_peer = peer


func _on_welcomed(payload: Dictionary) -> void:
	_entity_id = int(payload["entity_id"])
	_system_id = int(payload["system_id"])
	_start_system_id = _system_id
	_galaxy = Galaxy.generate(int(payload["galaxy_seed"]), GalaxyParams.from_tuning())
	_gate = _galaxy.system(_system_id).gates[0]
	print("jump_bot: welcomed in %s, flying to the %s gate" % [
		_galaxy.system(_system_id).name,
		_galaxy.system(_gate.to_system_id).name,
	])


func _on_snapshot(_tick: int, ships: Dictionary) -> void:
	if _gate == null or _jump_sent or not ships.has(_entity_id):
		return
	var state: ShipState = ShipState.unpack(ships[_entity_id])
	if state == null:
		return
	if state.position.distance_to(_gate.position) <= _gate_radius * 0.8:
		_jump_sent = true
		_rpc.request_jump.rpc_id(1, _gate.to_system_id)
		return
	var intent: ShipIntent = Motion.autopilot_intent(state, _hull, _gate.position, _autopilot)
	_rpc.submit_intent.rpc_id(1, intent.thrust, intent.turn)


func _on_jumped(system_id: int, fuel: float) -> void:
	if system_id == _gate.to_system_id and system_id != _start_system_id:
		print("JUMP_BOT OK: jumped %s -> %s, fuel left %.1f" % [
			_galaxy.system(_start_system_id).name, _galaxy.system(system_id).name, fuel,
		])
		quit(0)
	else:
		_fail("landed in system %d, expected %d" % [system_id, _gate.to_system_id])


func _on_physics_frame() -> void:
	if Time.get_ticks_msec() / 1000.0 - _started_at > TIMEOUT_S:
		_fail("timed out")


func _fail(reason: String) -> void:
	print("JUMP_BOT FAIL: %s" % reason)
	quit(1)


func _arg(name: String, fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback
