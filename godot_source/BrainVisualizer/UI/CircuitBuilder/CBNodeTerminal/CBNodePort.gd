extends TextureRect
class_name CBNodePort

signal node_moved()
signal deletion_requested()

## The position this port is relative to the root [CBNodeConnectableBase]
var CB_node_offset: Vector2:
	get: return _CB_node_offset
	
var _CB_node_offset: Vector2

## Called by parent [CBNodeTerminal] when the node does something which modes the terminals around
func terminal_offset_changed(terminal_positional_offset_from_node_root: Vector2) -> void:
	_CB_node_offset = position + terminal_positional_offset_from_node_root

## Called by parent [CBNodeTerminal] when something moves this object relative to CB, such as terminals being added / removed, or the node itself being dragged around
func node_has_moved() -> void:
	node_moved.emit()

func get_center_port_position() -> Vector2:
	return _CB_node_offset + position + (size / 2.0)

## Called by the associated [CBLineInterTerminal] when its [ConnectionChainLink] reports its about to be deleted
func request_deletion() -> void:
	deletion_requested.emit()
