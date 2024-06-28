extends GraphElement
class_name CBAbstractNode
## Sucessor to [CBNodeConnectableBase]. Base Abstract class for all graph elements that interact with [CBLine] connections

signal node_moved()

var is_currently_being_dragged: bool:
	get: return _is_currently_being_dragged

var _is_currently_being_dragged: bool = false
var _input_endpoints: Array[CBLineEndpoint] = []
var _output_endpoints: Array[CBLineEndpoint] = []

func setup_base() -> void:
	dragged.connect(_on_finish_drag)
	#draw.connect(_on_node_move)
	position_offset_changed.connect(_on_position_changed)
	_is_currently_being_dragged = false

## Creates and adds an input CBLineEndpoint. WARNING: NEEDS TO BE EXTENDED
func add_input_endpoint(endpoint_prefab: PackedScene, port_style: CBLineEndpoint.PORT_STYLE) -> CBLineEndpoint:
	var endpoint: CBLineEndpoint = endpoint_prefab.instantiate()
	_input_endpoints.append(endpoint)
	endpoint.setup(self, node_moved, port_style)
	endpoint.deletion_requested.connect(_remove_input_endpoint)
	return endpoint

func update_input_offsets() -> void:
	for endpoint in _input_endpoints:
		endpoint.update_offset()

## Creates and adds an output CBLineEndpoint. WARNING: NEEDS TO BE EXTENDED
func add_output_endpoint(endpoint_prefab: PackedScene, port_style: CBLineEndpoint.PORT_STYLE) -> CBLineEndpoint:
	var endpoint: CBLineEndpoint = endpoint_prefab.instantiate()
	_output_endpoints.append(endpoint)
	endpoint.setup(self, node_moved, port_style)
	endpoint.deletion_requested.connect(_remove_output_endpoint)
	return endpoint

func update_output_offsets() -> void:
	for endpoint in _output_endpoints:
		endpoint.update_offset()

## Gets called from the endpoint itself when the connected line commands it to be deleted
func _remove_input_endpoint(endpoint: CBLineEndpoint) -> void:
	var index: int = _input_endpoints.find(endpoint)
	if index != -1:
		_input_endpoints.remove_at(index)
	else:
		push_error("UI: Unable to find input line endpoint to remove!")
	endpoint.queue_free()

## Gets called from the endpoint itself when the connected line commands it to be deleted
func _remove_output_endpoint(endpoint: CBLineEndpoint) -> void:
	var index: int = _output_endpoints.find(endpoint)
	if index != -1:
		_output_endpoints.remove_at(index)
	else:
		push_error("UI: Unable to find output line endpoint to remove!")
	endpoint.queue_free()

func _on_finish_drag(_from_position: Vector2, to_position: Vector2) -> void:
	_is_currently_being_dragged = false
	node_moved.emit()

func _on_position_changed() -> void:
	_is_currently_being_dragged = true

