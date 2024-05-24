extends GraphNode
class_name CBNodeConnectableBase
## Any graph node that can reciewve inputs and outputs

signal recursive_container_offset_changed(offset: Vector2)
signal input_container_offset_changed(offset: Vector2)
signal output_container_offset_changed(offset: Vector2)

var recursive_container_offset: Vector2:
	get: return _recursive_container_offset
var input_container_offset: Vector2:
	get: return _input_container_offset
var output_container_offset: Vector2:
	get: return _output_container_offset

var _recursives: VBoxContainer
var _inputs: VBoxContainer
var _outputs: VBoxContainer

var _recursive_container_offset: Vector2
var _input_container_offset: Vector2
var _output_container_offset: Vector2

func setup_base(recursive_path: NodePath, input_path: NodePath, output_path: NodePath) -> void:
	_inputs = get_node(input_path)
	_outputs = get_node(output_path)
	if !recursive_path.is_empty():
		_recursives =  get_node(recursive_path)
	
## Called by [CircuitBuilder] when adding a connection to the Node object
func CB_add_connection_terminal(connection_type: CBNodeTerminal.TYPE, text: StringName, port_prefab: PackedScene) -> CBNodeTerminal:
	# NOTE: We ask for the prefab as an input since its a waste to have every instance of this object store a copy in memory
	var terminal: CBNodeTerminal = port_prefab.instantiate()
	terminal.setup(connection_type, text, self)
	match(connection_type):
		CBNodeTerminal.TYPE.INPUT:
			_inputs.add_child(terminal)
			# Input added to the end, update only that one
			terminal.node_offset_has_changed(_get_positional_offset_for_terminal_container(_inputs))
			terminal.terminal_has_moved()
			
			# outputs were moved, update them all
			_apply_local_offset_to_terminal_container(_outputs, _get_positional_offset_for_terminal_container(_outputs))

		CBNodeTerminal.TYPE.OUTPUT:
			_outputs.add_child(terminal)
			# Output added to the end, update only that one
			terminal.node_offset_has_changed(_get_positional_offset_for_terminal_container(_outputs))
			terminal.terminal_has_moved()
		CBNodeTerminal.TYPE.RECURSIVE:
			_recursives.add_child(terminal)
			
			# outputs and inputs were moved, update them all
			_apply_local_offset_to_terminal_container(_inputs, _get_positional_offset_for_terminal_container(_inputs))
			_apply_local_offset_to_terminal_container(_outputs, _get_positional_offset_for_terminal_container(_outputs))
	return terminal


func _get_positional_offset_for_terminal_container(container: BoxContainer) -> Vector2:
	## Calculate the total offset, this continer may be a few levels down
	var current_node: Control = container
	var total_offset: Vector2 = Vector2(0,0)
	while !(current_node is CBNodeConnectableBase):
		total_offset += current_node.position
		current_node = current_node.get_parent()
	return total_offset

func _apply_local_offset_to_terminal_container(container: BoxContainer, new_local_offset: Vector2) -> void:
	for terminal: CBNodeTerminal in container.get_children():
		terminal.node_offset_has_changed(new_local_offset)
		terminal.terminal_has_moved()
	

