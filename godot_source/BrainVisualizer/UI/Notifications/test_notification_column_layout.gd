extends SceneTree
## Phase 1 toast column: theme width and inset, 20px dismiss, two-line label.
## Messages, dedupe, and the cap of 8 are unchanged.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Notifications/test_notification_column_layout.gd

const COLUMN_WIDTH := 360
const COLUMN_INSET := 12
const DISMISS_SIZE := 20
const STACK_GAP := 8

const THEMES: Array[String] = [
	"res://BrainVisualizer/UI/Themes/source_themes/source_dark.tres",
	"res://BrainVisualizer/UI/Themes/0.5-DARK.tres",
	"res://BrainVisualizer/UI/Themes/0.75-DARK.tres",
	"res://BrainVisualizer/UI/Themes/1-DARK.tres",
	"res://BrainVisualizer/UI/Themes/1.25-DARK.tres",
	"res://BrainVisualizer/UI/Themes/1.5-DARK.tres",
	"res://BrainVisualizer/UI/Themes/2-DARK.tres",
]


func _initialize() -> void:
	var failures: int = 0
	failures += _test_theme_metrics()
	failures += _test_column_offsets()
	failures += _test_scenes_and_policy_hold()
	failures += _test_one_line_row_at_1x()
	failures += _test_message_width_hugs_text()
	if failures == 0:
		print("Notification column layout tests: PASS")
		quit(0)
		return
	push_error("Notification column layout tests: FAIL (%d)" % failures)
	quit(1)


func _scale_for_theme(path: String) -> float:
	if path.ends_with("source_dark.tres"):
		return 1.0
	var file_name := path.get_file()
	return file_name.get_slice("-", 0).to_float()


func _scaled(base: int, scale: float) -> int:
	return int(float(base) * scale)


func _test_theme_metrics() -> int:
	var failed := 0
	for path in THEMES:
		var theme: Theme = load(path)
		var scale := _scale_for_theme(path)
		if theme == null:
			push_error("Missing theme %s" % path)
			failed += 1
			continue
		failed += _expect_constant(theme, path, "NotificationSystem", "size_x", _scaled(COLUMN_WIDTH, scale))
		failed += _expect_constant(theme, path, "NotificationSystem", "size_y", _scaled(COLUMN_INSET, scale))
		failed += _expect_constant(theme, path, "NotificationSystem", "separation", STACK_GAP)
		failed += _expect_constant(theme, path, "TextureButton_NotificationDismiss", "size_x", _scaled(DISMISS_SIZE, scale))
		failed += _expect_constant(theme, path, "TextureButton_NotificationDismiss", "size_y", _scaled(DISMISS_SIZE, scale))
		failed += _expect_constant(theme, path, "TextureRect_NotificationIcon", "size_x", _scaled(DISMISS_SIZE, scale))
		failed += _expect_constant(theme, path, "TextureRect_NotificationIcon", "size_y", _scaled(DISMISS_SIZE, scale))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", theme.get_constant("separation", "NotificationSystem"))
		root.add_child(box)
		if box.get_theme_constant("separation") != STACK_GAP:
			push_error("%s column separation is %d" % [path, box.get_theme_constant("separation")])
			failed += 1
		box.queue_free()
	return failed


func _expect_constant(theme: Theme, path: String, type_name: String, constant_name: String, expected: int) -> int:
	if not theme.has_constant(constant_name, type_name):
		push_error("%s is missing %s/%s" % [path, type_name, constant_name])
		return 1
	var actual := theme.get_constant(constant_name, type_name)
	if actual != expected:
		push_error("%s %s/%s is %d, expected %d" % [path, type_name, constant_name, actual, expected])
		return 1
	return 0


func _test_column_offsets() -> int:
	var script: GDScript = load("res://BrainVisualizer/UI/Notifications/NotificationSystem.gd")
	if script == null:
		push_error("NotificationSystem script failed to load")
		return 1
	var offsets: Vector4 = script.call("column_offsets", 100.0, COLUMN_WIDTH, COLUMN_INSET)
	var expected := Vector4(-(COLUMN_WIDTH + COLUMN_INSET), 100.0 + COLUMN_INSET, -COLUMN_INSET, -COLUMN_INSET)
	if offsets != expected:
		push_error("Column offsets %s, expected %s" % [offsets, expected])
		return 1
	return 0


func _test_scenes_and_policy_hold() -> int:
	var failed := 0
	var column := FileAccess.get_file_as_string("res://BrainVisualizer/UI/Notifications/NotificationSystem.tscn")
	var card := FileAccess.get_file_as_string("res://BrainVisualizer/UI/Notifications/NotificationSystemNotification.tscn")
	var column_script := FileAccess.get_file_as_string("res://BrainVisualizer/UI/Notifications/NotificationSystem.gd")
	var manager := FileAccess.get_file_as_string("res://BrainVisualizer/UI/UIManager.gd")
	var root_scene := FileAccess.get_file_as_string("res://BrainVisualizer/BrainVisualizer.tscn")
	if column.find("anchor_bottom = 1.0") < 0 or column.find("mouse_filter = 2") < 0:
		push_error("Notification column must fill the right side and ignore the mouse")
		failed += 1
	if card.find("type=\"Label\"") < 0 or card.find("RichTextLabel") >= 0:
		push_error("Notification text must be a Label")
		failed += 1
	if card.find("max_lines_visible = 2") < 0:
		push_error("Notification text must stop at two lines")
		failed += 1
	if card.find("TextureButton_NotificationDismiss") < 0 or card.find("Dismiss this notification") < 0:
		push_error("Dismiss control must use its theme type and explain the click")
		failed += 1
	if card.find("size_flags_horizontal = 8") < 0:
		push_error("Notification cards must sit on the right")
		failed += 1
	if column_script.find("static func shared_card_width") < 0:
		push_error("Visible cards must share one width")
		failed += 1
	if card.find("[node name=\"message_label\"") >= 0 and card.find("size_flags_horizontal = 3") >= 0:
		push_error("Notification text must not stretch to the column width")
		failed += 1
	if card.find("custom_minimum_size = Vector2(48") >= 0:
		push_error("Dismiss control must not use the 48px window-close size")
		failed += 1
	if column_script.find("add_theme_constant_override(\"separation\"") < 0:
		push_error("Column must apply the theme stack gap")
		failed += 1
	if column_script.find("const MAX_VISIBLE_NOTIFICATIONS: int = 8") < 0:
		push_error("Visible cap must stay 8 until the toast policy phase")
		failed += 1
	if column_script.find("now_ms - last_ms < dedupe_window_ms") < 0:
		push_error("Dedupe must stay in place until the toast policy phase")
		failed += 1
	if manager.find("place_below_top_bar") < 0:
		push_error("UIManager must place the column from the top bar bottom")
		failed += 1
	if root_scene.find("offset_bottom = 161.0") >= 0:
		push_error("BrainVisualizer must not pin the notification column to 161px")
		failed += 1
	return failed


func _test_one_line_row_at_1x() -> int:
	var theme: Theme = load("res://BrainVisualizer/UI/Themes/1-DARK.tres")
	var label := Label.new()
	label.theme = theme
	label.add_theme_font_size_override("font_size", theme.get_font_size("font_size", "Label"))
	label.text = "Genome loaded!"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	root.add_child(label)
	var line_height := label.get_line_height()
	var dismiss := theme.get_constant("size_y", "TextureButton_NotificationDismiss")
	var icon := theme.get_constant("size_y", "TextureRect_NotificationIcon")
	label.queue_free()
	if line_height < float(dismiss) or line_height < float(icon):
		push_error("1x dismiss %d or icon %d is taller than the text line %s" % [dismiss, icon, line_height])
		return 1
	return 0


func _test_message_width_hugs_text() -> int:
	var script: GDScript = load("res://BrainVisualizer/UI/Notifications/NotificationSystem.gd")
	if script == null:
		push_error("Notification column script failed to load")
		return 1
	var matched: float = script.call("shared_card_width", [120.0, 180.0, 140.0], 360.0)
	var capped: float = script.call("shared_card_width", [400.0, 180.0], 360.0)
	if matched != 180.0 or capped != 360.0:
		push_error("Shared card width matched=%s capped=%s" % [matched, capped])
		return 1
	return 0
