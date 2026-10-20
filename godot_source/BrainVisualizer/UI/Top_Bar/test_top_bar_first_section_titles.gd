extends SceneTree
## Root top bar drops the first-section titles when the labeled bar is wider than the window.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Top_Bar/test_top_bar_first_section_titles.gd

const Titles = preload("res://BrainVisualizer/UI/Top_Bar/TopBarFirstSectionTitles.gd")


func _initialize() -> void:
	var failures: int = 0
	failures += _test_hides_only_when_the_labeled_bar_does_not_fit()
	failures += _test_hidden_title_width_includes_the_gap()
	failures += _test_category_title_label_finds_the_chip_text()
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
