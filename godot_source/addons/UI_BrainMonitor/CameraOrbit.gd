extends RefCounted
## Turntable orbit for the Brain Monitor camera.
## The whole camera transform turns around a fixed pivot, so the pivot keeps its place on screen and the distance to it does not change.
## Yaw turns around world up. Pitch turns around the camera's right axis and is clamped so the view never flips over the pole.


## Largest tilt of the view above or below the horizon, in radians. Stops short of straight up or down so the right axis stays defined.
const MAX_PITCH: float = deg_to_rad(89.0)


## True when this mouse press starts an orbit: middle button, or Option/Alt with the left button.
static func is_orbit_press(button_index: MouseButton, alt_held: bool) -> bool:
	if button_index == MOUSE_BUTTON_MIDDLE:
		return true
	return button_index == MOUSE_BUTTON_LEFT and alt_held


## Tilt of the view direction above the horizon, in radians. Positive looks up.
static func view_pitch(camera_basis: Basis) -> float:
	var forward: Vector3 = -camera_basis.z.normalized()
	return asin(clampf(forward.y, -1.0, 1.0))


## Camera transform after orbiting [param camera_transform] around [param pivot].
## [param yaw_delta] turns around world up. [param pitch_delta] tilts the view, positive looking further up.
static func orbit_transform(pivot: Vector3, camera_transform: Transform3D, yaw_delta: float, pitch_delta: float) -> Transform3D:
	var result: Transform3D = _rotate_about(pivot, camera_transform, Vector3.UP, yaw_delta)
	var current_pitch: float = view_pitch(result.basis)
	var allowed_pitch_delta: float = clampf(current_pitch + pitch_delta, -MAX_PITCH, MAX_PITCH) - current_pitch
	var right_axis: Vector3 = result.basis.x.normalized()
	return _rotate_about(pivot, result, right_axis, allowed_pitch_delta)


## Picks the orbit pivot when a drag starts, in this order:
## the center of the selected areas, the point under the screen center, then the center of the visible brain.
## Returns {&"found": bool, &"pivot": Vector3}. [param center_hit] is a physics ray result and may be empty.
static func choose_pivot(selection_aabb: AABB, center_hit: Dictionary, scene_aabb: AABB) -> Dictionary:
	if _is_usable(selection_aabb):
		return {&"found": true, &"pivot": selection_aabb.get_center()}
	if center_hit.has(&"position"):
		return {&"found": true, &"pivot": center_hit[&"position"] as Vector3}
	if _is_usable(scene_aabb):
		return {&"found": true, &"pivot": scene_aabb.get_center()}
	return {&"found": false, &"pivot": Vector3.ZERO}


## Free tumble around [param pivot]. Yaw turns about the camera's up axis. Pitch turns about its right axis and is not clamped, so the view can pass over the poles and continue.
static func tumble_transform(pivot: Vector3, camera_transform: Transform3D, yaw_delta: float, pitch_delta: float) -> Transform3D:
	var up_axis: Vector3 = camera_transform.basis.y.normalized()
	var result: Transform3D = _rotate_about(pivot, camera_transform, up_axis, yaw_delta)
	var right_axis: Vector3 = result.basis.x.normalized()
	return _rotate_about(pivot, result, right_axis, pitch_delta)


## Roll about the view axis through [param pivot]. The camera stays on that axis and the horizon twists.
static func roll_transform(pivot: Vector3, camera_transform: Transform3D, roll_delta: float) -> Transform3D:
	var view_axis: Vector3 = -camera_transform.basis.z.normalized()
	return _rotate_about(pivot, camera_transform, view_axis, roll_delta)


static func _rotate_about(pivot: Vector3, xform: Transform3D, axis: Vector3, angle: float) -> Transform3D:
	if is_zero_approx(angle) or axis.is_zero_approx():
		return xform
	var turn: Basis = Basis(axis, angle)
	return Transform3D(turn * xform.basis, pivot + turn * (xform.origin - pivot))


static func _is_usable(aabb: AABB) -> bool:
	return aabb.size != Vector3.ZERO and (aabb.size.x + aabb.size.y + aabb.size.z) >= 0.01
