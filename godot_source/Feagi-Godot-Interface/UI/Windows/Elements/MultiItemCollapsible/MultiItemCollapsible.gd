extends BoxContainer
class_name MultiItemCollapsible

@export var is_vertical: bool = false
@export var child_nodes_to_run_toggle_collapse_on: Array[Control] = []
@export var text_open: StringName = "►"
@export var text_closed: StringName = "◄"
@export var start_open: bool = false

signal toggled(is_open: bool)

var all_togglable_children: Array[Control]:
	get: return _children
var opened: bool:
	get: return _opened

var _text_button: Button
var _children: Array[Control] = []
var _opened: bool

func _ready() -> void:
	_text_button = $text_button
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
		_text_button.text = text_open	
	else:
		_text_button.text = text_closed

