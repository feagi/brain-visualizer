extends Line2D #TODO look later to do Path2D
class_name Connection2DBase
## Base class for all Cortical Node Connections, mainly handles visuals and contains common functions for tracking cortical nodes

signal mid_point_changed_position(midpoint: Vector2)

var start_point: Vector2:
	get: return points[0]
	set(v):
		points[0] = v
		mid_point_changed_position.emit(mid_point)

var end_point: Vector2:
	get: return points[1]
	set(v):
		points[1] = v
		mid_point_changed_position.emit(mid_point)

var mid_point: Vector2:
	get: return (points[0] + points[1]) / 2.0

var _source_node: CorticalNode
var _destination_node: CorticalNode

func _init() -> void:
	points = PackedVector2Array([Vector2(0,0), Vector2(0,0)])

func set_line_source_node(source_node: CorticalNode) -> void:
	_source_node = source_node
	start_point = source_node.connection_output.graph_position
	source_node.connection_output.moved.connect(_source_node_moved)

func set_line_destination_node(destination_node: CorticalNode) -> void:
	_destination_node = destination_node
	end_point = destination_node.connection_input.graph_position
	destination_node.connection_input.moved.connect(_destination_node_moved)

func _source_node_moved(new_position: Vector2) -> void:
	start_point = new_position

func _destination_node_moved(new_position: Vector2) -> void:
	end_point = new_position


