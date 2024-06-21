extends HBoxContainer
class_name CBNodeTerminal

signal terminal_about_to_be_deleted() 

enum TYPE {
	INPUT,
	OUTPUT,
	RECURSIVE,
	INPUT_OPEN,
	OUTPUT_OPEN
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
			_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		TYPE.INPUT:
			_tex_input.visible = true
			_active_port = _tex_input
			_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		TYPE.OUTPUT:
			_tex_output.visible = true
			_active_port = _tex_output
			_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		TYPE.INPUT_OPEN:
			_tex_input.visible = true
			_tex_input.texture = load("res://BrainVisualizer/UI/CircuitBuilder/CorticalNode/Resources/cb-port-ring.png")
			_active_port = _tex_input
			_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			
		TYPE.OUTPUT_OPEN:
			_tex_output.visible = true
			_active_port = _tex_output
			_tex_output.texture = load("res://BrainVisualizer/UI/CircuitBuilder/CorticalNode/Resources/cb-port-ring.png")
			_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
			
	_active_port.setup(parent_node, signal_to_report_updated_position)
	_active_port.deletion_requested.connect(_port_reporting_deletion)


func update_text(new_text: StringName) -> void:
	_button.text = new_text

## In the case of open ports, register the partial mapping such that this port doesnt need to be instructed by a [CBLineInterTerminal] to do things
func register_partial_mapping(partial_mapping: PartialMappingSet) -> void:
	partial_mapping.mappings_about_to_be_deleted.connect(_port_reporting_deletion)

func _port_reporting_deletion() -> void:
	terminal_about_to_be_deleted.emit()
	queue_free()
