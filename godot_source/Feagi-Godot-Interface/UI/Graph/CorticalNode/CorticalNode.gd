extends GraphNode
class_name CorticalNode
## Represents a Cortical Area in a node graph

const SENSOR_BOX_COLOR: Color = Color(0.9882352941176471, 0.7803921568627451, 0.6549019607843137)
const ACTUATOR_BOX_COLOR: Color = Color(0.6352941176470588, 0.8352941176470589, 0.7411764705882353)
const INTERCONNECT_BOX_COLOR: Color = Color(0.7529411764705882, 0.7686274509803922, 1)
const TERMINAL_PREFAB = preload("res://Feagi-Godot-Interface/UI/Graph/Connection/CorticalNodeTerminal.tscn")

signal moved(cortical_node: CorticalNode, new_location: Vector2i)

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


var _cortical_area_ref: CorticalArea

## We can only use this to init connections since we do not have _cortical_area_ref yet
func _ready():
	dragged.connect(_on_finish_drag)
	delete_request.connect(_user_request_delete_cortical_area)

# Announce if cortical area was selected with one click and open left panel on double click
func _gui_input(event):
	if !(event is InputEventMouseButton): return
	var mouse_event: InputEventMouseButton = event
	if !mouse_event.is_pressed(): return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT: return
	FeagiEvents.user_selected_cortical_area.emit(_cortical_area_ref)
	if !mouse_event.double_click: return
	VisConfig.UI_manager.window_manager.spawn_left_panel(_cortical_area_ref)

## Since we cannot use _init for scenes, use this instead to initialize data
func setup(cortical_area: CorticalArea, node_position: Vector2) -> void:
	_cortical_area_ref = cortical_area
	position_offset = node_position
	title = _cortical_area_ref.name
	name = _cortical_area_ref.cortical_ID
	_cortical_area_ref.name_updated.connect(_update_cortical_name)
	_setup_node_color(cortical_area.group)

## FEAGI deleted cortical area, so this node must go
func FEAGI_delete_cortical_area() -> void:
	queue_free()

func get_center_position_offset() -> Vector2:
	return position_offset + (size / 2.0)

## Spawns an afferent terminal for a cortical area (but does not make the connection line itself)
func spawn_afferent_terminal(afferent: CorticalArea) -> CorticalNodeTerminal:
	var terminal: CorticalNodeTerminal = TERMINAL_PREFAB.instantiate()
	terminal.setup(afferent, self, CorticalNodeTerminal.TYPE.INPUT)
	return terminal

## Spawns an efferent terminal for a cortical area (but does not make the connection line itself)
func spawn_efferent_terminal(efferent: CorticalArea) -> CorticalNodeTerminal:
	var terminal: CorticalNodeTerminal = TERMINAL_PREFAB.instantiate()
	terminal.setup(efferent, self,  CorticalNodeTerminal.TYPE.OUTPUT)
	return terminal

## User hit the X button to attempt to delete the cortical area
## Request FEAGI for deletion of area
func _user_request_delete_cortical_area() -> void:
	print("GRAPH: User requesting deletion of cortical area " +  cortical_area_ID)
	FeagiRequests.delete_cortical_area(_cortical_area_ref.cortical_ID)

## Set the color depnding on cortical type
func _setup_node_color(cortical_type: CorticalArea.CORTICAL_AREA_TYPE) -> void:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	match(cortical_type):
		CorticalArea.CORTICAL_AREA_TYPE.IPU:
			style_box.bg_color = SENSOR_BOX_COLOR
		CorticalArea.CORTICAL_AREA_TYPE.CORE:
			style_box.bg_color = INTERCONNECT_BOX_COLOR
		CorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			style_box.bg_color = INTERCONNECT_BOX_COLOR
		CorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			style_box.bg_color = INTERCONNECT_BOX_COLOR
		CorticalArea.CORTICAL_AREA_TYPE.OPU:
			style_box.bg_color = ACTUATOR_BOX_COLOR
		_:
			push_error("Cortical Node loaded unknown or invalid cortical area type!")
			#TODO
			pass

	add_theme_stylebox_override("titlebar", style_box)


func _on_finish_drag(_from_position: Vector2, to_position: Vector2) -> void:
	moved.emit(self, to_position)

func _update_cortical_name(new_name: StringName, _this_cortical_area: CorticalArea) -> void:
	title = new_name

