extends RefCounted
class_name UI_BrainMonitor_BoxSelect
## Screen-space box selection for Brain Monitor cortical areas.
## Shift+left-drag draws a rectangle; areas whose projected volume intersects it are selected.
## A Shift+click that never exceeds [constant MIN_DRAG_DISTANCE] is not a box select
## (voxel toggle on the cortical volume stays on click).


const MIN_DRAG_DISTANCE: float = 2.0

enum PHASE {
	IDLE,
	PRESSING,
	DRAGGING,
}

var phase: PHASE = PHASE.IDLE
var start_screen: Vector2 = Vector2.ZERO
var current_screen: Vector2 = Vector2.ZERO


func is_active() -> bool:
	return phase != PHASE.IDLE


func is_dragging() -> bool:
	return phase == PHASE.DRAGGING


func begin_press(screen_pos: Vector2) -> void:
	phase = PHASE.PRESSING
	start_screen = screen_pos
	current_screen = screen_pos


func update_pointer(screen_pos: Vector2) -> void:
	if phase == PHASE.IDLE:
		return
	current_screen = screen_pos
	if phase == PHASE.PRESSING and is_drag_distance(start_screen, current_screen, MIN_DRAG_DISTANCE):
		phase = PHASE.DRAGGING


func get_screen_rect() -> Rect2:
	return normalized_rect(start_screen, current_screen)


## Ends the gesture and returns the phase that was active. Session returns to IDLE.
func finish() -> PHASE:
	var ended_phase: PHASE = phase
	reset()
	return ended_phase


func reset() -> void:
	phase = PHASE.IDLE
	start_screen = Vector2.ZERO
	current_screen = Vector2.ZERO


static func is_drag_distance(start_pos: Vector2, end_pos: Vector2, min_distance: float) -> bool:
	return start_pos.distance_to(end_pos) >= min_distance


static func normalized_rect(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(a, b - a).abs()


static func screen_bounds_from_points(points: Array[Vector2]) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
	for i in range(1, points.size()):
		bounds = bounds.expand(points[i])
	return bounds


## True when the area's projected bounds overlap a selection rectangle with positive area.
static func screen_bounds_overlap_selection(area_bounds: Rect2, selection: Rect2) -> bool:
	if selection.size.x <= 0.0 or selection.size.y <= 0.0:
		return false
	if area_bounds.size == Vector2.ZERO:
		return selection.has_point(area_bounds.position)
	return area_bounds.intersects(selection)


## Projects AABB corners that are in front of the camera.
## [param is_position_behind] and [param unproject_position] take a Vector3.
static func project_aabb_corners(
	aabb: AABB,
	is_position_behind: Callable,
	unproject_position: Callable,
) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for i in 8:
		var corner: Vector3 = aabb.get_endpoint(i)
		if is_position_behind.call(corner):
			continue
		points.append(unproject_position.call(corner))
	return points


## [param entries] items are Dictionaries with keys `object` and `bounds` (Rect2).
static func collect_overlapping_objects(entries: Array, selection: Rect2) -> Array:
	var selected: Array = []
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var bounds: Rect2 = entry.get(&"bounds", Rect2())
		if screen_bounds_overlap_selection(bounds, selection):
			selected.append(entry.get(&"object"))
	return selected
