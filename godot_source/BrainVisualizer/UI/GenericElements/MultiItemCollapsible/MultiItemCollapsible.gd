extends BoxContainer
class_name MultiItemCollapsible

@export var texture_closed: Texture
@export var setup_as_vertical: bool = false
@export var child_nodes_to_run_toggle_collapse_on: Array[Control] = []
@export var start_open: bool = false

signal toggled(is_open: bool)

var all_togglable_children: Array[Control]:
	get: return _children
var opened: bool:
	get: return _opened
	
var _close_button_default_scale: Vector2i
var _texture_button: TextureButton
var _children: Array[Control] = []
var _opened: bool

func _ready() -> void:
	_texture_button = $texture_button
	_close_button_default_scale = _texture_button.custom_minimum_size
	for child: Control in ($Place_child_nodes_here).get_children():
		_children.append(child)
		_texture_button.texture_normal = texture_closed
		_texture_button.texture_hover = texture_closed
		_texture_button.texture_pressed = texture_closed
	toggle_open_state(start_open, true)
	vertical = setup_as_vertical
	($Place_child_nodes_here).vertical = setup_as_vertical
	_opened = start_open
	_theme_updated()
	BV.UI.theme_changed.connect(_theme_updated)

## toggles whether the UI is open or not
func toggle_open_state(is_open: bool, repress_signal: bool = false) -> void:
	_opened = is_open
	for child in _children:
		if child not in child_nodes_to_run_toggle_collapse_on:
			child.visible = is_open
		else:
			(child as Variant).toggle_collapse(!is_open) #Cursed
	
	_texture_button.flip_h = is_open
	
	if !repress_signal:
		toggled.emit(is_open)

func toggle() -> void:
	toggle_open_state(!_opened)

func _theme_updated(_theme = null) -> void:
	_texture_button.custom_minimum_size = BV.UI.loaded_theme_scale.x * _close_button_default_scale
