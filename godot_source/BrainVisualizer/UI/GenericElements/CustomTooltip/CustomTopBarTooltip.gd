extends VBoxContainer
class_name CustomTopBarTooltip

## Gap between anchor control and tooltip (caret tip sits just below this).
const TOOLTIP_OFFSET_Y: float = 14.0
const FADE_DURATION: float = 0.15
const TOOLTIP_PADDING: Vector2 = Vector2(12, 8)
## Max width for wrapping; short strings get a narrow box (content-sized below this cap).
const MAX_WRAP_WIDTH_BASE_PX: float = 300.0
const MIN_LABEL_WIDTH_BASE_PX: float = 28.0
const MAX_VISIBLE_TEXT_LINES: int = 2

## Upward-pointing caret (visual triangle); scales with UI.
const TRIANGLE_HEIGHT_BASE_PX: float = 11.0
const TRIANGLE_BASE_WIDTH_BASE_PX: float = 20.0

## Body: near-black, slightly transparent; caret uses same fill.
const BODY_BG_COLOR: Color = Color(0, 0, 0, 0.78)
const BODY_EDGE_COLOR: Color = Color(1, 1, 1, 0.14)

## Smaller than top-bar button labels ([Label_Header]); scales with theme [Label] + UI zoom.
const TOOLTIP_FONT_SCALE_FACTOR: float = 0.65
const TOOLTIP_FONT_MIN_PX: int = 10

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
	margin.add_child(_label)
	_apply_tooltip_typography()
	_apply_label_size_for_text("")
	
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
	if _label != null and is_instance_valid(_label):
		_apply_label_size_for_text(_label.text)


func _ui_scale() -> float:
	if is_instance_valid(BV) and BV.UI != null:
		return BV.UI.loaded_theme_scale.x
	return 1.0


func _resolve_theme_font_size_px() -> int:
	# Use base [Label] size (not [Label_Header] on buttons), then shrink so tooltips read as secondary.
	var base_px: int = 14
	if is_instance_valid(BV) and BV.UI != null and BV.UI.loaded_theme != null:
		var sz: int = BV.UI.loaded_theme.get_font_size("font_size", "Label")
		if sz > 0:
			base_px = sz
	var scaled: float = float(base_px) * TOOLTIP_FONT_SCALE_FACTOR * _ui_scale()
	return maxi(TOOLTIP_FONT_MIN_PX, int(round(scaled)))


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


func _get_max_label_wrap_width() -> float:
	return MAX_WRAP_WIDTH_BASE_PX * _ui_scale()


func _get_min_label_width() -> float:
	return MIN_LABEL_WIDTH_BASE_PX * _ui_scale()


## Sizes the label to the measured text block (capped by max wrap width), with modest inner padding.
func _apply_label_size_for_text(text: String) -> void:
	if _label == null or not is_instance_valid(_label):
		return
	var fs: int = _resolve_theme_font_size_px()
	var max_w: float = _get_max_label_wrap_width()
	var min_w: float = _get_min_label_width()
	var font: Font = _label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var measure_text: String = text if not text.is_empty() else " "
	var block: Vector2 = font.get_multiline_string_size(
		measure_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		max_w,
		fs,
		MAX_VISIBLE_TEXT_LINES
	)
	var line_spacing: int = maxi(2, int(round(float(fs) * 0.18)))
	_label.add_theme_constant_override("line_spacing", line_spacing)
	var line_height: int = maxi(fs + 2, int(ceil(float(fs) * 1.28)))
	# Small slack beyond measured glyph bounds; outer margin is TOOLTIP_PADDING on the MarginContainer.
	var inner_pad_x: float = 4.0 * _ui_scale()
	var inner_pad_y: float = 2.0 * _ui_scale()
	var w: float = clampf(block.x + inner_pad_x, min_w, max_w)
	var h: float = maxf(block.y + inner_pad_y, float(line_height))
	_label.custom_minimum_size = Vector2(w, h)
	_label.text = text


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
	_apply_tooltip_typography()
	_apply_label_size_for_text(text)
	show()
	await get_tree().process_frame
	await get_tree().process_frame
	reset_size()
	_position_tooltip()
	
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(false)
	_tween.tween_property(self, "modulate", Color(1, 1, 1, 1), FADE_DURATION)


func hide_tooltip() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(false)
	_tween.tween_property(self, "modulate", Color(1, 1, 1, 0), FADE_DURATION)
	_tween.tween_callback(hide)
	_tween.tween_callback(func(): tooltip_hidden.emit())
	_current_anchor = null


## Window-space rect matching [CanvasLayer] tooltips under [UIManager] (SubViewport, reparented popups, etc.).
func _anchor_global_rect_in_root_window(anchor: Control) -> Rect2:
	return CustomTopBarTooltipManager.anchor_control_global_rect_window(anchor)


func _tooltip_size_for_layout() -> Vector2:
	var s: Vector2 = size
	if s.x < 1.0 or s.y < 1.0:
		s = get_combined_minimum_size()
	return s


func _apply_global_top_left(tl_global: Vector2) -> void:
	var parent_ctl: Control = get_parent() as Control
	if parent_ctl != null:
		position = parent_ctl.get_global_transform().affine_inverse() * tl_global
	else:
		global_position = tl_global


func _position_tooltip() -> void:
	if _current_anchor == null or not is_instance_valid(_current_anchor):
		return
	
	if not _current_anchor.is_inside_tree():
		return
	
	var anchor_rect := _anchor_global_rect_in_root_window(_current_anchor)
	var tooltip_size: Vector2 = _tooltip_size_for_layout()
	
	var x_pos := anchor_rect.position.x + (anchor_rect.size.x - tooltip_size.x) / 2.0
	var y_pos := anchor_rect.position.y + anchor_rect.size.y + TOOLTIP_OFFSET_Y
	
	var vr: Rect2 = get_tree().root.get_visible_rect()
	var margin: float = 10.0
	var min_x: float = vr.position.x + margin
	var max_x: float = vr.position.x + vr.size.x - tooltip_size.x - margin
	if max_x >= min_x:
		x_pos = clampf(x_pos, min_x, max_x)
	else:
		x_pos = min_x
	
	_apply_global_top_left(Vector2(x_pos, y_pos))


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
