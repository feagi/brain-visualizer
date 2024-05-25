extends GraphNode
class_name CBNodeConnectableBase
## Any graph node that can reciewve inputs and outputs

signal recursive_container_offset_changed()
signal input_container_offset_changed()
signal output_container_offset_changed()



var _recursives: VBoxContainer
var _inputs: VBoxContainer
var _outputs: VBoxContainer

var _recursive_container_offset: Vector2


func setup_base(recursive_path: NodePath, input_path: NodePath, output_path: NodePath) -> void:
	_inputs = get_node(input_path)
	_outputs = get_node(output_path)
	if !recursive_path.is_empty():
		_recursives =  get_node(recursive_path)
	position_offset_changed.connect(_on_node_move)
	resized.connect(_on_node_move)
	
	
## Called by [CircuitBuilder] when adding a connection to the Node object
func CB_add_connection_terminal(connection_type: CBNodeTerminal.TYPE, text: StringName, port_prefab: PackedScene) -> CBNodeTerminal:
	# NOTE: We ask for the prefab as an input since its a waste to have every instance of this object store a copy in memory
	var terminal: CBNodeTerminal = port_prefab.instantiate()
	match(connection_type):
		CBNodeTerminal.TYPE.INPUT:
			_inputs.add_child(terminal)
			terminal.setup(CBNodeTerminal.TYPE.INPUT, text, self, input_container_offset_changed)
			output_container_offset_changed.emit() # because output is below, so all are moved

		CBNodeTerminal.TYPE.OUTPUT:
			_outputs.add_child(terminal)
			terminal.setup(CBNodeTerminal.TYPE.OUTPUT, text, self, output_container_offset_changed)
			# nothing below, nothing to do

		CBNodeTerminal.TYPE.RECURSIVE:
			_recursives.add_child(terminal)
			terminal.setup(CBNodeTerminal.TYPE.RECURSIVE, text, self, recursive_container_offset_changed)
			input_container_offset_changed.emit() # both inpouts and outputs are below recursives
			output_container_offset_changed.emit()

	return terminal

func _on_node_move() -> void:
	recursive_container_offset_changed.emit()
	input_container_offset_changed.emit()
	output_container_offset_changed.emit()
	print(position_offset)
