extends TextureButton
class_name ToggleImageDropDown

signal user_change_option(label: StringName, index: int)

@export var dimensions: Vector2i = Vector2i(1,1)
@export var is_vertical: bool = true
@export var initial_index: int = -1

var current_setting_name: StringName:
	get: return _current_setting_name

var _current_setting_name: StringName
var _panel: PanelContainer
var _button_holder: BoxContainer



func _ready() -> void:
	custom_minimum_size = dimensions
	_panel = $PanelContainer
	_button_holder = $PanelContainer/BoxContainer
	_button_holder.vertical = is_vertical
	_setup_all_buttons()
	set_option(initial_index, false)
	_toggle_menu(false)
	focus_exited.connect(_toggle_menu.bind(false))


## Sets the selected button for the dropdown
func set_option(option: int, emit_signal: bool = true, close_dropdown_menu: bool = true) -> void:
	if option == -1:
		_set_empty()
		return
	if option < -1:
		push_error("Unable to set Texture Dropdown to an invalid negative index!")
		return
	if option > get_number_of_buttons():
		push_error("Unable to set Texture Dropdown to an option with an index larger than available!")
		return
	var button: TextureButton = _get_texture_button(option)
	texture_normal = button.texture_normal
	texture_hover = button.texture_hover
	texture_pressed = button.texture_pressed
	texture_disabled = button.texture_disabled
	if close_dropdown_menu:
		_toggle_menu(false)
	if emit_signal:
		user_change_option.emit(button.name, option)

func dropdown_toggle() -> void:
	if _is_menu_shown():
		_toggle_menu(false)
		return
	_toggle_menu(true)

func get_number_of_buttons() -> int:
	return _button_holder.get_child_count()

func _toggle_menu(show_menu: bool) -> void:
	_panel.visible = show_menu
	if show_menu:
		var offset: Vector2i
		if is_vertical:
			offset = Vector2(0, size.y)
		else:
			offset = Vector2(size.x, 0)
		_panel.position = offset 
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
		child_button.custom_minimum_size = dimensions
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