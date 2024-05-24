extends HBoxContainer
class_name CBNodeTerminal

signal terminal_moved()

enum TYPE {
	INPUT,
	OUTPUT,
	RECURSIVE
}

var terminal_type: TYPE:
	get: return _terminal_type

## The position this port is relative to the root [CBNodeConnectableBase]
var CB_node_offset: Vector2:
	get: return _CB_node_offset
	
var _CB_node_offset: Vector2
var _terminal_type: TYPE ## The type of terminal


var _tex_input: TextureRect
var _tex_output: TextureRect
var _tex_recursive: TextureRect
var _button: Button
var _parent_node: CBNodeConnectableBase

func setup(terminal_type_: TYPE, terminal_text: StringName, parent_node: CBNodeConnectableBase):
	_tex_input = $input
	_tex_output = $output
	_tex_recursive = $recurse
	_button = $Button
	_parent_node = parent_node
	
	_terminal_type = terminal_type_
	update_text(terminal_text)
	match(_terminal_type):
		TYPE.RECURSIVE:
			_tex_recursive.visible = true
		TYPE.INPUT:
			_tex_input.visible = true
		TYPE.OUTPUT:
			_tex_output.visible = true

func get_active_terminal() -> TextureRect:
	match(_terminal_type):
		TYPE.INPUT:
			return _tex_input
		TYPE.OUTPUT:
			return _tex_output
		_:
			return _tex_recursive


func update_text(new_text: StringName) -> void:
	_button.text = new_text

## Called by the root [CBNodeConnectableBase] when something happens that changes this objects relative position inside the node
func node_offset_has_changed(higher_offset: Vector2) -> void:
	_CB_node_offset = higher_offset + position

## Called by the root [CBNodeConnectableBase] when this terminal moves either as a response to this objects relative position (called after node_offset_has_changed) or if the whole node is moved in the GraphEdit
func terminal_has_moved() -> void:
	get_active_terminal().node_has_moved()


