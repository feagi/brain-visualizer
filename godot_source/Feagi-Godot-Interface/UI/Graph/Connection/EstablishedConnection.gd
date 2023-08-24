extends BaseConnection
class_name EstablishConnection

signal point_moved(start_position: Vector2, end_position: Vector2)

var _start_connector: ConnectionButton_Point
var _end_connector: ConnectionButton_Point
var _source_cortical_area_ID: StringName
var _destination_cortical_area_ID: StringName
var _button: Connection_Button



func _init(start_node: CorticalNode, end_node: CorticalNode, num_mappings: int):
    super._init()
    _button = Connection_Button.new()
    add_child(_button)
    _start_connector = start_node.connection_output
    _end_connector = end_node.connection_input
    _source_cortical_area_ID = start_node.cortical_area_ID
    _destination_cortical_area_ID = end_node.cortical_area_ID
    points = PackedVector2Array([_start_connector.graph_position, _end_connector.graph_position])
    _button.text = str(num_mappings)
    _start_connector.moved.connect(_start_connection_point_moved)
    _end_connector.moved.connect(_end_connection_point_moved)
    _button.update_position(points)
    FeagiCacheEvents.cortical_areas_disconnected.connect(_check_if_connection_is_deleted)
    FeagiCacheEvents.cortical_areas_connection_modified.connect(_check_if_connection_is_modified)


func _start_connection_point_moved():
    _move_start_point(_start_connector.graph_position)
    _button.update_position(points)

func _end_connection_point_moved():
    _move_exit_point(_end_connector.graph_position)
    _button.update_position(points)

func _check_if_connection_is_deleted(source_cortical_area: StringName, destination_cortical_area: StringName):
    if source_cortical_area == _source_cortical_area_ID and destination_cortical_area == _destination_cortical_area_ID:
        queue_free()

func _check_if_connection_is_modified(source_cortical_area: StringName, destination_cortical_area: StringName, number_of_mappings: int):
    if source_cortical_area == _source_cortical_area_ID and destination_cortical_area == _destination_cortical_area_ID:
        _button.text = str(number_of_mappings)
