extends TextureRect
class_name CBLineEndpoint
## Sucessor to [CBNodePort], is a generic endpoint for [CBLine] to connect to

enum PORT_STYLE {
	FULL,
	RING
}

const port_style_paths: Dictionary = {
		PORT_STYLE.FULL: "res://BrainVisualizer/UI/CircuitBuilder/Resources/Ports/cb-port-full.png",
		PORT_STYLE.RING: "res://BrainVisualizer/UI/CircuitBuilder/Resources/Ports/cb-port-ring.png"
}

signal node_moved()
signal deletion_requested(self_ref: CBLineEndpoint)

var _cached_offset: Vector2 = Vector2(0,0)
var _node_parent: CBAbstractNode

func setup(root_node: CBAbstractNode, parent_node_moving: Signal, port_style: PORT_STYLE) -> void:
	_node_parent = root_node
	parent_node_moving.connect(update_offset)
	texture = load(port_style_paths[port_style])

func get_endpoint_position_offset() -> Vector2:
	return _cached_offset + _node_parent.position_offset

func get_center_port_CB_position(): # TEMP TODO
	return get_endpoint_position_offset()

func update_offset() -> void:
	var offset: Vector2 = Vector2(size) / 2.0
	var control: Control = self
	while !(control == _node_parent):
		offset += control.position
		control = control.get_parent()
		if control == null:
			push_error("CB Line Endpoint: Unable to correctly calculate endpoint position!")
			return
	_cached_offset = offset
	node_moved.emit()

func request_deletion() -> void:
	deletion_requested.emit(self)
