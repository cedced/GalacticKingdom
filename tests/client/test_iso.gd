extends GutTest
## wiki/systems/rendering.md test plan: world_to_screen and
## screen_to_world_plane are inverses on the XZ plane.

const VIEWPORT: Vector2 = Vector2(1280.0, 720.0)
const ORTHO_SIZE: float = 18.0


func _iso_transform() -> Transform3D:
	var basis: Basis = Iso.camera_basis(30.0, 45.0)
	var origin: Vector3 = basis * Vector3(0.0, 0.0, 60.0)
	return Transform3D(basis, origin)


func test_round_trip_on_xz_plane() -> void:
	var cam: Transform3D = _iso_transform()
	var samples: Array[Vector2] = [
		Vector2.ZERO,
		Vector2(5.0, 3.0),
		Vector2(-7.5, 2.25),
		Vector2(10.0, -10.0),
		Vector2(-0.1, 0.7),
	]
	for point: Vector2 in samples:
		var world: Vector3 = Vector3(point.x, 0.0, point.y)
		var screen: Vector2 = Iso.world_to_screen(world, cam, ORTHO_SIZE, VIEWPORT)
		var back: Vector2 = Iso.screen_to_world_plane(screen, cam, ORTHO_SIZE, VIEWPORT)
		assert_almost_eq(back.x, point.x, 0.001, "x round trip for %s" % point)
		assert_almost_eq(back.y, point.y, 0.001, "z round trip for %s" % point)


func test_world_origin_under_centered_camera_hits_screen_center() -> void:
	var cam: Transform3D = _iso_transform()
	var screen: Vector2 = Iso.world_to_screen(Vector3.ZERO, cam, ORTHO_SIZE, VIEWPORT)
	assert_almost_eq(screen.x, VIEWPORT.x / 2.0, 0.001)
	assert_almost_eq(screen.y, VIEWPORT.y / 2.0, 0.001)


func test_camera_basis_never_rolls() -> void:
	# The iso camera pitches and yaws but must keep the horizon level.
	var basis: Basis = Iso.camera_basis(30.0, 45.0)
	assert_almost_eq((basis * Vector3.RIGHT).y, 0.0, 0.0001)
