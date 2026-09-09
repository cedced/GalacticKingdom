extends GutTest
## Loading immutable definitions from data/ must work headless
## (wiki/systems/ships.md test plan).


func test_merchant_mk1_loads_from_data() -> void:
	var hull: HullDef = Entities.load_hull("merchant_mk1")
	assert_not_null(hull)
	assert_eq(hull.id, "merchant_mk1")
	assert_eq(hull.model, "res://assets/ships/merchant_mk1/merchant_mk1.glb")
	assert_gt(hull.accel, 0.0)
	assert_gt(hull.max_speed, 0.0)
	assert_gt(hull.turn_rate_deg, 0.0)
	assert_gt(hull.cargo_slots, 0)


func test_hull_model_file_exists() -> void:
	var hull: HullDef = Entities.load_hull("merchant_mk1")
	assert_true(
		ResourceLoader.exists(hull.model), "hull model missing on disk: %s" % hull.model
	)


func test_make_ship_state_uses_spawn_position() -> void:
	var state: ShipState = Entities.make_ship_state(Vector2(3.0, -2.0))
	assert_eq(state.position, Vector2(3.0, -2.0))
	assert_eq(state.velocity, Vector2.ZERO)
