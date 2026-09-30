extends SceneTree
## Configurable popup messages must wrap on a readable column.
## RichTextLabel fit_content otherwise reports a 1px width and stacks one word per line.
## Run: godot --headless --path godot_source -s res://BrainVisualizer/UI/Windows/ConfigurablePopup/test_configurable_popup_wrap.gd

const PopupDefinition = preload("res://BrainVisualizer/UI/Windows/ConfigurablePopup/ConfigurablePopupDefinition.gd")

const LONG_ERROR := "Failed to create classifier:\n500.0\nFailed to create classifier assembly areas: Invalid input: Cortical area bXRlc3Rfx8l= cannot join root; root is reserved for core, IPU, and OPU areas"
const SHORT_MESSAGE := "Please select an input device"


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var failures: int = 0
	failures += _test_long_error_uses_column_cap()
	failures += _test_short_message_keeps_natural_width()
	failures += await _test_long_error_wraps_to_a_short_block()
	if failures == 0:
		print("Configurable popup wrap tests: PASS")
		quit(0)
	else:
		push_error("Configurable popup wrap tests: FAIL (%d)" % failures)
		quit(1)


func _test_long_error_uses_column_cap() -> int:
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var natural := _longest_line_width(LONG_ERROR, font, font_size)
	if natural <= PopupDefinition.MESSAGE_COLUMN_WIDTH_PX:
		push_error("Long error fixture is only %s px wide" % natural)
		return 1
	var column := PopupDefinition.message_column_width(LONG_ERROR, font, font_size)
	if not is_equal_approx(column, PopupDefinition.MESSAGE_COLUMN_WIDTH_PX):
		push_error("Long error column is %s, expected %s" % [column, PopupDefinition.MESSAGE_COLUMN_WIDTH_PX])
		return 1
	return 0


func _test_short_message_keeps_natural_width() -> int:
	var font := ThemeDB.fallback_font
	var font_size := ThemeDB.fallback_font_size
	var natural := font.get_string_size(SHORT_MESSAGE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if natural <= 0.0 or natural >= PopupDefinition.MESSAGE_COLUMN_WIDTH_PX:
		push_error("Short message fixture width %s is outside the expected range" % natural)
		return 1
	var column := PopupDefinition.message_column_width(SHORT_MESSAGE, font, font_size)
	if not is_equal_approx(column, natural):
		push_error("Short message column is %s, expected %s" % [column, natural])
		return 1
	return 0


func _test_long_error_wraps_to_a_short_block() -> int:
	var theme: Theme = load("res://BrainVisualizer/UI/Themes/source_themes/source_dark.tres")
	var font: Font = theme.get_font(&"normal_font", &"RichTextLabel")
	var font_size: int = theme.get_font_size(&"normal_font_size", &"RichTextLabel")
	var column := PopupDefinition.message_column_width(LONG_ERROR, font, font_size)
	var skinny := await _message_block_size(LONG_ERROR, theme, 0.0)
	var wrapped := await _message_block_size(LONG_ERROR, theme, column)
	if wrapped.x + 1.0 < column:
		push_error("Wrapped message width %s is below the column %s" % [wrapped.x, column])
		return 1
	if wrapped.y >= skinny.y * 0.5:
		push_error("Wrapped height %s is not shorter than the skinny height %s" % [wrapped.y, skinny.y])
		return 1
	return 0


func _message_block_size(message: String, theme: Theme, column_width: float) -> Vector2:
	var label := RichTextLabel.new()
	label.theme = theme
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = message
	if column_width > 0.0:
		label.custom_minimum_size.x = column_width
	root.add_child(label)
	for _i in 4:
		await process_frame
	var block_size := label.get_combined_minimum_size()
	label.queue_free()
	return block_size


func _longest_line_width(message: String, font: Font, font_size: int) -> float:
	var longest := 0.0
	for line in message.split("\n", false):
		longest = maxf(longest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return longest
