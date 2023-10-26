extends GraphNode
class_name CorticalNode
## Represents a Cortical Area in a node graph

signal moved(cortical_node: CorticalNode, new_location: Vector2i)

enum ConnectionAvailibility {
	BOTH,
	INPUT_ONLY,
	OUTPUT_ONLY,
}

#@export var 

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

var _cortical_area_ref: CorticalArea


## We can only use this to init connections since we do not have _cortical_area_ref yet
func _ready():
	dragged.connect(_on_finish_drag)
	close_request.connect(_user_request_delete_cortical_area)
	
## Since we cannot use _init for scenes, use this instead to initialize data
func setup(cortical_area: CorticalArea, node_position: Vector2) -> void:
	_cortical_area_ref = cortical_area
	position_offset = node_position
	title = _cortical_area_ref.name
	name = _cortical_area_ref.cortical_ID
	_cortical_area_ref.name_updated.connect(_update_cortical_name)
	
## FEAGI deleted cortical area, so this node must go
func FEAGI_delete_cortical_area() -> void:
	queue_free()

func get_center_position_offset() -> Vector2:
	return position_offset + (size / 2.0)

## User hit the X button to attempt to delete the cortical area
## Request FEAGI for deletion of area
func _user_request_delete_cortical_area() -> void:
	print("GRAPH: User requesting deletion of cortical area " +  cortical_area_ID)
	FeagiRequests.delete_cortical_area(_cortical_area_ref.cortical_ID)

## Set the color depnding on cortical type
func _setup_color(cortical_type: CorticalArea.CORTICAL_AREA_TYPE) -> void:
	match(cortical_type):
		CorticalArea.CORTICAL_AREA_TYPE.IPU:
			#TODO
			pass
		CorticalArea.CORTICAL_AREA_TYPE.CORE:
			#TODO
			pass
		CorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			#TODO
			pass
		CorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			#TODO
			pass
		CorticalArea.CORTICAL_AREA_TYPE.OPU:
			#TODO
			pass
		_:
			push_error("Cortical Node loaded unknown or invalid cortical area type!")
			#TODO
			pass
		

# Announce if cortical area was selected with one click and open left panel on double click
func _gui_input(event):
	if !(event is InputEventMouseButton): return
	var mouse_event: InputEventMouseButton = event
	if !mouse_event.is_pressed(): return
	if !mouse_event.button_index != 0: return
	FeagiEvents.user_selected_cortical_area.emit(_cortical_area_ref)
	if !mouse_event.double_click: return
	VisConfig.UI_manager.window_manager.spawn_left_panel(_cortical_area_ref)

func _on_finish_drag(_from_position: Vector2, to_position: Vector2) -> void:
	moved.emit(self, to_position)

func _update_cortical_name(new_name: StringName, _this_cortical_area: CorticalArea) -> void:
	title = new_name
