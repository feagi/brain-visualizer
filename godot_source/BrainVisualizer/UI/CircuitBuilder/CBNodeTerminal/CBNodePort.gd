extends TextureRect
class_name CBNodePort

signal node_moved()
signal deletion_requested()

var _root_node: CBNodeConnectableBase

func setup(root_node: CBNodeConnectableBase, signal_terminals_moving: Signal) -> void:
	_root_node = root_node
	signal_terminals_moving.connect(_node_has_moved)
	_node_has_moved()
	
## Get the center point of this object as if it were directly a position offset on the CB GraphEdit
func get_center_port_CB_position() -> Vector2:
	return _get_position_local_to_root_node() + _root_node.position_offset# + (size / 2.0)

## Called by the associated [CBLineInterTerminal] when its [ConnectionChainLink] reports its about to be deleted
func request_deletion() -> void:
	deletion_requested.emit()

func _get_position_local_to_root_node() -> Vector2:
	var a = global_position
	var b = _root_node.global_position
	return global_position - _root_node.global_position

func _node_has_moved() -> void:
	node_moved.emit()
