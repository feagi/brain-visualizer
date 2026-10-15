extends SceneTree
## Every area title, including invariant cores, stays hidden until hover.
## Run: godot --headless --path godot_source -s res://addons/UI_BrainMonitor/test_area_name_label_visibility.gd

const Visibility = preload("res://addons/UI_BrainMonitor/UI_BrainMonitor_AreaNameLabelVisibility.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_titles_stay_hidden_until_hover()
	failures += _test_bottom_hover_line_shows_title()
	failures += _test_focus_arrow_shows_title()
	failures += _test_shift_hold_shows_every_title()
	failures += _test_shift_reveal_stays_in_the_view_under_the_pointer()
	if failures == 0:
		print("Area name label visibility tests: PASS")
		quit(0)
	else:
		push_error("Area name label visibility tests: FAIL (%d)" % failures)
		quit(1)


func _test_titles_stay_hidden_until_hover() -> int:
	var failures := 0
	if Visibility.always_visible():
		push_error("Area titles, including cores, must stay hidden while idle")
		failures += 1
	if Visibility.should_show(false, false):
		push_error("A core title must stay hidden when the pointer is elsewhere")
		failures += 1
	if not Visibility.should_show(true, false):
		push_error("A core title must show while the volume is hovered")
		failures += 1
	return failures


func _test_bottom_hover_line_shows_title() -> int:
	if not Visibility.should_show(false, true):
		push_error("Area title must show when the bottom hover line names that area")
		return 1
	return 0


func _test_focus_arrow_shows_title() -> int:
	if not Visibility.should_show(false, false, true):
		push_error("Area title must show while the focus arrow points at the area")
		return 1
	if Visibility.should_show(false, false, false):
		push_error("Area title must hide again after the focus arrow is gone")
		return 1
	return 0


func _test_shift_hold_shows_every_title() -> int:
	if not Visibility.should_show(false, false, false, true):
		push_error("Holding Shift must show a title that is otherwise hidden")
		return 1
	if Visibility.should_show(false, false, false, false):
		push_error("Releasing Shift must hide a title that is not hovered")
		return 1
	return 0


func _test_shift_reveal_stays_in_the_view_under_the_pointer() -> int:
	if not Visibility.shift_reveals_titles_in_this_view(true, true):
		push_error("Shift must reveal titles in the 3D view the pointer is inside")
		return 1
	if Visibility.shift_reveals_titles_in_this_view(true, false):
		push_error("Shift must leave titles hidden in a 3D view the pointer is outside")
		return 1
	if Visibility.shift_reveals_titles_in_this_view(false, true):
		push_error("A view under the pointer must keep titles hidden until Shift is held")
		return 1
	return 0
