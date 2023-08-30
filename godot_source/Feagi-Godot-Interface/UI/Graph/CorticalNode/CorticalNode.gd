extends Control
class_name CorticalNode
## Represents a Cortical Area in a node graph

enum ConnectionAvailibility {
	BOTH,
	INPUT_ONLY,
	OUTPUT_ONLY,
}

signal user_started_connection_from(cortical_area: CorticalNode)

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
var connection_input: ConnectionButton_Point:
	get: return _connection_input
var connection_output: ConnectionButton_Point:
	get: return _connection_output
var cortical_area_ref: CorticalArea:
	get: return _cortical_area_ref

var _cortical_area_ref: CorticalArea
var _title_bar: TitleBar
var _cortical_name_text: Label_Element
var _connection_input: ConnectionButton_Point
var _connection_output: ConnectionButton_Point



## We can only use this to init connections since we do not have _cortical_area_ref yet
func _ready():
	_title_bar = $TitleBar
	_cortical_name_text = $Cortical_Name
	_connection_input = $Connection_In
	_connection_output = $Connection_Out


	_title_bar.close_pressed.connect(_user_request_delete_cortical_area)
	_title_bar.dragged.connect(_on_title_bar_drag)
	gui_input.connect(_on_interact)

	


## Since we cannot use _init for scenes, use this instead to initialize data
func setup(cortical_area: CorticalArea, node_position: Vector2) -> void:
	_cortical_area_ref = cortical_area
	position = node_position
	_title_bar.title = _cortical_area_ref.name
	_cortical_name_text.text = _cortical_area_ref.cortical_ID

## FEAGI deleted cortical area, so this node must go
func FEAGI_delete_cortical_area() -> void:
	queue_free()


## User hit the X button to attempt to delete the cortical area
## Request FEAGI for deletion of area
func _user_request_delete_cortical_area() -> void:
	print("User requesting cortical area deletion from Circuit Builder")
	FeagiRequests.delete_cortical_area(_cortical_area_ref.cortical_ID)

func _on_title_bar_change_size() -> void:
	pass

func _on_title_bar_drag(_current_position: Vector2, delta_offset: Vector2) -> void:
	_connection_input.moved.emit()
	_connection_output.moved.emit()

func _on_interact(event):
	if !(event is InputEventMouseButton): return
	var mouse_event: InputEventMouseButton = event
	if !mouse_event.double_click: return
	VisConfig.window_manager.spawn_left_panel(_cortical_area_ref)
