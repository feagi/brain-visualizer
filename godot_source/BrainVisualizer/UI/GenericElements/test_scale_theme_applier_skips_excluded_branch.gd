extends SceneTree
## Root top bar must not restyle the shared combo. That combo owns category icon size.
## Run: godot --headless -s res://BrainVisualizer/UI/GenericElements/test_scale_theme_applier_skips_excluded_branch.gd


func _initialize() -> void:
	var failures: int = 0
	failures += _test_excluded_branch_is_not_collected()
	failures += _test_root_bar_excludes_shared_combo_before_theme_scaler()
	if failures == 0:
		print("ScaleThemeApplier exclusion tests: PASS")
		quit(0)
		return
	push_error("ScaleThemeApplier exclusion tests: FAIL (%d)" % failures)
	quit(1)


func _test_excluded_branch_is_not_collected() -> int:
	var applier := ScaleThemeApplier.new()
	var host := Node.new()
	var combo := Node.new()
	var category_icon := TextureRect.new()
	var plus := TextureButton.new()
	var outside_icon := TextureRect.new()
	combo.add_child(category_icon)
	combo.add_child(plus)
	host.add_child(combo)
	host.add_child(outside_icon)
	root.add_child(host)
	applier._nodes_to_not_include_or_search = [combo]
	applier.search_for_matching_children(host)
	var failed: int = 0
	if applier._texture_rects.has(category_icon):
		push_error("Theme scaler must not resize icons inside an excluded combo")
		failed = 1
	if applier._texture_buttons.has(plus):
		push_error("Theme scaler must not resize buttons inside an excluded combo")
		failed = 1
	if not applier._texture_rects.has(outside_icon):
		push_error("Theme scaler must still resize icons outside the excluded combo")
		failed = 1
	host.queue_free()
	return failed


func _test_root_bar_excludes_shared_combo_before_theme_scaler() -> int:
	var source := FileAccess.get_file_as_string("res://BrainVisualizer/UI/Top_Bar/TopBar.gd")
	var exclude_at := source.find("theme_scalar_nodes_to_not_include_or_search.append(_shared_combo)")
	var setup_at := source.find("_theme_custom_scaler.setup(")
	if exclude_at < 0 or setup_at < 0 or exclude_at > setup_at:
		push_error("Root top bar must exclude the shared combo from the theme scaler before setup")
		return 1
	return 0
