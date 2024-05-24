extends CBLine
class_name CBLineInterTerminal
## Connects 2 terminals together in CB

var _source_port: CBNodePort
var _destination_port: CBNodePort
var _link: ConnectionChainLink

## Sets up the default line behavior, by having it connect to the ports of the 2 given terminals
func setup(source_port: CBNodePort, destination_port: CBNodePort, link: ConnectionChainLink) -> void:
	line_setup()
	_source_port = source_port
	_destination_port = destination_port
	_link = link
	_update_line_endpoint_positions()
	_source_port.node_moved.connect(_update_line_endpoint_positions)
	_destination_port.node_moved.connect(_update_line_endpoint_positions)


func _update_line_endpoint_positions() -> void:
	set_line_endpoints(_source_port.get_center_port_position(), _destination_port.get_center_port_position())

func _on_link_about_to_be_deleted() -> void:
	_source_port.request_deletion()
	_destination_port.request_deletion()
