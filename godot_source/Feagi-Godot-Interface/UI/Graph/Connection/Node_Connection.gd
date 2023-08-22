extends Line2D
class_name Node_Connection

enum State {
	INITIAL_DRAG,
	CONFIRMING,
	CONFIRMED,
}

var source_node_point: ConnectionButton_Point:
	get: return _source_node_point
var destination_node_point: ConnectionButton_Point:
	get: return _destination_node_point


var _source_node_point: ConnectionButton_Point
var _destination_node_point: ConnectionButton_Point
var _button: Connection_Button

func _init():
	points = PackedVector2Array([Vector2(0,0), Vector2(0,0)])


## For when the connection loads already formed
func spawn_connected(source_point: ConnectionButton_Point, destination_point: ConnectionButton_Point, mapping_count: int, background: CorticalNodeGraph) -> void:
	background.add_child(self)
	_source_node_point = source_point
	_destination_node_point = destination_point
	_button = $Button
	update_source_point_position()
	update_destination_point_position()
	_button.text = str(mapping_count)

func update_source_point_position() -> void:
	points = PackedVector2Array([_source_node_point.position, points[1]])

func update_destination_point_position() -> void:
	points = PackedVector2Array([points[0], _destination_node_point.position])

