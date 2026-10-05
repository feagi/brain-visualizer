extends RefCounted
## Gesture and camera pivot for the floating single-area inspect view.
## Shift+Ctrl+click (Shift+Command+click on macOS) opens it. The camera reports Command as Ctrl before this runs.


## True for a still Shift+Ctrl/Command click on a cortical area. A drag stays box-select.
## [param button_is_secondary] covers macOS, where Godot delivers Control+left click as the right button
## while [param ctrl_pressed] stays true. A right click without Ctrl is not this gesture.
static func is_open_gesture(ctrl_pressed: bool, shift_pressed: bool, button_is_main: bool, button_is_secondary: bool, button_pressed: bool, was_dragging: bool) -> bool:
	var click_button: bool = button_is_main or (button_is_secondary and ctrl_pressed)
	return ctrl_pressed and shift_pressed and click_button and button_pressed and not was_dragging


## Top-left of the floating view at the click, shifted only enough to stay inside the viewport and below [param min_top].
static func top_left_for_click(click: Vector2, window_size: Vector2, viewport_rect: Rect2, min_top: float) -> Vector2:
	var pos := click
	if min_top > 0.0:
		pos.y = maxf(pos.y, min_top)
	if pos.x + window_size.x > viewport_rect.end.x:
		pos.x = viewport_rect.end.x - window_size.x
	if pos.y + window_size.y > viewport_rect.end.y:
		pos.y = viewport_rect.end.y - window_size.y
	pos.x = maxf(pos.x, viewport_rect.position.x)
	pos.y = maxf(pos.y, viewport_rect.position.y)
	return pos


## Size after a bottom-right drag. Never smaller than [param min_size].
static func resized_size(start_size: Vector2, delta: Vector2, min_size: Vector2) -> Vector2:
	return Vector2(maxf(start_size.x + delta.x, min_size.x), maxf(start_size.y + delta.y, min_size.y))


## Orbit pivot locked to the single area. Ignores selection and whatever sits under the screen center.
static func pivot_for_area(area_aabb: AABB) -> Dictionary:
	if area_aabb.size == Vector3.ZERO or (area_aabb.size.x + area_aabb.size.y + area_aabb.size.z) < 0.01:
		return {&"found": false, &"pivot": Vector3.ZERO}
	return {&"found": true, &"pivot": area_aabb.get_center()}
