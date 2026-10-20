extends SceneTree
## Root top bar drops the first-section titles when the labeled bar is wider than the window.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Top_Bar/test_top_bar_first_section_titles.gd

const Titles = preload("res://BrainVisualizer/UI/Top_Bar/TopBarFirstSectionTitles.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_hides_only_when_the_labeled_bar_does_not_fit()
	failures += _test_compression_drops_counts_before_the_refresh_label()
	failures += _test_hidden_title_width_includes_the_gap()
	failures += _test_category_title_label_finds_the_chip_text()
	failures += _test_refresh_label_savings_is_the_dropped_words()
	if failures == 0:
		print("Top bar first-section title tests: PASS")
		quit(0)
	else:
		push_error("Top bar first-section title tests: FAIL (%d)" % failures)
		quit(1)


func _test_hides_only_when_the_labeled_bar_does_not_fit() -> int:
	if not Titles.should_hide(1200.0, 900.0):
		push_error("A labeled bar wider than the window must drop titles")
		return 1
	if Titles.should_hide(900.0, 900.0):
		push_error("An exact fit must keep the titles")
		return 1
	if Titles.should_hide(800.0, 900.0):
		push_error("Spare width must restore the titles")
		return 1
	if Titles.should_hide(1200.0, 0.0):
		push_error("An unknown window width must keep the titles")
		return 1
	return 0


func _test_compression_drops_counts_before_the_refresh_label() -> int:
	# full 1500, titles 200, counts 250, shortening the refresh label saves 80.
	var full := 1500.0
	var titles := 200.0
	var counts := 250.0
	var savings := 80.0
	if Titles.compression_stage(1600.0, full, titles, counts, savings) != Titles.STAGE_FULL:
		push_error("A bar that fits must keep titles, counts, and the refresh label")
		return 1
	if Titles.compression_stage(1400.0, full, titles, counts, savings) != Titles.STAGE_ICONS:
		push_error("The first squeeze must drop category titles only")
		return 1
	if Titles.compression_stage(1100.0, full, titles, counts, savings) != Titles.STAGE_NO_COUNTS:
		push_error("The next squeeze must hide neuron and synapse counts before touching refresh rate")
		return 1
	if Titles.compression_stage(1000.0, full, titles, counts, savings) != Titles.STAGE_SHORT_HZ:
		push_error("Refresh rate shortens only after counts are already hidden")
		return 1
	# Stage 2 width is 1500 - 200 - 250 = 1050. Exact fit keeps the long refresh label.
	if Titles.compression_stage(1050.0, full, titles, counts, savings) != Titles.STAGE_NO_COUNTS:
		push_error("An exact fit after hiding counts must keep Refresh Rate (Hz)")
		return 1
	return 0


func _test_hidden_title_width_includes_the_gap() -> int:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	var title := Label.new()
	title.text = "Modulators"
	row.add_child(icon)
	row.add_child(title)
	root.add_child(row)
	if not is_zero_approx(Titles.hidden_title_slot_width(title)):
		push_error("A visible title is already inside the bar width")
		row.queue_free()
		return 1
	var text_width: float = title.get_combined_minimum_size().x
	title.visible = false
	var hidden: float = Titles.hidden_title_slot_width(title)
	if text_width <= 1.0:
		push_error("Title text must have a measurable width")
		row.queue_free()
		return 1
	if not is_equal_approx(hidden, text_width + 6.0):
		push_error("Hidden title slot must be the text width plus the icon gap, got %s (text %s)" % [hidden, text_width])
		row.queue_free()
		return 1
	row.queue_free()
	return 0


func _test_category_title_label_finds_the_chip_text() -> int:
	var row := PanelContainer.new()
	var outer := HBoxContainer.new()
	outer.name = "HBoxContainer"
	var list := PanelContainer.new()
	list.name = "InputsList"
	var inner := HBoxContainer.new()
	inner.name = "HBoxContainer"
	var title := Label.new()
	title.name = "Label"
	title.text = "Inputs"
	inner.add_child(title)
	list.add_child(inner)
	outer.add_child(list)
	row.add_child(outer)
	root.add_child(row)
	var found: Label = Titles.category_title_label(row, "InputsList")
	if found != title:
		push_error("Category chip lookup must return the title label")
		row.queue_free()
		return 1
	if Titles.category_title_label(null, "InputsList") != null:
		push_error("A missing row has no title")
		row.queue_free()
		return 1
	row.queue_free()
	return 0


func _test_refresh_label_savings_is_the_dropped_words() -> int:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var label := Label.new()
	label.text = Titles.REFRESH_LABEL_FULL
	var field := LineEdit.new()
	field.text = "30"
	row.add_child(label)
	row.add_child(field)
	root.add_child(row)
	if not is_zero_approx(Titles.compact_refresh_extra_width(label, field)):
		push_error("A visible refresh title is already inside the bar width")
		row.queue_free()
		return 1
	label.visible = false
	var extra: float = Titles.compact_refresh_extra_width(label, field)
	var expected: float = Titles.hidden_title_slot_width(label)
	if not is_equal_approx(extra, expected):
		push_error("Compact refresh width must add the hidden title back without subtracting Hz")
		row.queue_free()
		return 1
	if extra <= 0.0:
		push_error("Dropping the refresh title must still save width")
		row.queue_free()
		return 1
	row.queue_free()
	return 0
