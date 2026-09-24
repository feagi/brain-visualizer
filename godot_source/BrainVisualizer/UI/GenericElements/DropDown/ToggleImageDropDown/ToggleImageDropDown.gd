extends TextureButton
class_name ToggleImageDropDown

signal user_change_option(label: StringName, index: int)

@export var is_vertical: bool = true
@export var initial_index: int = -1
@export var fade_out_selected_option: bool = true
## When false, option presses act like menu actions (emit + close) without changing trigger icon/selection state.
@export var select_on_press: bool = true
## Open the menu while the pointer is over the trigger. Used by the Inspectors dropdown.
@export var open_on_hover: bool = false

## Overlap so the pointer can move from the trigger into the menu without a gap.
const MENU_ANCHOR_OVERLAP_PX: int = 4
## Grace period while the pointer crosses from the trigger into the menu.
const MENU_HOVER_CLOSE_DELAY_SEC: float = 0.15

var _panel: PopupPanel
var _button_holder: BoxContainer
var _current_setting_index: int = -2 # start withs omething invalid that the initial index overrides on start
var _menu_close_timer: Timer = null

func _ready() -> void:
	_panel = $PanelContainer
	_button_holder = $PanelContainer/BoxContainer
	# Keep panel in-scene to preserve child-node paths used by parent controls.
	# PopupPanel renders above normal controls when opened via popup().
	# When reparented to the root viewport, the panel must carry BV.UI.loaded_theme so tooltips
	# on dropdown items use the same TooltipLabel size as top-bar controls (FilterableListPopup pattern).
	if BV.UI:
		if not BV.UI.theme_changed.is_connected(_on_bv_theme_changed):
			BV.UI.theme_changed.connect(_on_bv_theme_changed)
		_apply_panel_theme()
	_button_holder.vertical = is_vertical
	_setup_all_buttons()
	if select_on_press:
		set_option(initial_index, false)
	_toggle_menu(false)
	focus_exited.connect(_on_trigger_focus_exited)
	if open_on_hover:
		mouse_entered.connect(_open_menu_from_pointer)
		mouse_exited.connect(_schedule_menu_close)
		if not _panel.mouse_entered.is_connected(_cancel_menu_close):
			_panel.mouse_entered.connect(_cancel_menu_close)
		if not _panel.mouse_exited.is_connected(_schedule_menu_close):
			_panel.mouse_exited.connect(_schedule_menu_close)

## Sets the selected button for the dropdown
func set_option(option: int, should_emit_signal: bool = true, close_dropdown_menu: bool = true) -> void:
	if option == -1:
		_set_empty()
		return
	if option < -1:
		push_error("Unable to set Texture Dropdown to an invalid negative index!")
		return
	if option > get_number_of_buttons():
		push_error("Unable to set Texture Dropdown to an option with an index larger than available!")
		return
	
	if _current_setting_index != -2:
		var old_button: TextureButton = _get_texture_button(_current_setting_index)
		old_button.disabled = false
		
	_current_setting_index = option
	var new_button: TextureButton = _get_texture_button(option)
	texture_normal = new_button.texture_normal
	texture_hover = new_button.texture_hover
	texture_pressed = new_button.texture_pressed
	texture_disabled = new_button.texture_disabled
	new_button.disabled = true
	if close_dropdown_menu:
		_toggle_menu(false)
	if should_emit_signal:
		user_change_option.emit(new_button.name, option)

func dropdown_toggle() -> void:
	if open_on_hover:
		_open_menu_from_pointer()
		return
	if _is_menu_shown():
		_toggle_menu(false)
		return
	_toggle_menu(true)


## Hover-open is opt-in. A disabled trigger must stay closed.
static func should_open_menu_on_hover(open_on_hover_enabled: bool, button_disabled: bool) -> bool:
	return open_on_hover_enabled and not button_disabled


## Keep the menu open while the pointer is on the trigger or the popup.
static func should_keep_menu_open_while_pointer_inside(pointer_over_menu: bool, pointer_over_button: bool) -> bool:
	return pointer_over_menu or pointer_over_button

func get_number_of_buttons() -> int:
	return _button_holder.get_child_count()

func _toggle_menu(show_menu: bool) -> void:
	if _panel == null:
		return
	var child_button: TextureButton
	if show_menu:
		for child in _button_holder.get_children():
			if !(child is TextureButton):
				push_error("Non-TextureButton found in ToggleImageDropDown! Skipping!")
				continue
			child_button = (child as TextureButton)
			child_button.size = Vector2(0,0)
		_panel.size = Vector2(0,0)
		# Same as FilterableListPopup: SubViewport controls report "global" coords in viewport space;
		# reparent the panel to the root viewport and use screen-space anchor so the menu sits under the button.
		_reparent_panel_to_root_viewport()
		var anchor_screen := _get_anchor_screen_position()
		var menu_y: float = size.y
		if open_on_hover:
			menu_y -= float(MENU_ANCHOR_OVERLAP_PX)
		_panel.position = anchor_screen + Vector2(0, menu_y)
		_panel.popup()
		grab_focus()
	else:
		_panel.hide()
		release_focus()


## Root-reparented popups must use [member UIManager.loaded_theme] so tooltip labels match the rest of the UI.
func _on_bv_theme_changed(_new_theme: Theme) -> void:
	_apply_panel_theme()


func _apply_panel_theme() -> void:
	if _panel == null or BV.UI == null:
		return
	_panel.theme = BV.UI.loaded_theme


## Match [method FilterableListPopup._reparent_to_root_viewport].
func _reparent_panel_to_root_viewport() -> void:
	if _panel == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var root_viewport := tree.root
	if root_viewport == null:
		return
	if _panel.get_parent() == root_viewport:
		return
	var p := _panel.get_parent()
	if p != null:
		p.remove_child(_panel)
	root_viewport.add_child(_panel)
	_apply_panel_theme()


## Match [method FilterableListPopup._get_anchor_screen_position] for this trigger control.
func _get_anchor_screen_position() -> Vector2:
	var anchor_pos := get_global_position()
	var anchor_viewport := get_viewport()
	if anchor_viewport == null:
		return anchor_pos
	if anchor_viewport is SubViewport:
		var container := anchor_viewport.get_parent()
		if container is SubViewportContainer:
			anchor_pos += (container as SubViewportContainer).get_global_position()
	return anchor_pos

func _is_menu_shown() -> bool:
	return _panel.visible


## True while the popup menu is visible (after [method _toggle_menu](true) / [method popup]).
func is_menu_open() -> bool:
	return _is_menu_shown()


func _get_texture_button(index: int) -> TextureButton:
	return _button_holder.get_child(index)
	

func _setup_all_buttons() -> void:
	var index: int = 0
	var child_button: TextureButton
	for child in _button_holder.get_children():
		if !(child is TextureButton):
			push_error("Non-TextureButton found in ToggleImageDropDown! Skipping!")
			continue
		# copy all internal settings to child buttons
		child_button = (child as TextureButton)
		child_button.ignore_texture_size = ignore_texture_size
		child_button.stretch_mode = stretch_mode
		child_button.focus_mode = Control.FOCUS_NONE # prevent menu from closing when we click a button
		
		# connect signals
		if child_button.pressed.is_connected(set_option):
			child_button.pressed.disconnect(set_option) # prevent duplicate connections
		if child_button.pressed.is_connected(_emit_action_option):
			child_button.pressed.disconnect(_emit_action_option)
		if select_on_press:
			# bind the index of the button to the signal such that when the call is made, we know which button made it
			child_button.pressed.connect(set_option.bind(index))
		else:
			child_button.pressed.connect(_emit_action_option.bind(index))
		index += 1

func _emit_action_option(index: int) -> void:
	var button := _get_texture_button(index)
	user_change_option.emit(button.name, index)
	_toggle_menu(false)

func _on_trigger_focus_exited() -> void:
	if open_on_hover:
		call_deferred("_close_menu_if_pointer_left")
		return
	_toggle_menu(false)


## Open from a hover or click. A second press does not close the menu.
func _open_menu_from_pointer() -> void:
	if not should_open_menu_on_hover(open_on_hover, disabled):
		return
	_cancel_menu_close()
	if _is_menu_shown():
		return
	_toggle_menu(true)


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
	if not _is_menu_shown():
		return
	_ensure_menu_close_timer().start(MENU_HOVER_CLOSE_DELAY_SEC)


func _cancel_menu_close() -> void:
	if _menu_close_timer != null:
		_menu_close_timer.stop()


func _close_menu_if_pointer_left() -> void:
	if not _is_menu_shown():
		return
	if should_keep_menu_open_while_pointer_inside(_is_pointer_over_menu(), _is_pointer_over_trigger()):
		return
	_toggle_menu(false)


func _is_pointer_over_trigger() -> bool:
	var vp := get_viewport()
	if vp == null:
		return false
	var hovered: Control = vp.gui_get_hovered_control()
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
	var local_viewport := get_viewport()
	if local_viewport != null:
		var local_hovered: Control = local_viewport.gui_get_hovered_control()
		if local_hovered != null and (_panel == local_hovered or _panel.is_ancestor_of(local_hovered)):
			return true
	return _panel.get_visible_rect().has_point(_panel.get_mouse_position())


func _set_empty() -> void:
	texture_normal = null
	texture_hover = null
	texture_pressed = null
	texture_disabled = null
