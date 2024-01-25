extends BoxContainer
class_name MultiItemCollapsible

@export var texture_closed: Texture = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/top_bar_toggle_right.png")
@export var texture_open: Texture = preload("res://Feagi-Godot-Interface/UI/Resources/Icons/top_bar_toggle_left.png")
@export var is_vertical: bool = false
@export var child_nodes_to_run_toggle_collapse_on: Array[Control] = []
@export var start_open: bool = false

signal toggled(is_open: bool)

var all_togglable_children: Array[Control]:
	get: return _children
var opened: bool:
	get: return _opened

var _texture_button: TextureButton
var _children: Array[Control] = []
var _opened: bool

func _ready() -> void:
	_texture_button = $texture_button
	for child: Control in ($Place_child_nodes_here).get_children():
		_children.append(child)
	toggle_open_state(start_open, true)
	vertical = is_vertical
	($Place_child_nodes_here).vertical = is_vertical
	_opened = start_open

## toggles whether the UI is open or not
func toggle_open_state(is_open: bool, repress_signal: bool = false) -> void:
	_opened = is_open
	for child in _children:
		if child not in child_nodes_to_run_toggle_collapse_on:
			child.visible = is_open
		else:
			(child as Variant).toggle_collapse(!is_open) #Cursed
	
	_toggle_button_indicator(is_open)
	
	if !repress_signal:
		toggled.emit(is_open)

func toggle() -> void:
	toggle_open_state(!_opened)

func _toggle_button_indicator(is_open: bool) -> void:
	if is_open:
		_texture_button.texture_normal = texture_closed
		_texture_button.texture_hover = texture_closed
		_texture_button.texture_pressed = texture_closed
	else:
		_texture_button.texture_normal = texture_open
		_texture_button.texture_hover = texture_open
		_texture_button.texture_pressed = texture_open

