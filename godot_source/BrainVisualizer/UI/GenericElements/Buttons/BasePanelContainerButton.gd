extends PanelContainer
class_name BasePanelContainerButton

signal pressed()

const PLATE_COLOR: Color = Color("252525")
const PLATE_PADDING: int = 10
const HOVER_SCALE: float = 1.03
const HOVER_TWEEN_SECONDS: float = 0.08

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
var _plate_styleboxes: Dictionary = {}
var _hover_scale_target: Control = null
var _hover_scale_normal: Vector2 = Vector2.ONE
var _hover_tween: Tween = null

func _ready() -> void:
	mouse_entered.connect(_mouse_entered)
	mouse_exited.connect(_mouse_exited)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hover_scale_target = _find_hover_scale_target()
	if _hover_scale_target != null:
		_hover_scale_normal = _hover_scale_target.scale
	if BV and BV.UI:
		BV.UI.theme_changed.connect(_on_theme_changed)
	_apply_plate_color()


## Ensure the back plate color is visible against dark scenes.
func _apply_plate_color() -> void:
	_plate_styleboxes.clear()
	_plate_styleboxes["panel"] = _build_plate_stylebox("panel")
	_plate_styleboxes["panel_hover"] = _build_plate_stylebox("panel_hover")
	_plate_styleboxes["panel_pressed"] = _build_plate_stylebox("panel_pressed")
	_plate_styleboxes["panel_disabled"] = _build_plate_stylebox("panel_disabled")
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
func _build_plate_stylebox(style_name: StringName) -> StyleBox:
	var base_style: StyleBox = null
	if has_theme_stylebox(style_name, "BasePanelContainerButton"):
		base_style = get_theme_stylebox(style_name, "BasePanelContainerButton")
	if base_style is StyleBoxFlat:
		var plate_style := base_style.duplicate() as StyleBoxFlat
		plate_style.bg_color = PLATE_COLOR
		plate_style.content_margin_left = PLATE_PADDING
		plate_style.content_margin_top = PLATE_PADDING
		plate_style.content_margin_right = PLATE_PADDING
		plate_style.content_margin_bottom = PLATE_PADDING
		return plate_style
	if base_style != null:
		var fallback_style := StyleBoxFlat.new()
		fallback_style.bg_color = PLATE_COLOR
		fallback_style.content_margin_left = PLATE_PADDING
		fallback_style.content_margin_top = PLATE_PADDING
		fallback_style.content_margin_right = PLATE_PADDING
		fallback_style.content_margin_bottom = PLATE_PADDING
		return fallback_style
	return null


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
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null and hovered != self and is_ancestor_of(hovered):
		if hovered.has_meta("ignore_parent_press") and bool(hovered.get_meta("ignore_parent_press")):
			return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if !get_global_rect().has_point(get_global_mouse_position()): # check if mouse is in button. FIXME: Does not check if control is on top, so in that case this fails!
			return
		
		if mouse_event.pressed:
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
		
func _mouse_entered() -> void:
	if _disabled:
		return
	var hover_style := _get_plate_stylebox("panel_hover")
	if hover_style != null:
		add_theme_stylebox_override("panel", hover_style)
	else:
		push_error("Missing panel_hover for PanelContainerButton")
	if _hover_scale_target != null:
		_animate_hover_scale(_hover_scale_normal * HOVER_SCALE)

func _mouse_exited() -> void:
	if _disabled:
		return
	var normal_style := _get_plate_stylebox("panel")
	if normal_style != null:
		add_theme_stylebox_override("panel", normal_style)
	else:
		push_error("Missing panel for BasePanelContainerButton")
	if _hover_scale_target != null:
		_animate_hover_scale(_hover_scale_normal)


## Find a reasonable child to scale on hover.
func _find_hover_scale_target() -> Control:
	for child in get_children():
		if child is Control and child.has_meta("hover_scale_target") and bool(child.get_meta("hover_scale_target")):
			return child as Control
	for child in get_children():
		if child is Control:
			return child as Control
	return null


## Animate hover scaling for a subtle zoom-in/out.
func _animate_hover_scale(target_scale: Vector2) -> void:
	if _hover_scale_target == null:
		return
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_SINE)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(_hover_scale_target, "scale", target_scale, HOVER_TWEEN_SECONDS)
