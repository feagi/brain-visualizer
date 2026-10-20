extends RefCounted
## Hover draws a cortical area's mapping lines.
## Shift keeps that area's lines after the pointer leaves, and shows a count button on each line.


## True when this area should draw its incoming and outgoing mapping lines.
## [param area_pinned] stays true while Shift is holding the lines from this area.
static func should_show_connections(volume_hovered: bool, area_pinned: bool) -> bool:
	return volume_hovered or area_pinned


## Count buttons are drawn on lines that are already visible, and only while Shift is held.
static func should_show_count_buttons(connections_visible: bool, shift_held: bool) -> bool:
	return connections_visible and shift_held


## The area whose lines stay up for as long as Shift is held.
## Pressing Shift pins the area under the pointer. A later hover does not replace that pin.
## Hovering while Shift is already held pins that area when nothing is pinned yet.
static func next_pinned_cortical_id(
	hovered_cortical_id: StringName,
	current_pinned_id: StringName,
	shift_held: bool,
	shift_just_pressed: bool
) -> StringName:
	if not shift_held:
		return &""
	if shift_just_pressed:
		return hovered_cortical_id
	if current_pinned_id != &"":
		return current_pinned_id
	return hovered_cortical_id


## Point halfway along the same upward arc the mapping line uses.
static func curve_midpoint(start_pos: Vector3, end_pos: Vector3, arc_height_multiplier: float = 0.4) -> Vector3:
	var distance := start_pos.distance_to(end_pos)
	var control := (start_pos + end_pos) * 0.5 + Vector3(0.0, distance * arc_height_multiplier, 0.0)
	return quadratic_bezier(start_pos, control, end_pos, 0.5)


## Center of a self-mapping loop, where the count button sits.
static func loop_anchor(center: Vector3, loop_height: float) -> Vector3:
	return center + Vector3(0.0, loop_height, 0.0)


## Button label used by Circuit Builder connection lines.
static func count_button_label(mapping_count: int) -> String:
	return "  %d  " % mapping_count


static func quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2
