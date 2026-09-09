class_name Iso
extends RefCounted
## Pure isometric projection math (wiki/systems/rendering.md). Kept free of
## viewport/node access so tests can run it headless; IsoCamera wraps these
## with the live camera's values.


static func camera_basis(pitch_deg: float, yaw_deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Basis(Vector3.RIGHT, deg_to_rad(-pitch_deg))


## Orthographic projection of a world point to screen pixels. ortho_size is
## the camera's vertical extent (Godot Camera3D "size" with keep_height).
static func world_to_screen(
	world: Vector3, cam_transform: Transform3D, ortho_size: float, viewport: Vector2
) -> Vector2:
	var local: Vector3 = cam_transform.affine_inverse() * world
	var width: float = ortho_size * viewport.x / viewport.y
	var sx: float = (local.x / width + 0.5) * viewport.x
	var sy: float = (0.5 - local.y / ortho_size) * viewport.y
	return Vector2(sx, sy)


## Ray from a screen pixel through the ortho view, intersected with the XZ
## gameplay plane (y == 0). Returns the XZ hit point.
static func screen_to_world_plane(
	screen: Vector2, cam_transform: Transform3D, ortho_size: float, viewport: Vector2
) -> Vector2:
	var width: float = ortho_size * viewport.x / viewport.y
	var local_x: float = (screen.x / viewport.x - 0.5) * width
	var local_y: float = (0.5 - screen.y / viewport.y) * ortho_size
	var origin: Vector3 = cam_transform * Vector3(local_x, local_y, 0.0)
	var direction: Vector3 = -cam_transform.basis.z
	if is_zero_approx(direction.y):
		return Vector2(origin.x, origin.z)
	var t: float = -origin.y / direction.y
	var hit: Vector3 = origin + direction * t
	return Vector2(hit.x, hit.z)
