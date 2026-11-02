extends GraphNode
class_name CBNodeConnectableBase
## Any graph node that can reciewve inputs and outputs

signal node_moved(self_ref: CBNodeConnectableBase, new_offset_pos: Vector2i)
signal recursive_container_offset_changed()
signal input_container_offset_changed()
signal output_container_offset_changed()

var _dragged: bool = false
## True while assigning [member position_offset] from FEAGI/cache so [member position_offset_changed] is not treated as user drag.
var _applying_position_from_model: bool = false
## Set when the user finished a drag with meaningful movement; suppresses the deferred "click" that opens the quick menu.
var _suppress_pending_click_after_drag: bool = false
## Minimum graph-space movement on [signal GraphNode.dragged] to count as a drag (not a click).
const _DRAG_SUPPRESS_CLICK_MIN_DISTANCE: float = 3.0
## Screen-space pointer movement while the button is down cancels treating the gesture as a click.
const _MOUSE_MOVE_CANCEL_CLICK_PX: float = 8.0
## Wait after release before emitting a single click so a second press can register as double-click.
const _SINGLE_CLICK_AFTER_RELEASE_DELAY_S: float = 0.2

var _awaiting_left_release: bool = false
var _mouse_down_screen_pos: Vector2 = Vector2.ZERO
var _release_click_cancelled: bool = false
## Incremented on each left press; stale deferred single-clicks compare against this.
var _left_click_generation: int = 0

var _recursives: VBoxContainer
var _inputs: VBoxContainer
var _outputs: VBoxContainer

var t_v_1: Vector2

func _gui_input(event):
	if event is InputEventMouseMotion:
		if _awaiting_left_release and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if get_global_mouse_position().distance_to(_mouse_down_screen_pos) >= _MOUSE_MOVE_CANCEL_CLICK_PX:
				_release_click_cancelled = true
		return

	if !(event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		_left_click_generation += 1
		if mouse_event.double_click:
			_awaiting_left_release = false
			_on_double_left_click()
			return
		_suppress_pending_click_after_drag = false
		_dragged = false
		_awaiting_left_release = true
		_release_click_cancelled = false
		_mouse_down_screen_pos = get_global_mouse_position()
		return

	# Button released: never open the quick menu until the button is up (and not a drag / double-click).
	if !_awaiting_left_release:
		return
	_awaiting_left_release = false
	if _release_click_cancelled:
		return
	var generation_at_release: int = _left_click_generation
	await get_tree().create_timer(_SINGLE_CLICK_AFTER_RELEASE_DELAY_S).timeout
	if generation_at_release != _left_click_generation:
		return
	# Let [signal GraphNode.dragged] / [method _on_finish_drag] run so [member _suppress_pending_click_after_drag] is set.
	await get_tree().process_frame
	if _suppress_pending_click_after_drag:
		_suppress_pending_click_after_drag = false
		return
	if _dragged:
		return
	_on_single_left_click()

func setup_base(recursive_path: NodePath, input_path: NodePath, output_path: NodePath) -> void:
	dragged.connect(_on_finish_drag)
	_inputs = get_node_or_null(input_path)
	_outputs = get_node_or_null(output_path)
	if !recursive_path.is_empty():
		_recursives = get_node_or_null(recursive_path)
	position_offset_changed.connect(_on_node_move)
	position_offset_changed.connect(_on_position_changed)
	_dragged = false
	minimum_size_changed.connect(_on_node_move)
	# Group containers stay in the scene for their node paths, but a hidden child is not a slot.
	# Each connection row is added as its own visible child so it can have one port.
	if _inputs != null:
		_inputs.visible = false
	if _outputs != null:
		_outputs.visible = false
	if _recursives != null:
		_recursives.visible = false


## Assign [member position_offset] from genome/cache updates. Does not set [member _dragged] (unlike user dragging the node).
func apply_model_position_offset(new_position: Vector2i) -> void:
	_applying_position_from_model = true
	position_offset = new_position
	_applying_position_from_model = false


	
## Called by [CircuitBuilder] when adding a connection to the Node object
func CB_add_connection_terminal(connection_type: CBNodeTerminal.TYPE, text: StringName, port_prefab: PackedScene) -> CBNodeTerminal:
	# NOTE: We ask for the prefab as an input since its a waste to have every instance of this object store a copy in memory
	var terminal: CBNodeTerminal = port_prefab.instantiate()
	terminal.tree_exited.connect(_on_terminal_left)
	var position_signal: Signal
	match(connection_type):
		CBNodeTerminal.TYPE.INPUT, CBNodeTerminal.TYPE.INPUT_OPEN:
			position_signal = input_container_offset_changed
		CBNodeTerminal.TYPE.OUTPUT, CBNodeTerminal.TYPE.OUTPUT_OPEN:
			position_signal = output_container_offset_changed
		CBNodeTerminal.TYPE.RECURSIVE:
			if _recursives == null or !is_instance_valid(_recursives):
				push_warning("CBNodeConnectableBase: RECURSIVE container is null/invalid; skipping add_child")
				terminal.queue_free()
				return null
			position_signal = recursive_container_offset_changed
		_:
			terminal.queue_free()
			return null
	add_child(terminal)
	move_child(terminal, _tree_index_for_terminal(connection_type, terminal))
	terminal.setup(connection_type, text, self, position_signal)
	_refresh_terminal_slots()
	terminal.button.resized.connect(_on_node_move)
	_on_node_move()
	return terminal


func _on_terminal_left() -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_force_shrink()
	_refresh_terminal_slots()
	_on_node_move()


## Recursive rows, then inputs, then outputs. Hidden group containers are skipped by the layout.
func _tree_index_for_terminal(connection_type: CBNodeTerminal.TYPE, terminal: CBNodeTerminal) -> int:
	var rank := _terminal_rank(connection_type)
	for i: int in get_child_count():
		var other := get_child(i) as CBNodeTerminal
		if other == null or other == terminal:
			continue
		if _terminal_rank(other.terminal_type) > rank:
			return i
	return get_child_count() - 1


func _terminal_rank(connection_type: CBNodeTerminal.TYPE) -> int:
	match connection_type:
		CBNodeTerminal.TYPE.RECURSIVE:
			return 0
		CBNodeTerminal.TYPE.INPUT, CBNodeTerminal.TYPE.INPUT_OPEN:
			return 1
		_:
			return 2


func _refresh_terminal_slots() -> void:
	var input_index := 0
	var output_index := 0
	for child: Node in get_children():
		var terminal := child as CBNodeTerminal
		if terminal == null or not is_instance_valid(terminal):
			continue
		var slot_index := GraphNodeStyle.visible_slot_index(self, terminal)
		if slot_index < 0:
			continue
		var left := false
		var right := false
		var kind: StringName = &"full"
		match terminal.terminal_type:
			CBNodeTerminal.TYPE.INPUT:
				left = true
			CBNodeTerminal.TYPE.INPUT_OPEN:
				left = true
				kind = &"ring"
			CBNodeTerminal.TYPE.OUTPUT:
				right = true
			CBNodeTerminal.TYPE.OUTPUT_OPEN:
				right = true
				kind = &"ring"
			CBNodeTerminal.TYPE.RECURSIVE:
				left = true
				kind = &"recursive"
		GraphNodeStyle.configure_row_slot(self, slot_index, left, right, GraphNodeStyle.port_icon(kind))
		if left:
			terminal.assign_graph_port(true, input_index)
			input_index += 1
		elif right:
			terminal.assign_graph_port(false, output_index)
			output_index += 1


func get_number_inputs() -> int:
	return _count_terminals(true)

func get_number_outputs() -> int:
	return _count_terminals(false)


func _count_terminals(inputs: bool) -> int:
	var count := 0
	for child: Node in get_children():
		var terminal := child as CBNodeTerminal
		if terminal == null:
			continue
		var is_input := terminal.terminal_type == CBNodeTerminal.TYPE.INPUT or terminal.terminal_type == CBNodeTerminal.TYPE.INPUT_OPEN
		var is_output := terminal.terminal_type == CBNodeTerminal.TYPE.OUTPUT or terminal.terminal_type == CBNodeTerminal.TYPE.OUTPUT_OPEN
		if (inputs and is_input) or (not inputs and is_output):
			count += 1
	return count

func _on_single_left_click() -> void:
	pass

func _on_double_left_click() -> void:
	pass

func _on_node_move() -> void:
	queue_redraw()
	recursive_container_offset_changed.emit()
	input_container_offset_changed.emit()
	output_container_offset_changed.emit()

func _on_finish_drag(from_position: Vector2, to_position: Vector2) -> void:
	if from_position.distance_to(to_position) >= _DRAG_SUPPRESS_CLICK_MIN_DISTANCE:
		_suppress_pending_click_after_drag = true
	_dragged = false
	node_moved.emit(self, to_position)

func _on_position_changed() -> void:
	if _applying_position_from_model:
		return
	_dragged = true

func _force_shrink() -> void:
	size = Vector2(0,0)
