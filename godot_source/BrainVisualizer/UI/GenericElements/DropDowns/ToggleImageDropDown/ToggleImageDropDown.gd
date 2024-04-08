extends TextureButton
class_name ToggleImageDropDown

signal user_change_option(label: StringName, index: int)

@export var is_vertical: bool = true
@export var initial_index: int = -1
@export var fade_out_selected_option: bool = true

var _panel: PanelContainer
var _button_holder: BoxContainer
var _current_setting_index: int = -2 # start withs omething invalid that the initial index overrides on start

func _ready() -> void:
	_panel = $PanelContainer
	_button_holder = $PanelContainer/BoxContainer
	_button_holder.vertical = is_vertical
	_setup_all_buttons()
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
	_panel.visible = show_menu
	var child_button: TextureButton
	if show_menu:
		_panel.position = Vector2(0,0)
		for child in _button_holder.get_children():
			if !(child is TextureButton):
				push_error("Non-TextureButton found in ToggleImageDropDown! Skipping!")
				continue
			child_button = (child as TextureButton)
			child_button.size = Vector2(0,0)
		_panel.size = Vector2(0,0)
		grab_focus()
	else:
		release_focus()

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
		child_button.pressed.connect(set_option.bind(index)) # bind the index of the button to the signal such that when the call is made, we know which button made it
		index += 1

func _set_empty() -> void:
	texture_normal = null
	texture_hover = null
	texture_pressed = null
	texture_disabled = null
