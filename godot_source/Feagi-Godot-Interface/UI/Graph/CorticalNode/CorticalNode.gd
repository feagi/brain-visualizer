extends GraphNode
class_name CorticalNode
## Represents a Cortical Area in a node graph

enum ConnectionAvailibility {
	BOTH,
	INPUT_ONLY,
	OUTPUT_ONLY,
}

var cortical_area_name: StringName:
	get:
		if(_cortical_area_ref):
			return _cortical_area_ref.name
		return "ERROR NOT SETUP"

var cortical_area_ID: StringName:
	get: 
		if(_cortical_area_ref):
			return _cortical_area_ref.cortical_ID
		return "ERROR NOT SETUP"
var cortical_area_ref: CorticalArea:
	get: return _cortical_area_ref

var cortical_connection_destinations: Dictionary = {}

var _cortical_area_ref: CorticalArea


## We can only use this to init connections since we do not have _cortical_area_ref yet
func _ready():
	dragged.connect(_on_finish_drag)
	close_request.connect(_user_request_delete_cortical_area)
	
## Since we cannot use _init for scenes, use this instead to initialize data
func setup(cortical_area: CorticalArea, node_position: Vector2) -> void:
	_cortical_area_ref = cortical_area
	position = node_position

## FEAGI deleted cortical area, so this node must go
func FEAGI_delete_cortical_area() -> void:
	queue_free()

## User hit the X button to attempt to delete the cortical area
## Request FEAGI for deletion of area
func _user_request_delete_cortical_area() -> void:
	print("CIRCUIT BUILDER: User requesting deletion of cortical area " +  cortical_area_ID)
	FeagiRequests.delete_cortical_area(_cortical_area_ref.cortical_ID)

func _gui_input(event):
	if !(event is InputEventMouseButton): return
	var mouse_event: InputEventMouseButton = event
	if !mouse_event.double_click: return
	VisConfig.UI_manager.window_manager.spawn_left_panel(_cortical_area_ref)

func _on_finish_drag(_from_position: Vector2, to_position: Vector2) -> void:
	var arr_position: Array = FEAGIUtils.vector2i_to_array(to_position)
	FeagiRequests.set_cortical_area_properties( _cortical_area_ref.cortical_ID, {"cortical_coordinates_2d": arr_position})
