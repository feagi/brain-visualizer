extends BaseConnection
class_name DraggingToDestinationConnection


var mouse_normal_click_button: MouseButton = MOUSE_BUTTON_LEFT

var _start_connector: ConnectionButton_Point
var _source_cortical_area_ID: StringName
var _cortical_node_graph: CorticalNodeGraph
var _center: NodeGraphCenter

func _init(start_node: CorticalNode, cortical_graph: CorticalNodeGraph):
    super._init()
    _start_connector = start_node.connection_output
    _source_cortical_area_ID = start_node.cortical_area_ID
    _cortical_node_graph = cortical_graph
    _center = _cortical_node_graph._background_center
    _center.add_child(self)
    default_color = Color(1,1,0.7,0.7)
    _move_start_point(_start_connector.graph_position)
    _move_exit_point(_start_connector.graph_position)


func _input(event):
    if event is InputEventMouseButton:
		# user clicked mouse (or clicked / scrolled mouse wheel)
        _handle_click(event)
    if event is InputEventMouseMotion:
        _handle_mouse_move(event)


func _handle_click(event: InputEventMouseButton) -> void:
    if event.button_index != mouse_normal_click_button:
        return
    
    if event.pressed == true:
        return
    
    # user let go somewhere, confirm this is a connection, if not delete, if so spawn window
    queue_free()

func _handle_mouse_move(event: InputEventMouseMotion) -> void:
    var pos: Vector2 = event.position
    pos = pos - _center.position
    _move_exit_point(pos)
