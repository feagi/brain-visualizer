extends PanelContainer
class_name BasePanelContainerButton

signal pressed()

const DEFAULT_PLATE_COLOR: Color = Color("252525")
const PLATE_PADDING: int = 5
const HOVER_SCALE: float = 1.03
const CONTENT_HOVER_SCALE: float = 1.1
const HOVER_TWEEN_SECONDS: float = 0.08
const HOVER_CLEARANCE_NODE: StringName = &"HoverClearance"

var disabled: bool:
	get: return _disabled
	set(v):
		_disabled = v
		if v:
			var disabled_style := _get_plate_stylebox("panel_disabled")
			if disabled_style != null:
				add_theme_stylebox_override("panel", disabled_style)
			else:
				push_error("Missing panel_disabled for BasePanelContainerButton")
		else:
			var normal_style := _get_plate_stylebox("panel")
			if normal_style != null:
				add_theme_stylebox_override("panel", normal_style)
			else:
				push_error("Missing panel for BasePanelContainerButton")
		

var _disabled: bool = false
var _hovered: bool = false
var _plate_styleboxes: Dictionary = {}
var _hover_scale_target: Control = null
var _hover_scale_normal: Vector2 = Vector2.ONE
var _hover_tween: Tween = null
var _plus_tween: Tween = null
var _plus_buttons: Array[Control] = []


## Godot already delivered this event to the control. Do not re-test with
## get_global_rect()/get_global_mouse_position(); those spaces diverge inside
## a SubViewport (Brain Monitor) and drop the Connectome press.
static func should_emit_press_for_gui_mouse_button(disabled: bool, hovered: bool, event: InputEvent) -> bool:
	if disabled or not hovered:
		return false
	if not event is InputEventMouseButton:
		return false
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	return mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed


## List text and + are separate buttons. Never scale a container that owns both.
static func should_scale_list_content_on_hover(pointer_over_plus: bool) -> bool:
	return not pointer_over_plus


## Text pop is limited to the label rect. Icon, padding, and the shared row plate do not scale it.
static func should_scale_list_label_on_hover(pointer_over_label: bool, pointer_over_plus: bool) -> bool:
	return pointer_over_label and not pointer_over_plus


## Label must PASS so hover stays on the text while the parent button still gets the click.
static func list_label_mouse_filter_for_parent_press() -> MouseFilter:
	return MOUSE_FILTER_PASS


## Clicking the label still counts as hovering the list button.
static func is_list_button_press_hovered(button_hovered: bool, label_hovered: bool) -> bool:
	return button_hovered or label_hovered


## Text / + pop in place. Whole-row targets (no + child) keep the smaller plate scale.
static func content_hover_scale(hovered: bool, target_is_text_or_plus: bool) -> float:
	if not hovered:
		return 1.0
	return CONTENT_HOVER_SCALE if target_is_text_or_plus else HOVER_SCALE


## Left gap so a left-aligned label can pop without covering the icon.
static func label_hover_left_clearance_px(text_width: float, hover_scale: float) -> int:
	if text_width <= 0.0:
		return 0
	var extra_width: float = text_width * max(hover_scale, 1.0) - text_width
	return int(round(extra_width / 2.0))


## Glyph width only. Do not use the expand-fill control size.
static func label_text_width_px(label: Label) -> float:
	if label == null:
		return 0.0
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if font == null:
		return maxf(label.get_minimum_size().x, 0.0)
	return maxf(font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, 0.0)


## Scale around the text (or the plus), never the empty expand-fill box.
static func hover_pivot_offset(control: Control) -> Vector2:
	if control == null:
		return Vector2.ZERO
	if control is Label:
		var text_width: float = label_text_width_px(control as Label)
		return Vector2(text_width * 0.5, control.size.y * 0.5)
	return control.size * 0.5


## Prefer the label when a marked hover target also contains a + button.
static func resolve_hover_scale_target(root: Control) -> Control:
	if root == null:
		return null
	if root.has_meta("disable_hover_scale") and bool(root.get_meta("disable_hover_scale")):
		return null
	var marked: Control = _find_control_with_meta(root, "hover_scale_target")
	if marked != null and not contains_ignore_parent_press(marked):
		return marked
	return _first_descendant_label(root)


## True when a + (or other ignore_parent_press) control lives under [param root].
static func contains_ignore_parent_press(root: Node) -> bool:
	if root == null:
		return false
	if root is Control and root.has_meta("ignore_parent_press") and bool(root.get_meta("ignore_parent_press")):
		return true
	for child in root.get_children():
		if contains_ignore_parent_press(child):
			return true
	return false


static func _find_control_with_meta(root: Node, meta_name: String) -> Control:
	if root is Control and root.has_meta(meta_name) and bool(root.get_meta(meta_name)):
		return root as Control
	for child in root.get_children():
		var found: Control = _find_control_with_meta(child, meta_name)
		if found != null:
			return found
	return null


static func _first_descendant_label(root: Node) -> Label:
	if root == null:
		return null
	if root is Control and root.has_meta("ignore_parent_press") and bool(root.get_meta("ignore_parent_press")):
		return null
	if root is Label:
		return root as Label
	for child in root.get_children():
		var found: Label = _first_descendant_label(child)
		if found != null:
			return found
	return null

func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hover_scale_target = resolve_hover_scale_target(self)
	if _hover_scale_target != null:
		_hover_scale_normal = _hover_scale_target.scale
		_center_scale_pivot(_hover_scale_target)
		if not _hover_scale_target.resized.is_connected(_on_hover_scale_target_resized):
			_hover_scale_target.resized.connect(_on_hover_scale_target_resized)
		if _hover_scale_target is Label:
			_hover_scale_target.mouse_filter = list_label_mouse_filter_for_parent_press()
	_wire_plus_hover_scale()
	if BV and BV.UI:
		BV.UI.theme_changed.connect(_on_theme_changed)
	_apply_plate_color()


## True when this list button sits on a shared combo-row plate and must not paint its own chrome.
func _is_flat_on_backdrop() -> bool:
	return has_meta("flat_on_backdrop") and bool(get_meta("flat_on_backdrop"))


## Paint no local plate so list and + share one neutral backdrop.
func _apply_flat_backdrop_styles() -> void:
	var empty := StyleBoxEmpty.new()
	_plate_styleboxes.clear()
	for key in ["panel", "panel_hover", "panel_pressed", "panel_disabled"]:
		_plate_styleboxes[key] = empty
		add_theme_stylebox_override(key, empty)


## Ensure the button plate color remains consistent across themes.
func _apply_plate_color() -> void:
	if _is_flat_on_backdrop():
		_apply_flat_backdrop_styles()
		return
	var plate_color: Color = _resolve_plate_color()
	_plate_styleboxes.clear()
	_plate_styleboxes["panel"] = _build_plate_stylebox("panel", plate_color)
	_plate_styleboxes["panel_hover"] = _build_plate_stylebox("panel_hover", plate_color)
	_plate_styleboxes["panel_pressed"] = _build_plate_stylebox("panel_pressed", plate_color)
	_plate_styleboxes["panel_disabled"] = _build_plate_stylebox("panel_disabled", plate_color)
	for key in _plate_styleboxes.keys():
		var style: StyleBox = _plate_styleboxes[key]
		if style != null:
			add_theme_stylebox_override(key, style)
	var normal_style := _get_plate_stylebox("panel")
	if normal_style != null:
		add_theme_stylebox_override("panel", normal_style)


## Rebuild plate styles when the theme changes.
func _on_theme_changed(_new_theme: Theme) -> void:
	_apply_plate_color()


## Build a plate style based on the theme stylebox.
func _build_plate_stylebox(style_name: StringName, plate_color: Color) -> StyleBox:
	var base_style: StyleBox = null
	if has_theme_stylebox(style_name, "BasePanelContainerButton"):
		base_style = get_theme_stylebox(style_name, "BasePanelContainerButton")
	if base_style is StyleBoxFlat:
		var plate_style := base_style.duplicate() as StyleBoxFlat
		_apply_plate_metrics(plate_style, plate_color)
		return plate_style
	var plate_style := StyleBoxFlat.new()
	_apply_plate_metrics(plate_style, plate_color)
	return plate_style


## Shared plate fill and inset so text buttons match icon-button chrome.
func _apply_plate_metrics(plate_style: StyleBoxFlat, plate_color: Color) -> void:
	var pad_x: int = int(get_meta("plate_padding_x")) if has_meta("plate_padding_x") else PLATE_PADDING
	var pad_y: int = int(get_meta("plate_padding_y")) if has_meta("plate_padding_y") else PLATE_PADDING
	plate_style.bg_color = plate_color
	plate_style.content_margin_left = pad_x
	plate_style.content_margin_top = pad_y
	plate_style.content_margin_right = pad_x
	plate_style.content_margin_bottom = pad_y


## Keep icon-button plates independent from top-bar panel/background styling.
## Set metadata/plate_color to match a neighboring control (e.g. icon JPEG fill).
func _resolve_plate_color() -> Color:
	if has_meta("plate_color"):
		return Color(get_meta("plate_color"))
	return DEFAULT_PLATE_COLOR


## Return the current plate stylebox for a given state.
func _get_plate_stylebox(style_name: StringName) -> StyleBox:
	if style_name in _plate_styleboxes:
		return _plate_styleboxes[style_name]
	if has_theme_stylebox(style_name, "BasePanelContainerButton"):
		return get_theme_stylebox(style_name, "BasePanelContainerButton")
	return null


func _gui_input(event: InputEvent) -> void:
	if _disabled:
		return
	if _is_ignore_parent_press_child_hovered():
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			if not should_emit_press_for_gui_mouse_button(_disabled, is_list_button_press_hovered(_hovered, _is_list_label_hovered()), mouse_event):
				return
			var pressed_style := _get_plate_stylebox("panel_pressed")
			if pressed_style != null:
				add_theme_stylebox_override("panel", pressed_style)
			else:
				push_error("Missing panel_pressed for BasePanelContainerButton")
			pressed.emit()
		else:
			var hover_style := _get_plate_stylebox("panel_hover")
			if hover_style != null:
				add_theme_stylebox_override("panel", hover_style)
			else:
				push_error("Missing panel_hover for BasePanelContainerButton")


## True when a child marked ignore_parent_press (e.g. a + button) owns the click.
func _is_ignore_parent_press_child_hovered() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var hovered := vp.gui_get_hovered_control()
	if hovered == null or hovered == self or not is_ancestor_of(hovered):
		return false
	return hovered.has_meta("ignore_parent_press") and bool(hovered.get_meta("ignore_parent_press"))

		
func _mouse_entered() -> void:
	_hovered = true
	if _disabled:
		return
	var hover_style := _get_plate_stylebox("panel_hover")
	if hover_style != null:
		add_theme_stylebox_override("panel", hover_style)
	else:
		push_error("Missing panel_hover for PanelContainerButton")
	call_deferred("_refresh_list_hover_scale")

func _mouse_exited() -> void:
	_hovered = false
	if _disabled:
		return
	var normal_style := _get_plate_stylebox("panel")
	if normal_style != null:
		add_theme_stylebox_override("panel", normal_style)
	else:
		push_error("Missing panel for BasePanelContainerButton")
	call_deferred("_refresh_list_hover_scale")


func _wire_plus_hover_scale() -> void:
	_plus_buttons.clear()
	_collect_ignore_parent_press_controls(self, _plus_buttons)
	for plus in _plus_buttons:
		plus.mouse_entered.connect(_on_plus_hover.bind(plus, true))
		plus.mouse_exited.connect(_on_plus_hover.bind(plus, false))
		_center_scale_pivot(plus)
		plus.resized.connect(_on_plus_resized.bind(plus))


func _collect_ignore_parent_press_controls(node: Node, out: Array[Control]) -> void:
	if node is Control and node.has_meta("ignore_parent_press") and bool(node.get_meta("ignore_parent_press")):
		out.append(node as Control)
		return
	for child in node.get_children():
		_collect_ignore_parent_press_controls(child, out)


func _on_plus_hover(plus: Control, hovered: bool) -> void:
	if plus == null or _disabled:
		return
	_animate_control_scale(plus, content_hover_scale(hovered, true), true)
	call_deferred("_refresh_list_hover_scale")


func _on_plus_resized(plus: Control) -> void:
	_center_scale_pivot(plus)


func _on_hover_scale_target_resized() -> void:
	_center_scale_pivot(_hover_scale_target)


func _refresh_list_hover_scale() -> void:
	if _disabled:
		_apply_list_hover_scale(false)
		return
	if _hover_scale_target is Label:
		_apply_list_hover_scale(should_scale_list_label_on_hover(_is_list_label_hovered(), _is_ignore_parent_press_child_hovered()))
		return
	var scale_list: bool = _hovered and should_scale_list_content_on_hover(_is_ignore_parent_press_child_hovered())
	_apply_list_hover_scale(scale_list)


## True only while the pointer is on the label glyphs, not the icon or leftover plate.
func _is_list_label_hovered() -> bool:
	if not _hover_scale_target is Label:
		return false
	var vp := get_viewport()
	if vp == null:
		return false
	return vp.gui_get_hovered_control() == _hover_scale_target


func _apply_list_hover_scale(hovered: bool) -> void:
	if _hover_scale_target == null:
		return
	var target_is_text: bool = _hover_scale_target is Label
	_animate_control_scale(_hover_scale_target, content_hover_scale(hovered, target_is_text), false)


func _center_scale_pivot(control: Control) -> void:
	if control == null:
		return
	if control is Label:
		_apply_label_icon_clearance(control as Label)
	control.pivot_offset = hover_pivot_offset(control)


## Insert space before the label equal to the leftward hover growth.
func _apply_label_icon_clearance(label: Label) -> void:
	var hbox: HBoxContainer = label.get_parent() as HBoxContainer
	if hbox == null:
		return
	var clearance: int = label_hover_left_clearance_px(label_text_width_px(label), CONTENT_HOVER_SCALE)
	var spacer: Control = hbox.get_node_or_null(NodePath(HOVER_CLEARANCE_NODE)) as Control
	if spacer == null:
		spacer = Control.new()
		spacer.name = String(HOVER_CLEARANCE_NODE)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(spacer)
		hbox.move_child(spacer, label.get_index())
	spacer.custom_minimum_size = Vector2(float(clearance), 0.0)


## Animate hover scaling for a subtle zoom-in/out.
func _animate_control_scale(control: Control, scale_factor: float, is_plus: bool) -> void:
	if control == null:
		return
	_center_scale_pivot(control)
	if is_plus:
		if _plus_tween != null and _plus_tween.is_running():
			_plus_tween.kill()
		_plus_tween = create_tween()
		_plus_tween.set_trans(Tween.TRANS_SINE)
		_plus_tween.set_ease(Tween.EASE_OUT)
		_plus_tween.tween_property(control, "scale", Vector2(scale_factor, scale_factor), HOVER_TWEEN_SECONDS)
		return
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_SINE)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(control, "scale", Vector2(scale_factor, scale_factor), HOVER_TWEEN_SECONDS)
