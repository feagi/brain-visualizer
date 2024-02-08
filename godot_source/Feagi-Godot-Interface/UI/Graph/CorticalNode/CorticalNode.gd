extends GraphNode
class_name CorticalNode
## Represents a Cortical Area in a node graph
const IPU_BOX_COLOR: Color = Color(0.25882352941176473, 0.25882352941176473, 0.25882352941176473)
const CUSTOM_BOX_COLOR: Color = Color(0, 0.32941176470588235, 0.5764705882352941)
const MEMORY_BOX_COLOR: Color = Color(0.5803921568627451, 0.06666666666666667, 0)
const OPU_BOX_COLOR: Color = Color(0.5803921568627451, 0.3215686274509804, 0)


const INTERCORTICAL_CONNECTION_PREFAB: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/CorticalNode/Connection/InterCorticalConnection.tscn")
const INTERCORTICAL_TERMINAL_PREFAB: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/CorticalNode/Connection/InterCorticalNodeTerminal.tscn")
const RECURSIVE_TERMINAL_PREFAB: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/CorticalNode/Connection/RecursiveNodeTerminal.tscn")

signal moved(cortical_node: CorticalNode, new_location: Vector2i)

enum ConnectionAvailibility {
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
var cortical_area_ref: BaseCorticalArea:
	get: return _cortical_area_ref

var _cortical_area_ref: BaseCorticalArea
var _graph: CorticalNodeGraph

## We can only use this to init connections since we do not have _cortical_area_ref yet
func _ready():
	dragged.connect(_on_finish_drag)
	delete_request.connect(_user_request_delete_cortical_area)
	_graph = get_parent()
	child_order_changed.connect(_shrink)

# Announce if cortical area was selected with one click and open cortical properties panel on double click
func _gui_input(event):
	if !(event is InputEventMouseButton): return
	var mouse_event: InputEventMouseButton = event
	if !mouse_event.is_pressed(): return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT: return
	FeagiEvents.user_selected_cortical_area.emit(_cortical_area_ref)
	#if !mouse_event.double_click: return
	VisConfig.UI_manager.window_manager.spawn_quick_cortical_menu(_cortical_area_ref)

## Since we cannot use _init for scenes, use this instead to initialize data
func setup(cortical_area: BaseCorticalArea, node_position: Vector2) -> void:
	_cortical_area_ref = cortical_area
	position_offset = node_position
	title = _cortical_area_ref.name
	name = _cortical_area_ref.cortical_ID
	_cortical_area_ref.name_updated.connect(_update_cortical_name)
	_cortical_area_ref.efferent_mapping_added.connect(FEAGI_create_mapping_from_efferent)
	_setup_node_color(cortical_area.group)

## FEAGI deleted cortical area, so this node must go
func FEAGI_delete_cortical_area() -> void:
	queue_free()

func FEAGI_create_mapping_from_efferent(mapping_properties: MappingProperties) -> void:
		if mapping_properties.is_recursive():
		# recurssive connection
			_spawn_recursive_terminal(mapping_properties)
			return
		_spawn_new_internode_mapping(mapping_properties)

func spawn_afferent_terminal(mapping_properties: MappingProperties) -> InterCorticalNodeTerminal:
	var terminal: InterCorticalNodeTerminal = INTERCORTICAL_TERMINAL_PREFAB.instantiate()
	add_child(terminal)
	move_child(terminal, _get_starting_afferent_index())
	terminal.setup(mapping_properties, InterCorticalNodeTerminal.TYPE.INPUT, position_offset_changed)
	return terminal

func get_center_position_offset() -> Vector2:
	return position_offset + (size / 2.0)

func _is_cortical_node_mapped(cortical_area: BaseCorticalArea) -> bool:
	for child: Node in get_children():
		if child.name == cortical_area.cortical_ID:
			return true
	return false

func _spawn_new_internode_mapping(mapping_properties: MappingProperties) -> void:
	# InterNode Connection
	if mapping_properties.destination_cortical_area.cortical_ID not in _graph.cortical_nodes.keys():
		push_error("UI: GRAPH: Unable to locate destination cortical node %s! Skipping mapping from %s!" % [mapping_properties.destination_cortical_area.cortical_ID, mapping_properties.source_cortical_area.cortical_ID])
		return

	# spawn terminals
	var afferent_node: CorticalNode = _graph.cortical_nodes[mapping_properties.destination_cortical_area.cortical_ID]
	var afferent_terminal: InterCorticalNodeTerminal = afferent_node.spawn_afferent_terminal(mapping_properties)
	var efferent_terminal: InterCorticalNodeTerminal = _spawn_efferent_terminal(mapping_properties) 
	
	# spawn line and mapping button
	var connection: InterCorticalConnection = INTERCORTICAL_CONNECTION_PREFAB.instantiate()
	_graph.add_child(connection)
	connection.setup(efferent_terminal, afferent_terminal, mapping_properties)

func _get_starting_afferent_index() -> int:
	if get_child(0).name == cortical_area_ID:
		# Since terminal names are always the mapped target ID, we can do this
		## The first element (after the add connection section) is always the self mapped terminal (if it exists)
		return 2
	return 1

func _get_starting_efferent_index() -> int:
	return cortical_area_ref.num_afferent_connections + _get_starting_afferent_index()

## Spawns an efferent terminal for a cortical area (but does not make the connection line itself)
func _spawn_efferent_terminal(mapping_properties: MappingProperties) -> InterCorticalNodeTerminal:
	var terminal: InterCorticalNodeTerminal = INTERCORTICAL_TERMINAL_PREFAB.instantiate()
	add_child(terminal)
	move_child(terminal, _get_starting_afferent_index())
	terminal.setup(mapping_properties, InterCorticalNodeTerminal.TYPE.OUTPUT, position_offset_changed)
	return terminal

func _delete_connection() -> void:
	pass

## Spawns a recursive terminal for this cortical node
func _spawn_recursive_terminal(mapping: MappingProperties) -> RecursiveNodeTerminal:
	var terminal: RecursiveNodeTerminal = RECURSIVE_TERMINAL_PREFAB.instantiate()
	add_child(terminal)
	move_child(terminal, 1)
	terminal.setup(mapping)
	return terminal

## User hit the X button to attempt to delete the cortical area
## Request FEAGI for deletion of area
func _user_request_delete_cortical_area() -> void:
	print("GRAPH: User requesting deletion of cortical area " +  cortical_area_ID)
	FeagiRequests.delete_cortical_area(_cortical_area_ref.cortical_ID)

## Set the color depnding on cortical type
func _setup_node_color(cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> void:
	var style_box: StyleBoxFlat = StyleBoxFlat.new()
	match(cortical_type):
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			style_box.bg_color = IPU_BOX_COLOR
		BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			style_box.bg_color = MEMORY_BOX_COLOR
		BaseCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			style_box.bg_color = CUSTOM_BOX_COLOR
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			style_box.bg_color = OPU_BOX_COLOR
		BaseCorticalArea.CORTICAL_AREA_TYPE.CORE:
			pass #TODO Define an actual color here at some point!
		_:
			push_error("Cortical Node loaded unknown or invalid cortical area type!")
			#TODO
			pass

	add_theme_stylebox_override("titlebar", style_box)

func _on_finish_drag(_from_position: Vector2, to_position: Vector2) -> void:
	moved.emit(self, to_position)
			
func _update_cortical_name(new_name: StringName, _this_cortical_area: BaseCorticalArea) -> void:
	title = new_name

func _shrink() -> void:
	size = Vector2(0,0)
