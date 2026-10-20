extends SceneTree
## Shift keeps hovered mapping lines and places a count at the middle of each line.
## Run: godot --headless --path godot_source -s res://addons/UI_BrainMonitor/test_mapping_hover_hold.gd

const Hold = preload("res://addons/UI_BrainMonitor/UI_BrainMonitor_MappingHoverHold.gd")


func _initialize() -> void:
	var failures := 0
	failures += _test_hover_shows_lines_until_the_pointer_leaves()
	failures += _test_shift_keeps_the_pinned_area_after_the_pointer_leaves()
	failures += _test_shift_pins_the_area_under_the_pointer()
	failures += _test_shift_does_not_replace_the_pinned_area()
	failures += _test_count_buttons_follow_shift()
	failures += _test_count_button_label_matches_circuit_builder()
	failures += _test_curve_midpoint_is_the_middle_of_the_arc()
	failures += _test_loop_anchor_is_the_center_of_the_ring()
	if failures == 0:
		print("Mapping hover hold tests: PASS")
		quit(0)
	else:
		push_error("Mapping hover hold tests: FAIL (%d)" % failures)
		quit(1)


func _test_hover_shows_lines_until_the_pointer_leaves() -> int:
	if not Hold.should_show_connections(true, false):
		push_error("hover must show mapping lines")
		return 1
	if Hold.should_show_connections(false, false):
		push_error("leaving an area without Shift must hide mapping lines")
		return 1
	return 0


func _test_shift_keeps_the_pinned_area_after_the_pointer_leaves() -> int:
	if not Hold.should_show_connections(false, true):
		push_error("Shift must keep the pinned area's mapping lines after the pointer leaves")
		return 1
	if not Hold.should_show_connections(true, true):
		push_error("a pinned area must keep its lines while the pointer is still over it")
		return 1
	return 0


func _test_shift_pins_the_area_under_the_pointer() -> int:
	var failures := 0
	if Hold.next_pinned_cortical_id(&"area-a", &"", true, true) != &"area-a":
		push_error("pressing Shift over an area must pin that area")
		failures += 1
	if Hold.next_pinned_cortical_id(&"", &"", true, true) != &"":
		push_error("pressing Shift over empty space must not pin an area")
		failures += 1
	if Hold.next_pinned_cortical_id(&"area-b", &"", true, false) != &"area-b":
		push_error("hovering an area while Shift is already held must pin it")
		failures += 1
	if Hold.next_pinned_cortical_id(&"area-a", &"area-a", false, false) != &"":
		push_error("releasing Shift must clear the pin")
		failures += 1
	return failures


func _test_shift_does_not_replace_the_pinned_area() -> int:
	if Hold.next_pinned_cortical_id(&"area-b", &"area-a", true, false) != &"area-a":
		push_error("moving onto another area while Shift is held must keep the original lines")
		return 1
	if Hold.next_pinned_cortical_id(&"", &"area-a", true, false) != &"area-a":
		push_error("moving the pointer away while Shift is held must keep the pinned lines")
		return 1
	return 0


func _test_count_buttons_follow_shift() -> int:
	if Hold.should_show_count_buttons(true, false):
		push_error("mapping count buttons must stay hidden until Shift is held")
		return 1
	if not Hold.should_show_count_buttons(true, true):
		push_error("Shift must show a count button on each visible mapping line")
		return 1
	if Hold.should_show_count_buttons(false, true):
		push_error("Shift must not show count buttons when no mapping lines are visible")
		return 1
	return 0


func _test_count_button_label_matches_circuit_builder() -> int:
	if Hold.count_button_label(3) != "  3  ":
		push_error("the count button must use the Circuit Builder label")
		return 1
	return 0


func _test_curve_midpoint_is_the_middle_of_the_arc() -> int:
	var middle := Hold.curve_midpoint(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 0.4)
	if middle.distance_to(Vector3(5.0, 2.0, 0.0)) > 0.001:
		push_error("the count button must sit halfway along the mapping arc, got %s" % str(middle))
		return 1
	return 0


func _test_loop_anchor_is_the_center_of_the_ring() -> int:
	var anchor := Hold.loop_anchor(Vector3(1.0, 2.0, 3.0), 2.0)
	if anchor.distance_to(Vector3(1.0, 4.0, 3.0)) > 0.001:
		push_error("a self-mapping count button must sit in the center of the loop")
		return 1
	return 0
