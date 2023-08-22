extends BaseConnection
class_name EstablishConnection

signal point_moved(start_position: Vector2, end_position: Vector2)

var _start_connector: ConnectionButton_Point
var _end_connector: ConnectionButton_Point
var _button: Connection_Button



func _init(start_point: ConnectionButton_Point, end_point: ConnectionButton_Point, num_mappings: int):
	super._init()
	_button = Connection_Button.new()
	add_child(_button)
	_start_connector = start_point
	_end_connector = end_point
	points = PackedVector2Array([_start_connector.graph_position, _end_connector.graph_position])
	_button.text = str(num_mappings)
	_start_connector.moved.connect(start_connection_point_moved)
	_end_connector.moved.connect(end_connection_point_moved)
	_button.update_position(points)

func start_connection_point_moved():
	_move_start_point(_start_connector.graph_position)
	_button.update_position(points)

func end_connection_point_moved():
	_move_exit_point(_end_connector.graph_position)
	_button.update_position(points)

