extends TextureRect
class_name CBNodePort

signal node_moved()
signal deletion_requested()

var root_node: CBNodeConnectableBase:
	get: return _root_node

var _root_node: CBNodeConnectableBase
var _use_graph_slot: bool = false

func setup(root_node_: CBNodeConnectableBase, signal_terminals_moving: Signal) -> void:
	_root_node = root_node_
	signal_terminals_moving.connect(_node_has_moved)
	_node_has_moved()


## The row's slot draws the port. This control stays so the wire can keep its endpoint object.
func use_graph_slot() -> void:
	_use_graph_slot = true
	visible = false
	
## Get the center point of this object as if it were directly a position offset on the CB GraphEdit
func get_center_port_CB_position() -> Vector2:
	if _use_graph_slot:
		var terminal := get_parent() as CBNodeTerminal
		if terminal == null or _root_node == null or terminal.graph_port_index < 0:
			return _root_node.position_offset if _root_node != null else Vector2.ZERO
		return GraphNodeStyle.graph_port_position(_root_node, terminal.graph_port_is_input, terminal.graph_port_index)
	return _get_position_local_to_root_node() + _root_node.position_offset + (size / 2.0)

## Called by the associated [CBLineInterTerminal] when its [ConnectionChainLink] reports its about to be deleted
func request_deletion() -> void:
	deletion_requested.emit()

func _get_position_local_to_root_node() -> Vector2:
	var offset: Vector2 = Vector2(0,0)
	var control: Control = self
	while !(control is CBNodeConnectableBase):
		if !control:
			push_error("Port errored!")
			return offset # stupid
		offset += control.position
		control = control.get_parent()
	return offset


func _node_has_moved() -> void:
	node_moved.emit()
