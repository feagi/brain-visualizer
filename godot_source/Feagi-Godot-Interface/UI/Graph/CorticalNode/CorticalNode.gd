extends GraphNode
class_name CorticalNode
## Represents a Cortical Area in a node graph

const SENSOR_BOX_COLOR: Color = Color.BLUE
const ACTUATOR_BOX_COLOR: Color = Color.YELLOW
const INTERCONNECT_BOX_COLOR: Color = Color.SEA_GREEN
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
## The 2 below may be uneeded
var _input_terminals: Dictionary = {} ## Keyd by connecting area cortical ID
var _output_terminals: Dictionary = {} ## Keyd by connecting area cortical ID

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

## FEAGI deleted cortical area, so this node must go
func FEAGI_delete_cortical_area() -> void:
	queue_free()

func get_center_position_offset() -> Vector2:
	return position_offset + (size / 2.0)

## Get the index position to place the next afferent terminal
func get_next_afferent_index() -> int:
	return _cortical_area_ref.num_afferent_connections

## Get the index position to place the next efferent terminal
## Technically uneeded since the answer will always be the last element
func get_next_efferent_index() -> int:
	print(cortical_area_name)
	print(get_next_afferent_index())
	print(_cortical_area_ref.num_afferent_connections)
	return get_next_afferent_index() + 1

## Spawns an afferent terminal for a cortical area (but does not make the connection line itself)
func spawn_afferent_terminal(afferent: CorticalArea) -> CorticalNodeTerminal:
	var terminal: CorticalNodeTerminal = TERMINAL_PREFAB.instantiate()
	terminal.setup(afferent, self, CorticalNodeTerminal.TYPE.INPUT)
	var index: int = get_next_afferent_index()
	move_child(terminal, index)
	_input_terminals[afferent.cortical_ID] = terminal
	set_slot_enabled_left(index, true)
	_update_terminal_indexes()
	return terminal

## Spawns an efferent terminal for a cortical area (but does not make the connection line itself)
func spawn_efferent_terminal(efferent: CorticalArea) -> CorticalNodeTerminal:
	var terminal: CorticalNodeTerminal = TERMINAL_PREFAB.instantiate()
	terminal.setup(efferent, self,  CorticalNodeTerminal.TYPE.OUTPUT)
	var index: int = get_next_efferent_index()
	move_child(terminal, index)
	_output_terminals[efferent.cortical_ID] = terminal
	set_slot_enabled_right(index, true)
	_update_terminal_indexes()
	return terminal
	

func _update_terminal_indexes() -> void:
	for child in get_children():
		if !(child is CorticalNodeTerminal):
			continue
		(child as CorticalNodeTerminal).update_indexes()

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

