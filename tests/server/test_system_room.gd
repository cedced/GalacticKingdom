extends GutTest
## Authoritative room behavior: spawn spread and the intent dead-man's switch.

const DT: float = 0.05

var _room: SystemRoom


func before_each() -> void:
	Tuning.load_data()
	_room = SystemRoom.new()
	add_child_autofree(_room)


func test_many_spawns_do_not_stack() -> void:
	# Regression: a quarter-turn spawn step put the 5th ship exactly on the 1st.
	var positions: Array[Vector2] = []
	for entity_id: int in range(1, 13):
		_room.add_ship(entity_id)
		positions.append(_room.ship_position(entity_id))
	for i: int in positions.size():
		for j: int in range(i + 1, positions.size()):
			assert_gt(
				positions[i].distance_to(positions[j]), 0.5,
				"ships %d and %d spawned on top of each other" % [i + 1, j + 1]
			)


func test_fresh_intent_moves_ship() -> void:
	_room.add_ship(1)
	_room.set_intent(1, 1.0, 0.0)
	_room.step(DT)
	var state: ShipState = ShipState.unpack(_room.snapshot()[1])
	assert_lt(state.velocity.y, 0.0, "full thrust must produce -z velocity")


func test_stale_intent_times_out() -> void:
	# Regression: a frozen client's last intent used to replay forever.
	_room.add_ship(1)
	_room.set_intent(1, 1.0, 0.0)
	var timeout_ticks: int = int(ceil(
		Tuning.value_f("net.intent_timeout_ms") / 1000.0 * float(Tuning.value_i("net.tick_hz"))
	))
	for _i: int in timeout_ticks + 1:
		_room.step(DT)
	var speed_at_timeout: float = _snapshot_speed(1)
	assert_gt(speed_at_timeout, 0.0, "ship should have accelerated before the timeout")
	for _i: int in 10:
		_room.step(DT)
	assert_lt(_snapshot_speed(1), speed_at_timeout, "thrust must stop once the intent is stale")


func test_new_intent_resets_the_timeout() -> void:
	_room.add_ship(1)
	for _i: int in 100:
		_room.set_intent(1, 1.0, 0.0)
		_room.step(DT)
	assert_gt(_snapshot_speed(1), 1.0, "a live client must keep thrusting")


func _snapshot_speed(entity_id: int) -> float:
	var state: ShipState = ShipState.unpack(_room.snapshot()[entity_id])
	return state.velocity.length()
