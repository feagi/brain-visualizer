extends TextureButton
class_name ToggleImageDropDown

signal user_change_option(label: StringName, index: int)

@export var is_vertical: bool = true
@export var initial_index: int = -1
@export var fade_out_selected_option: bool = true
## When false, option presses act like menu actions (emit + close) without changing trigger icon/selection state.
@export var select_on_press: bool = true

var _panel: PopupPanel
var _button_holder: BoxContainer
var _current_setting_index: int = -2 # start withs omething invalid that the initial index overrides on start

func _ready() -> void:
	_panel = $PanelContainer
	_button_holder = $PanelContainer/BoxContainer
	# Keep panel in-scene to preserve child-node paths used by parent controls.
	# PopupPanel renders above normal controls when opened via popup().
	_button_holder.vertical = is_vertical
	_setup_all_buttons()
	if select_on_press:
		set_option(initial_index, false)
	_toggle_menu(false)
	focus_exited.connect(_toggle_menu.bind(false))

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
	if _is_menu_shown():
		_toggle_menu(false)
		return
	_toggle_menu(true)

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
		_panel.position = anchor_screen + Vector2(0, size.y)
		_panel.popup()
		grab_focus()
	else:
		_panel.hide()
		release_focus()


## Match [method FilterableListPopup._reparent_to_root_viewport].
func _reparent_panel_to_root_viewport() -> void:
	if _panel == null:
		return
	var root_viewport := get_tree().root
	if _panel.get_parent() == root_viewport:
		return
	var p := _panel.get_parent()
	if p != null:
		p.remove_child(_panel)
	root_viewport.add_child(_panel)


## Match [method FilterableListPopup._get_anchor_screen_position] for this trigger control.
func _get_anchor_screen_position() -> Vector2:
	var anchor_pos := get_global_position()
	var anchor_viewport := get_viewport()
	if anchor_viewport is SubViewport:
		var container := anchor_viewport.get_parent()
		if container is SubViewportContainer:
			anchor_pos += (container as SubViewportContainer).get_global_position()
	return anchor_pos

func _is_menu_shown() -> bool:
	return _panel.visible

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

func _set_empty() -> void:
	texture_normal = null
	texture_hover = null
	texture_pressed = null
	texture_disabled = null
