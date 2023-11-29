extends GraphEdit
class_name CorticalNodeGraph

const NODE_SIZE: Vector2i = Vector2i(175, 86)

## All cortical nodes on CB, key'd by their ID
var cortical_nodes: Dictionary = {}
@export var algorithm_cortical_area_spacing: Vector2i =  Vector2i(10,6)
@export var move_time_delay_before_update_FEAGI: float = 5.0

var _cortical_node_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/CorticalNode/CortexNode.tscn")
var _connection_button_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/Connection/ConnectionButton.tscn")
var _spawn_sorter: CorticalNodeSpawnSorter
var _connection_buttons: Dictionary = {} # key'd by Source_ID {Destination_ID[button]}
var _move_timer: Timer
var _moved_cortical_areas_buffer: Dictionary = {}

func _ready():
	FeagiCacheEvents.cortical_area_added.connect(feagi_spawn_single_cortical_node)
	FeagiCacheEvents.cortical_area_removed.connect(feagi_deleted_single_cortical_node)
	FeagiEvents.genome_is_about_to_reset.connect(_on_genome_reset)
	_spawn_sorter = CorticalNodeSpawnSorter.new(algorithm_cortical_area_spacing, NODE_SIZE)

	_move_timer = $Timer
	_move_timer.wait_time = move_time_delay_before_update_FEAGI
	_move_timer.one_shot = true
	_move_timer.timeout.connect(_move_timer_finished)

	connection_request.connect(_user_request_connection)
	disconnection_request.connect(_user_request_connection_deletion)


## Spawns a cortical Node, should only be called via FEAGI
func feagi_spawn_single_cortical_node(cortical_area: CorticalArea) -> CorticalNode:
	var cortical_node: CorticalNode = _cortical_node_prefab.instantiate()
	var offset: Vector2
	if cortical_area.is_coordinates_2D_available:
		offset = cortical_area.coordinates_2D
	else:
		if VisConfig.visualizer_state == VisConfig.STATES.LOADING_INITIAL:
			offset = _spawn_sorter.add_cortical_area_to_memory_and_return_position(cortical_area.group)
		else:
			offset = Vector2(0.0,0.0) # TODO use center of view instead
	add_child(cortical_node)
	cortical_node.setup(cortical_area, offset)
	cortical_node.moved.connect(_cortical_node_moved)
	cortical_nodes[cortical_area.cortical_ID] = cortical_node
	
	cortical_area.efferent_mapping_edited.connect(feagi_create_connection_button_from_efferent)
	
	return cortical_node

## Deletes a cortical Node, should only be called via FEAGI
func feagi_deleted_single_cortical_node(cortical_area: CorticalArea) -> void:
	if cortical_area.cortical_ID not in cortical_nodes.keys():
		push_error("GRAPH: Attempted to remove non-existant cortex node " + cortical_area.cortical_ID + "! Skipping...")
	var node: CorticalNode = cortical_nodes[cortical_area.cortical_ID]
	node.FEAGI_delete_cortical_area()
	cortical_nodes.erase(cortical_area.cortical_ID)

## Spawns a conneciton button, which itself coordinates maintaining connection lines 
func feagi_create_connection_button_from_efferent(mapping_properties: MappingProperties) -> void:

	if mapping_properties.source_cortical_area.cortical_ID not in _connection_buttons.keys():
		_connection_buttons[mapping_properties.source_cortical_area.cortical_ID] = {}
	if mapping_properties.destination_cortical_area.cortical_ID in _connection_buttons[mapping_properties.source_cortical_area.cortical_ID].keys():
		# Button Exists. Do nothing
		return
	
	if mapping_properties.source_cortical_area.cortical_ID not in cortical_nodes.keys():
		push_error("UI: GRAPH: Unable to create a connection due to missing cortical area %s! Skipping!" % mapping_properties.source_cortical_area.cortical_ID)
		return
	if mapping_properties.destination_cortical_area.cortical_ID not in cortical_nodes.keys():
		push_error("GRAPH: Unable to create a connection due to missing cortical area %s! Skipping!" % mapping_properties.destination_cortical_area.cortical_ID)
		return

	var source_node: CorticalNode = cortical_nodes[mapping_properties.source_cortical_area.cortical_ID]
	var destination_node: CorticalNode = cortical_nodes[mapping_properties.destination_cortical_area.cortical_ID]
	
	# Spawn Button and setup
	_connection_buttons[mapping_properties.source_cortical_area.cortical_ID][mapping_properties.destination_cortical_area.cortical_ID] = _connection_button_prefab.instantiate()
	_connection_buttons[mapping_properties.source_cortical_area.cortical_ID][mapping_properties.destination_cortical_area.cortical_ID].setup(source_node, destination_node, mapping_properties, self)


## Every time a cortical node moves, store and send it when time is ready
func _cortical_node_moved(node: CorticalNode, new_position: Vector2i) -> void:
	print("Buffering change in position of cortical area " + node.cortical_area_ID)
	if _moved_cortical_areas_buffer == {}:
		print("Starting 2D move timer for %d seconds" % move_time_delay_before_update_FEAGI)
		_move_timer.start()
	_moved_cortical_areas_buffer[node.cortical_area_ID] = new_position

## When the move timer goes off, send all the buffered cortical areas with their new positions to feagi
func _move_timer_finished():
	print("Sending change of 2D positions for %d cortical area(s)" % len(_moved_cortical_areas_buffer.keys()))
	FeagiRequests.request_mass_change_2D_positions(_moved_cortical_areas_buffer)
	_moved_cortical_areas_buffer = {}


## User requested a connection. Note that this function is going to be redone in the graph edit refactor
func _user_request_connection(from_cortical_ID: StringName, _from_port: int, to_cortical_ID: StringName, _to_port: int) -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(FeagiCache.cortical_areas_cache.cortical_areas[from_cortical_ID], FeagiCache.cortical_areas_cache.cortical_areas[to_cortical_ID])

func _user_request_connection_deletion(from_cortical_ID: StringName, _from_port: int, to_cortical_ID: StringName, _to_port: int) -> void:
	FeagiRequests.request_delete_mapping_between_corticals(FeagiCache.cortical_areas_cache.cortical_areas[from_cortical_ID], FeagiCache.cortical_areas_cache.cortical_areas[to_cortical_ID])

func _on_genome_reset():
	_spawn_sorter = CorticalNodeSpawnSorter.new(algorithm_cortical_area_spacing, NODE_SIZE)
	_moved_cortical_areas_buffer = {}
	_move_timer.stop()


