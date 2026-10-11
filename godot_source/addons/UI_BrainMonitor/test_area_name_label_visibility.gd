extends SceneTree
## Every area title, including invariant cores, stays hidden until hover.
## Run: godot --headless --path godot_source -s res://addons/UI_BrainMonitor/test_area_name_label_visibility.gd

const Visibility = preload("res://addons/UI_BrainMonitor/UI_BrainMonitor_AreaNameLabelVisibility.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_titles_stay_hidden_until_hover()
	failures += _test_bottom_hover_line_shows_title()
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
