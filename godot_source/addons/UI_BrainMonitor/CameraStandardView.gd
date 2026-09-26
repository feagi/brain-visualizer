extends RefCounted
## Fixed Brain Monitor camera angles for T, B, F, L, and R.
## Directions are Godot world axes. FEAGI +Z is Godot -Z, so top and bottom keep that axis at the top of the screen.
## Front sits on +Z. Left sits on -X. Right sits on +X.


enum VIEW { TOP, BOTTOM, FRONT, LEFT, RIGHT }

const _NO_VIEW: int = -1


static func view_from_key(
	keycode: Key,
	physical_keycode: Key,
	pressed: bool,
	echo: bool,
	ctrl_or_meta: bool,
	alt: bool,
	shift: bool,
) -> int:
	if not pressed or echo or ctrl_or_meta or alt or shift:
		return _NO_VIEW
	if _is_view_key(keycode, KEY_T) or _is_view_key(physical_keycode, KEY_T):
		return VIEW.TOP
	if _is_view_key(keycode, KEY_B) or _is_view_key(physical_keycode, KEY_B):
		return VIEW.BOTTOM
	if _is_view_key(keycode, KEY_F) or _is_view_key(physical_keycode, KEY_F):
		return VIEW.FRONT
	if _is_view_key(keycode, KEY_L) or _is_view_key(physical_keycode, KEY_L):
		return VIEW.LEFT
	if _is_view_key(keycode, KEY_R) or _is_view_key(physical_keycode, KEY_R):
		return VIEW.RIGHT
	return _NO_VIEW


static func orientation(view_id: int) -> Dictionary:
	match view_id:
		VIEW.TOP:
			return {&"view_dir": Vector3(0, 1, 0), &"up": Vector3(0, 0, -1)}
		VIEW.BOTTOM:
			return {&"view_dir": Vector3(0, -1, 0), &"up": Vector3(0, 0, -1)}
		VIEW.FRONT:
			return {&"view_dir": Vector3(0, 0, 1), &"up": Vector3.UP}
		VIEW.LEFT:
			return {&"view_dir": Vector3(-1, 0, 0), &"up": Vector3.UP}
		VIEW.RIGHT:
			return {&"view_dir": Vector3(1, 0, 0), &"up": Vector3.UP}
		_:
			return {}


## Camera position for a view that looks at [param center] from [param distance] away.
## [param view_id] must be a [enum VIEW] value.
static func camera_position(center: Vector3, distance: float, view_id: int) -> Vector3:
	var orient: Dictionary = orientation(view_id)
	return center + (orient[&"view_dir"] as Vector3) * distance


static func _is_view_key(pressed_key: Key, view_key: Key) -> bool:
	return pressed_key == view_key
