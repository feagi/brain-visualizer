extends VBoxContainer
class_name CustomTopBarTooltip

## Gap between anchor control and tooltip (caret tip sits just below this).
const TOOLTIP_OFFSET_Y: float = 14.0
const FADE_DURATION: float = 0.15
const TOOLTIP_PADDING: Vector2 = Vector2(18, 14)
const MIN_TEXT_WIDTH_BASE_PX: float = 360.0
const MAX_VISIBLE_TEXT_LINES: int = 2

## Upward-pointing caret (visual triangle); scales with UI.
const TRIANGLE_HEIGHT_BASE_PX: float = 11.0
const TRIANGLE_BASE_WIDTH_BASE_PX: float = 20.0

## Body: near-black, slightly transparent; caret uses same fill.
const BODY_BG_COLOR: Color = Color(0, 0, 0, 0.78)
const BODY_EDGE_COLOR: Color = Color(1, 1, 1, 0.14)

var _caret: TooltipCaret
var _body: PanelContainer
var _label: Label
var _tween: Tween
var _current_anchor: Control = null

signal tooltip_hidden()


func _ready() -> void:
	hide()
	modulate = Color(1, 1, 1, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 0)
	
	_caret = TooltipCaret.new()
	_caret.name = "TooltipCaret"
	_caret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caret.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_caret)
	
	_body = PanelContainer.new()
	_body.name = "TooltipBody"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_setup_body_panel_style()
	add_child(_body)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(TOOLTIP_PADDING.x))
	margin.add_theme_constant_override("margin_right", int(TOOLTIP_PADDING.x))
	margin.add_theme_constant_override("margin_top", int(TOOLTIP_PADDING.y))
	margin.add_theme_constant_override("margin_bottom", int(TOOLTIP_PADDING.y))
	_body.add_child(margin)
	
	_label = Label.new()
	_label.theme_type_variation = &"Label"
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.max_lines_visible = MAX_VISIBLE_TEXT_LINES
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_tooltip_typography()
	_apply_label_text_width()
	_apply_label_min_height()
	margin.add_child(_label)
	
	if is_instance_valid(BV) and BV.UI != null and not BV.UI.theme_changed.is_connected(_on_bv_theme_changed):
		BV.UI.theme_changed.connect(_on_bv_theme_changed)
	
	z_index = 1000


func _setup_body_panel_style() -> void:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = BODY_BG_COLOR
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = BODY_EDGE_COLOR
	# Flat top where the caret sits; rounded bottom.
	stylebox.corner_radius_top_left = 0
	stylebox.corner_radius_top_right = 0
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	stylebox.shadow_color = Color(0, 0, 0, 0.45)
	stylebox.shadow_size = 10
	stylebox.shadow_offset = Vector2(0, 4)
	stylebox.anti_aliasing = true
	_body.add_theme_stylebox_override("panel", stylebox)


func _on_bv_theme_changed(_new_theme: Theme) -> void:
	_apply_tooltip_typography()
	_apply_caret_metrics()
	_apply_label_text_width()
	_apply_label_min_height()


func _ui_scale() -> float:
	if is_instance_valid(BV) and BV.UI != null:
		return BV.UI.loaded_theme_scale.x
	return 1.0


func _resolve_theme_font_size_px() -> int:
	var base_px: int = 14
	if is_instance_valid(BV) and BV.UI != null and BV.UI.loaded_theme != null:
		var sz: int = BV.UI.loaded_theme.get_font_size("font_size", "Label")
		if sz > 0:
			base_px = sz
	return int(round(float(base_px) * _ui_scale()))


func _apply_tooltip_typography() -> void:
	if _label == null or not is_instance_valid(_label):
		return
	_label.add_theme_font_size_override("font_size", _resolve_theme_font_size_px())
	_label.add_theme_color_override("font_color", Color.WHITE)


func _apply_caret_metrics() -> void:
	if _caret == null or not is_instance_valid(_caret):
		return
	var s := _ui_scale()
	_caret.custom_minimum_size = Vector2(0, TRIANGLE_HEIGHT_BASE_PX * s)
	_caret.triangle_base_width = TRIANGLE_BASE_WIDTH_BASE_PX * s
	_caret.fill_color = BODY_BG_COLOR
	_caret.edge_color = BODY_EDGE_COLOR
	_caret.queue_redraw()


func _get_scaled_min_text_width() -> float:
	return MIN_TEXT_WIDTH_BASE_PX * _ui_scale()


func _apply_label_text_width() -> void:
	if _label == null or not is_instance_valid(_label):
		return
	_label.custom_minimum_size.x = _get_scaled_min_text_width()


func _apply_label_min_height() -> void:
	if _label == null or not is_instance_valid(_label):
		return
	var fs: int = _resolve_theme_font_size_px()
	# Enough vertical space for two wrapped lines (Label needs explicit min height with max_lines_visible).
	var line_spacing: int = maxi(2, int(round(float(fs) * 0.2)))
	_label.add_theme_constant_override("line_spacing", line_spacing)
	var line_height: int = maxi(fs + 2, int(ceil(float(fs) * 1.28)))
	var min_h: int = line_height * MAX_VISIBLE_TEXT_LINES + line_spacing * maxi(0, MAX_VISIBLE_TEXT_LINES - 1)
	_label.custom_minimum_size.y = float(min_h)


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
	_apply_caret_metrics()
	_apply_label_text_width()
	_apply_label_min_height()
	_label.text = text
	
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
	
	var anchor_rect := _current_anchor.get_global_rect()
	var tooltip_size := size
	
	var x_pos := anchor_rect.position.x + (anchor_rect.size.x - tooltip_size.x) / 2.0
	var y_pos := anchor_rect.position.y + anchor_rect.size.y + TOOLTIP_OFFSET_Y
	
	var viewport_size := get_viewport_rect().size
	if x_pos + tooltip_size.x > viewport_size.x:
		x_pos = viewport_size.x - tooltip_size.x - 10
	if x_pos < 10:
		x_pos = 10
	
	global_position = Vector2(x_pos, y_pos)


func update_position() -> void:
	_position_tooltip()


## Upward-pointing triangle: tip at top center, base along bottom edge (meets body panel).
class TooltipCaret extends Control:
	var triangle_base_width: float = 20.0
	var fill_color: Color = BODY_BG_COLOR
	var edge_color: Color = BODY_EDGE_COLOR
	
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)
	
	func _draw() -> void:
		var w := size.x
		var h := size.y
		if w <= 0.0 or h <= 0.0:
			return
		var cx := w * 0.5
		var half_b := triangle_base_width * 0.5
		half_b = minf(half_b, w * 0.5 - 1.0)
		var pts := PackedVector2Array([
			Vector2(cx, 0.0),
			Vector2(cx - half_b, h),
			Vector2(cx + half_b, h),
		])
		draw_colored_polygon(pts, fill_color)
		# Light outer edge on sloped sides for definition on dark UIs.
		draw_line(pts[0], pts[1], edge_color, 1.0, true)
		draw_line(pts[0], pts[2], edge_color, 1.0, true)
