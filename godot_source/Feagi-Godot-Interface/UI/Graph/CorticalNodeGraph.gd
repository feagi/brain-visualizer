extends GraphEdit
class_name CorticalNodeGraph

const NODE_SIZE: Vector2i = Vector2i(175, 86)

## All cortical nodes on CB, key'd by their ID
var cortical_nodes: Dictionary = {}
@export var algorithm_cortical_area_spacing: Vector2i =  Vector2i(10,6)

var _cortical_node_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/CorticalNode/CortexNode.tscn")
var _connection_button_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/Connection/ConnectionButton.tscn")
var _spawn_sorter: CorticalNodeSpawnSorter
var _connection_buttons: Dictionary = {}

func _ready():
	FeagiCacheEvents.cortical_area_added.connect(feagi_spawn_single_cortical_node)
	FeagiCacheEvents.cortical_area_removed.connect(feagi_deleted_single_cortical_node)
	FeagiCacheEvents.cortical_areas_connection_modified.connect(feagi_spawn_established_connection)
	FeagiCacheEvents.cortical_areas_disconnected.connect(feagi_delete_established_connection)
	FeagiEvents.genome_is_about_to_reset.connect(_on_genome_reset)
	_spawn_sorter = CorticalNodeSpawnSorter.new(algorithm_cortical_area_spacing, NODE_SIZE)

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
	cortical_nodes[cortical_area.cortical_ID] = cortical_node
	
	#cortical_node.user_started_connection_from.connect(user_start_drag_new_connection)
	return cortical_node


func feagi_deleted_single_cortical_node(cortical_area: CorticalArea) -> void:
	if cortical_area.cortical_ID not in cortical_nodes.keys():
		push_error("GRAPH: Attempted to remove non-existant cortex node " + cortical_area.cortical_ID + "! Skipping...")
	var node: CorticalNode = cortical_nodes[cortical_area.cortical_ID]
	node.FEAGI_delete_cortical_area()
	cortical_nodes.erase(cortical_area.cortical_ID)


## Should only be called from feagi when connection creation is confirmed
func feagi_spawn_established_connection(source: CorticalArea, destination: CorticalArea, mapping_count: int) -> void:
	pass
	if source.cortical_ID not in cortical_nodes.keys():
		push_error("GRAPH: Unable to create a connection due to missing cortical area %s! Skipping!" % source.cortical_ID)
		return
	if destination.cortical_ID not in cortical_nodes.keys():
		push_error("GRAPH: Unable to create a connection due to missing cortical area %s! Skipping!" % destination.cortical_ID)
		return

	connect_node(source.cortical_ID, 0, destination.cortical_ID, 0)
	
	# Check from outputs
	if source.cortical_ID not in _connection_buttons.keys():
		var new_button: ConnectionButton = _connection_button_prefab.instantiate()
		_connection_buttons[source.cortical_ID] = {destination.cortical_ID: new_button}
		add_child(new_button)
		new_button.setup(cortical_nodes[source.cortical_ID], cortical_nodes[destination.cortical_ID], mapping_count)
		return
	
	# check from inputs
	if destination.cortical_ID not in _connection_buttons[source.cortical_ID].keys():
		var new_button: ConnectionButton = _connection_button_prefab.instantiate()
		_connection_buttons[source.cortical_ID][destination.cortical_ID] = new_button
		add_child(new_button)
		new_button.setup(cortical_nodes[source.cortical_ID], cortical_nodes[destination.cortical_ID], mapping_count)
		return
	
	# button exists, update
	_connection_buttons[source.cortical_ID][destination.cortical_ID].update_mapping_counter(mapping_count)


## Should only be called from feagi when connection deletion is confirmed
func feagi_delete_established_connection(source: CorticalArea, destination: CorticalArea) -> void:
	if source.cortical_ID not in cortical_nodes.keys():
		push_error("GRAPH: Unable to delete a connection from source cortical area %s since it was not found in the cache! Skipping!" % source.cortical_ID)
		return
	
	if source.cortical_ID in _connection_buttons.keys():
		if destination.cortical_ID in _connection_buttons[source.cortical_ID].keys():
			_connection_buttons[source.cortical_ID][destination.cortical_ID].destroy_self()
			_connection_buttons[source.cortical_ID].erase(destination.cortical_ID)
			if len(_connection_buttons[source.cortical_ID].keys()) == 0:
				_connection_buttons.erase(source.cortical_ID)
	
	disconnect_node(source.cortical_ID, 0, destination.cortical_ID, 0)

## User requested a connection. Note that this function is going to be redone in the graph edit refactor
func _user_request_connection(from_cortical_ID: StringName, _from_port: int, to_cortical_ID: StringName, _to_port: int) -> void:
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(FeagiCache.cortical_areas_cache.cortical_areas[from_cortical_ID], FeagiCache.cortical_areas_cache.cortical_areas[to_cortical_ID])

func _user_request_connection_deletion(from_cortical_ID: StringName, _from_port: int, to_cortical_ID: StringName, _to_port: int) -> void:
	FeagiRequests.request_delete_mapping_between_corticals(FeagiCache.cortical_areas_cache.cortical_areas[from_cortical_ID], FeagiCache.cortical_areas_cache.cortical_areas[to_cortical_ID])

func _on_genome_reset():
	_spawn_sorter = CorticalNodeSpawnSorter.new(algorithm_cortical_area_spacing, NODE_SIZE)

