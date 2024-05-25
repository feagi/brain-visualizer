extends HBoxContainer
class_name CBNodeTerminal

signal terminal_about_to_be_deleted() 

enum TYPE {
	INPUT,
	OUTPUT,
	RECURSIVE
}

var terminal_type: TYPE:
	get: return _terminal_type
var active_port: CBNodePort:
	get: return _active_port

var _terminal_type: TYPE ## The type of terminal
var _active_port: CBNodePort = null # becomes valid after setup

var _tex_input: CBNodePort
var _tex_output: CBNodePort
var _tex_recursive: CBNodePort
var _button: Button
var _parent_node: CBNodeConnectableBase

func setup(terminal_type_: TYPE, terminal_text: StringName, parent_node: CBNodeConnectableBase, signal_to_report_updated_position: Signal):
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
			_active_port = _tex_recursive
		TYPE.INPUT:
			_tex_input.visible = true
			_active_port = _tex_input
		TYPE.OUTPUT:
			_tex_output.visible = true
			_active_port = _tex_output
	_active_port.setup(parent_node, signal_to_report_updated_position)


func update_text(new_text: StringName) -> void:
	_button.text = new_text

func _port_reporting_deletion() -> void:
	terminal_about_to_be_deleted.emit()
	queue_free()

