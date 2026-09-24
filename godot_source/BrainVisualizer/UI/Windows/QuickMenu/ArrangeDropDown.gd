extends TextureButton
class_name ArrangeDropDown
## Quick-menu Arrange control. Hover or click opens Align and Distribute, each with X, Y, and Z.
## Mirrors the inspectors dropdown: the menu overlaps the trigger so the pointer can move into it.

signal arrange_requested(action: StringName, axis: int)

const MENU_ANCHOR_OVERLAP_PX: int = 4
const MENU_HOVER_CLOSE_DELAY_SEC: float = 0.15

var _panel: PopupPanel
var _align_buttons: Array[Button] = []
var _distribute_buttons: Array[Button] = []
var _menu_close_timer: Timer


func _init() -> void:
	_build_menu()


func _ready() -> void:
	tooltip_text = "Arrange"
	_apply_panel_theme()
	_connect_theme_listener()
	if not pressed.is_connected(_on_trigger_pressed):
		pressed.connect(_on_trigger_pressed)
	if not mouse_entered.is_connected(_open_menu_from_pointer):
		mouse_entered.connect(_open_menu_from_pointer)
	if not mouse_exited.is_connected(_schedule_menu_close):
		mouse_exited.connect(_schedule_menu_close)
	focus_mode = Control.FOCUS_NONE


func _exit_tree() -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	if _panel.get_parent() == self:
		return
	_panel.hide()
	_panel.queue_free()
	_panel = null


## Enables Align when at least two areas are selected, and Distribute when at least three are.
func set_action_availability(align_enabled: bool, distribute_enabled: bool) -> void:
	for button in _align_buttons:
		button.disabled = not align_enabled
	for button in _distribute_buttons:
		button.disabled = not distribute_enabled
		if distribute_enabled:
			button.tooltip_text = _axis_tooltip(SelectionArrange.ACTION_DISTRIBUTE, _axis_of_button(button))
		else:
			button.tooltip_text = "Select at least 3 areas to distribute them"


func is_menu_open() -> bool:
	return _panel != null and _panel.visible


func close_menu() -> void:
	_toggle_menu(false)


func get_axis_button(action: StringName, axis: int) -> Button:
	var buttons: Array[Button] = _align_buttons if action == SelectionArrange.ACTION_ALIGN else _distribute_buttons
	if axis < 0 or axis >= buttons.size():
		return null
	return buttons[axis]


func _build_menu() -> void:
	if _panel != null:
		return
	_panel = PopupPanel.new()
	_panel.name = "ArrangeMenu"
	_panel.visible = false
	_panel.transparent = false
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	_panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 6)
	margin.add_child(rows)
	rows.add_child(_build_action_row(SelectionArrange.ACTION_ALIGN, "Align", _align_buttons))
	rows.add_child(_build_action_row(SelectionArrange.ACTION_DISTRIBUTE, "Distribute", _distribute_buttons))
	add_child(_panel)
	if not _panel.mouse_entered.is_connected(_cancel_menu_close):
		_panel.mouse_entered.connect(_cancel_menu_close)
	if not _panel.mouse_exited.is_connected(_schedule_menu_close):
		_panel.mouse_exited.connect(_schedule_menu_close)


func _build_action_row(action: StringName, title: String, bucket: Array[Button]) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = title + "Row"
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	for axis in [SelectionArrange.Axis.X, SelectionArrange.Axis.Y, SelectionArrange.Axis.Z]:
		var button := Button.new()
		button.name = "%s%s" % [title, SelectionArrange.axis_label(axis)]
		button.text = SelectionArrange.axis_label(axis)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = _axis_tooltip(action, axis)
		button.custom_minimum_size = Vector2(44, 36)
		button.pressed.connect(_on_axis_pressed.bind(action, axis))
		row.add_child(button)
		bucket.append(button)
	return row


func _axis_tooltip(action: StringName, axis: int) -> String:
	var axis_name := SelectionArrange.axis_label(axis)
	if action == SelectionArrange.ACTION_ALIGN:
		return "Align to the lowest %s" % axis_name
	return "Distribute evenly on %s" % axis_name


func _axis_of_button(button: Button) -> int:
	if button.text == "Y":
		return SelectionArrange.Axis.Y
	if button.text == "Z":
		return SelectionArrange.Axis.Z
	return SelectionArrange.Axis.X


func _on_trigger_pressed() -> void:
	_open_menu_from_pointer()


func _on_axis_pressed(action: StringName, axis: int) -> void:
	_toggle_menu(false)
	arrange_requested.emit(action, axis)


func _open_menu_from_pointer() -> void:
	# Same rule as the inspectors dropdown: hover opens the menu, a disabled trigger stays closed.
	if disabled:
		return
	_cancel_menu_close()
	if is_menu_open():
		return
	_toggle_menu(true)


func _toggle_menu(show_menu: bool) -> void:
	if _panel == null:
		return
	if not show_menu:
		_panel.hide()
		return
	_reparent_panel_to_root_viewport()
	_apply_panel_theme()
	_panel.reset_size()
	# PopupPanel is a Window. Content size comes from the child controls, not Control.get_combined_minimum_size.
	var menu_size: Vector2 = _panel.get_contents_minimum_size()
	_panel.position = _clamped_menu_position(menu_size)
	_panel.popup()


func _clamped_menu_position(menu_size: Vector2) -> Vector2:
	var anchor := _anchor_screen_position()
	var menu_y: float = size.y - float(MENU_ANCHOR_OVERLAP_PX)
	var position := anchor + Vector2(0, menu_y)
	var viewport := get_viewport()
	if viewport == null:
		return position
	var bounds: Vector2 = viewport.get_visible_rect().size
	if position.x + menu_size.x > bounds.x:
		position.x = maxf(0.0, bounds.x - menu_size.x)
	if position.y + menu_size.y > bounds.y:
		position.y = anchor.y - menu_size.y + float(MENU_ANCHOR_OVERLAP_PX)
	position.x = maxf(0.0, position.x)
	position.y = maxf(0.0, position.y)
	return position


func _reparent_panel_to_root_viewport() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	if _panel.get_parent() == tree.root:
		return
	var parent := _panel.get_parent()
	if parent != null:
		parent.remove_child(_panel)
	tree.root.add_child(_panel)


func _anchor_screen_position() -> Vector2:
	var anchor_pos := get_global_position()
	var anchor_viewport := get_viewport()
	if anchor_viewport is SubViewport:
		var container := anchor_viewport.get_parent()
		if container is SubViewportContainer:
			anchor_pos += (container as SubViewportContainer).get_global_position()
	return anchor_pos


func _ui_manager() -> Node:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("BrainVisualizer/UIManager")


func _connect_theme_listener() -> void:
	var ui := _ui_manager()
	if ui == null or not ui.has_signal("theme_changed"):
		return
	if not ui.theme_changed.is_connected(_apply_panel_theme):
		ui.theme_changed.connect(_apply_panel_theme)


func _apply_panel_theme(_theme: Theme = null) -> void:
	if _panel == null:
		return
	var ui := _ui_manager()
	if ui == null:
		return
	var loaded_theme: Theme = ui.get("loaded_theme") as Theme
	if loaded_theme == null:
		return
	_panel.theme = loaded_theme


func _ensure_menu_close_timer() -> Timer:
	if _menu_close_timer != null:
		return _menu_close_timer
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_close_menu_if_pointer_left)
	add_child(timer)
	_menu_close_timer = timer
	return timer


func _schedule_menu_close() -> void:
	if not is_menu_open():
		return
	_ensure_menu_close_timer().start(MENU_HOVER_CLOSE_DELAY_SEC)


func _cancel_menu_close() -> void:
	if _menu_close_timer != null:
		_menu_close_timer.stop()


func _close_menu_if_pointer_left() -> void:
	if not is_menu_open():
		return
	# Stay open while the pointer is on the trigger or the menu, matching the inspectors dropdown.
	if _is_pointer_over_menu() or _is_pointer_over_trigger():
		return
	_toggle_menu(false)


func _is_pointer_over_trigger() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var hovered: Control = viewport.gui_get_hovered_control()
	if hovered == null:
		return false
	return self == hovered or is_ancestor_of(hovered)


func _is_pointer_over_menu() -> bool:
	if _panel == null:
		return false
	var tree := get_tree()
	if tree != null and tree.root != null:
		var root_hovered: Control = tree.root.gui_get_hovered_control()
		if root_hovered != null and (_panel == root_hovered or _panel.is_ancestor_of(root_hovered)):
			return true
	return false
