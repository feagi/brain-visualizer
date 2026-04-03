extends PanelContainer
class_name CustomTopBarTooltip

const TOOLTIP_OFFSET_Y: float = 8.0
const FADE_DURATION: float = 0.15
## Horizontal / vertical inner padding for the label (less cramped than default).
const TOOLTIP_PADDING: Vector2 = Vector2(18, 10)
## Minimum width for wrapped text (before theme scale); ~2 lines at typical copy length.
const MIN_TEXT_WIDTH_BASE_PX: float = 360.0
const MAX_VISIBLE_TEXT_LINES: int = 2

var _label: Label
var _tween: Tween
var _current_anchor: Control = null

signal tooltip_hidden()

func _ready():
	hide()
	modulate = Color(1, 1, 1, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_stylish_panel()
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(TOOLTIP_PADDING.x))
	margin.add_theme_constant_override("margin_right", int(TOOLTIP_PADDING.x))
	margin.add_theme_constant_override("margin_top", int(TOOLTIP_PADDING.y))
	margin.add_theme_constant_override("margin_bottom", int(TOOLTIP_PADDING.y))
	add_child(margin)
	
	_label = Label.new()
	_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	_label.add_theme_font_size_override("font_size", 14)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.max_lines_visible = MAX_VISIBLE_TEXT_LINES
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label_text_width()
	margin.add_child(_label)
	if is_instance_valid(BV) and BV.UI != null and not BV.UI.theme_changed.is_connected(_on_bv_theme_changed):
		BV.UI.theme_changed.connect(_on_bv_theme_changed)
	
	z_index = 1000

func _setup_stylish_panel() -> void:
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.12, 0.15, 0.20, 0.95)
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.35, 0.55, 0.85, 0.8)
	stylebox.corner_radius_top_left = 6
	stylebox.corner_radius_top_right = 6
	stylebox.corner_radius_bottom_left = 6
	stylebox.corner_radius_bottom_right = 6
	stylebox.shadow_color = Color(0, 0, 0, 0.5)
	stylebox.shadow_size = 8
	stylebox.shadow_offset = Vector2(0, 3)
	stylebox.anti_aliasing = true
	
	add_theme_stylebox_override("panel", stylebox)

func _on_bv_theme_changed(_new_theme: Theme) -> void:
	_apply_label_text_width()

func _get_scaled_min_text_width() -> float:
	var w := MIN_TEXT_WIDTH_BASE_PX
	if is_instance_valid(BV) and BV.UI != null:
		w *= BV.UI.loaded_theme_scale.x
	return w

func _apply_label_text_width() -> void:
	if _label == null or not is_instance_valid(_label):
		return
	_label.custom_minimum_size.x = _get_scaled_min_text_width()

func show_tooltip(text: String, anchor_control: Control) -> void:
	if text.is_empty():
		hide_tooltip()
		return
	
	if anchor_control == null or not is_instance_valid(anchor_control):
		push_warning("CustomTopBarTooltip: Anchor control is null or invalid")
		hide_tooltip()
		return
	
	if _label == null or not is_instance_valid(_label):
		push_error("CustomTopBarTooltip: Label is null or invalid")
		return
	
	_current_anchor = anchor_control
	_apply_label_text_width()
	_label.text = text
	
	# Let layout resolve minimum size before reading global rect / size.
	await get_tree().process_frame
	await get_tree().process_frame
	reset_size()
	_position_tooltip()
	
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(false)
	_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), FADE_DURATION)
	show()

func hide_tooltip() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(false)
	_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), FADE_DURATION)
	_tween.tween_callback(hide)
	_tween.tween_callback(func(): tooltip_hidden.emit())
	_current_anchor = null

func _position_tooltip() -> void:
	if _current_anchor == null or not is_instance_valid(_current_anchor):
		return
	
	if not _current_anchor.is_inside_tree():
		return
	
	var anchor_rect = _current_anchor.get_global_rect()
	var tooltip_size = size
	
	var x_pos = anchor_rect.position.x + (anchor_rect.size.x - tooltip_size.x) / 2.0
	var y_pos = anchor_rect.position.y + anchor_rect.size.y + TOOLTIP_OFFSET_Y
	
	var viewport_size = get_viewport_rect().size
	if x_pos + tooltip_size.x > viewport_size.x:
		x_pos = viewport_size.x - tooltip_size.x - 10
	if x_pos < 10:
		x_pos = 10
	
	global_position = Vector2(x_pos, y_pos)

func update_position() -> void:
	_position_tooltip()
