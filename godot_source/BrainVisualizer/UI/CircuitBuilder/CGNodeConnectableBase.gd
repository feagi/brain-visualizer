extends GraphNode
class_name CGNodeConnectableBase
## Any graph node that can reciewve inputs and outputs

var _recursives: VBoxContainer
var _inputs: VBoxContainer
var _outputs: VBoxContainer


func setup_base(recursive_path: NodePath, input_path: NodePath, output_path: NodePath) -> void:
	_inputs = get_node(input_path)
	_outputs = get_node(output_path)
	if !recursive_path.is_empty():
		_recursives =  get_node(recursive_path)
	
## Called by [CircuitBuilder] when adding a connection to the Node object
func CB_add_connection_terminal(connection_type: CBNodeTerminal.TYPE, text: StringName, port_prefab: PackedScene) -> CBNodeTerminal:
	# NOTE: We ask for the prefab as an input since its a waste to have every instance of this object store a copy in memory
	var terminal: CBNodeTerminal = port_prefab.instantiate()
	terminal.setup(connection_type, text)
	match(connection_type):
		CBNodeTerminal.TYPE.INPUT:
			_inputs.add_child(terminal)
		CBNodeTerminal.TYPE.OUTPUT:
			_outputs.add_child(terminal)
		CBNodeTerminal.TYPE.RECURSIVE:
			_recursives.add_child(terminal)
	
	return terminal


