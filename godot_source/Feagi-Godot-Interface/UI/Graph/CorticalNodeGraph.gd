extends NodeGraph
class_name CorticalNodeGraph

const NODE_SIZE: Vector2i = Vector2i(175, 86)

## All cortical nodes on CB, key'd by their ID
var cortical_nodes: Dictionary = {}
@export var algorithm_cortical_area_spacing: Vector2i =  Vector2i(10,6)

var _cortical_node_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/CorticalNode/CortexNode.tscn")
var _spawn_sorter: CorticalNodeSpawnSorter


func _ready():
	super()
	FeagiCacheEvents.cortical_area_added.connect(spawn_single_cortical_node)
	FeagiCacheEvents.cortical_area_removed.connect(delete_single_cortical_node)
	FeagiCacheEvents.cortical_areas_connection_modified.connect(spawn_established_connection)
	FeagiCacheEvents.cortical_areas_disconnected.connect(delete_established_connection)
	_spawn_sorter = CorticalNodeSpawnSorter.new(algorithm_cortical_area_spacing, NODE_SIZE)



## Spawns a cortical Node, should only be called via FEAGI
func spawn_single_cortical_node(cortical_area: CorticalArea) -> CorticalNode:
	var cortical_node: CorticalNode = _cortical_node_prefab.instantiate()
	#cortical_node.user_started_connection_from.connect(_user_starting_drag_from)
	var offset: Vector2
	if !cortical_area.is_coordinates_2D_available: #TODO REMOVE THE !
		offset = cortical_area.coordinates_2D
	else:
		if VisConfig.visualizer_state == VisConfig.STATES.LOADING_INITIAL:
			offset = _spawn_sorter.add_cortical_area_to_memory_and_return_position(cortical_area.group)
		else:
			offset = Vector2(0.0,0.0)
	_background_center.add_child(cortical_node)
	cortical_node.setup(cortical_area, offset)
	cortical_nodes[cortical_area.cortical_ID] = cortical_node
	return cortical_node

func delete_single_cortical_node(cortical_area: CorticalArea) -> void:
	if cortical_area.cortical_ID not in cortical_nodes.keys():
		push_error("Attempted to remove non-existant cortex node " + cortical_area.cortical_ID + "! Skipping...")
	var node: CorticalNode = cortical_nodes[cortical_area.cortical_ID]
	node.FEAGI_delete_cortical_area()
	cortical_nodes.erase(cortical_area.cortical_ID)

## Should only be called from feagi when conneciton creation is confirmed
func spawn_established_connection(source: CorticalArea, destination: CorticalArea, mapping_count: int) -> void:
	if source.cortical_ID not in cortical_nodes.keys():
		push_error("Unable to create a connection due to missing cortical area %s! Skipping!" % source.cortical_ID)
		return
	if destination.cortical_ID not in cortical_nodes.keys():
		push_error("Unable to create a connection due to missing cortical area %s! Skipping!" % destination.cortical_ID)
		return
	
	if destination.cortical_ID in cortical_nodes[source.cortical_ID].cortical_connection_destinations.keys():
		# Connection already exists. Update!
		cortical_nodes[source.cortical_ID].cortical_connection_destinations[destination.cortical_ID].update_mapping(mapping_count)
		return

	var confirmed_connection: Connection2DConfirmed = Connection2DConfirmed.new(cortical_nodes[source.cortical_ID], cortical_nodes[destination.cortical_ID], mapping_count, _background_center)
	cortical_nodes[source.cortical_ID].cortical_connection_destinations[destination.cortical_ID] = confirmed_connection

## Should only be called from feagi when connection deletion is confirmed
func delete_established_connection(source: CorticalArea, destination: CorticalArea) -> void:
	if source.cortical_ID not in cortical_nodes.keys():
		push_error("Unable to delete a connection from source cortical area %s since it was not found in the cache! Skipping!" % source.cortical_ID)
		return
	if destination.cortical_ID not in cortical_nodes[source.cortical_ID].cortical_connection_destinations.keys():
		push_error("Unable to delete a connection toward %s since no connection was found to begin with! Skipping!" % destination.cortical_ID)
		return
	
	cortical_nodes[source.cortical_ID].cortical_connection_destinations[destination.cortical_ID].queue_free()
	cortical_nodes[source.cortical_ID].cortical_connection_destinations.erase(destination.cortical_ID)



