extends GraphNode
class_name CBNodeConnectableBase
## Any graph node that can reciewve inputs and outputs

signal node_moved(self_ref: CBNodeConnectableBase, new_offset_pos: Vector2i)
signal recursive_container_offset_changed()
signal input_container_offset_changed()
signal output_container_offset_changed()

var _dragged: bool = false
var _recursives: VBoxContainer
var _inputs: VBoxContainer
var _outputs: VBoxContainer

func _gui_input(event):
	if !(event is InputEventMouseButton): return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT: return
	if mouse_event.double_click:
		_on_double_left_click()
		print("double")
		return
	else:
		if !mouse_event.is_pressed(): return
		await get_tree().create_timer(0.1).timeout # wait a small moment to ensure we arent dragging
		if _dragged: return
		_on_single_left_click()
		print("single")

func setup_base(recursive_path: NodePath, input_path: NodePath, output_path: NodePath) -> void:
	dragged.connect(_on_finish_drag)
	_inputs = get_node(input_path)
	_outputs = get_node(output_path)
	if !recursive_path.is_empty():
		_recursives =  get_node(recursive_path)
	position_offset_changed.connect(_on_node_move)
	position_offset_changed.connect(_on_position_changed)
	_dragged = false
	minimum_size_changed.connect(_on_node_move)


	
## Called by [CircuitBuilder] when adding a connection to the Node object
func CB_add_connection_terminal(connection_type: CBNodeTerminal.TYPE, text: StringName, port_prefab: PackedScene) -> CBNodeTerminal:
	# NOTE: We ask for the prefab as an input since its a waste to have every instance of this object store a copy in memory
	var terminal: CBNodeTerminal = port_prefab.instantiate()
	terminal.tree_exited.connect(_force_shrink)
	match(connection_type):
		CBNodeTerminal.TYPE.INPUT:
			_inputs.add_child(terminal)
			terminal.setup(connection_type, text, self, input_container_offset_changed)

		CBNodeTerminal.TYPE.OUTPUT:
			_outputs.add_child(terminal)
			terminal.setup(connection_type, text, self, output_container_offset_changed)

		CBNodeTerminal.TYPE.RECURSIVE:
			_recursives.add_child(terminal)
			terminal.setup(connection_type, text, self, recursive_container_offset_changed)

		CBNodeTerminal.TYPE.INPUT_OPEN:
			_inputs.add_child(terminal)
			terminal.setup(connection_type, text, self, input_container_offset_changed)

		CBNodeTerminal.TYPE.OUTPUT_OPEN:
			_outputs.add_child(terminal)
			terminal.setup(connection_type, text, self, output_container_offset_changed)
	
	terminal.button.resized.connect(_on_node_move)
	#terminal.active_port.resized.connect(_on_node_move)
	#terminal.terminal_about_to_be_deleted.connect(_on_node_move)
	return terminal

func get_number_inputs() -> int:
	return _inputs.get_child_count()

func get_number_outputs() -> int:
	return _outputs.get_child_count()

func _on_single_left_click() -> void:
	pass

func _on_double_left_click() -> void:
	pass

func _on_node_move() -> void:
	recursive_container_offset_changed.emit()
	input_container_offset_changed.emit()
	output_container_offset_changed.emit()

func _on_finish_drag(_from_position: Vector2, to_position: Vector2) -> void:
	_dragged = false
	node_moved.emit(self, to_position)

func _on_position_changed() -> void:
	_dragged = true

func _force_shrink() -> void:
	size = Vector2(0,0)
