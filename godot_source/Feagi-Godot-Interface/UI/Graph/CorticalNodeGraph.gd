extends NodeGraph
class_name CorticalNodeGraph

## All cortical nodes on CB, key'd by their ID
var cortical_nodes: Dictionary = {}

var _cortical_node_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/CorticalNode/CortexNode.tscn")
var _connection_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/Connection/Connection.tscn")

func _ready():
	super._ready()
	FeagiCacheEvents.cortical_area_added.connect(spawn_single_cortical_node)
	FeagiCacheEvents.cortical_area_removed.connect(delete_single_cortical_node)
	FeagiCacheEvents.cortical_areas_connected.connect(spawn_connection)



## Spawns a cortical Node, should only be called via FEAGI
func spawn_single_cortical_node(cortical_area: CorticalArea) -> CorticalNode:
	var cortical_node: CorticalNode = _cortical_node_prefab.instantiate()
	var offset: Vector2
	if cortical_area.is_coordinates_2D_available:
		offset = cortical_area.coordinates_2D
	else:
		offset = VisConfig.screen_size / 2.0
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

func spawn_connection(source_ID: StringName, destination_ID: StringName, mapping_count: int) -> void:
	var connection: Node_Connection = _connection_prefab.instantiate()
	var source: CorticalNode = cortical_nodes[source_ID]
	var destination: CorticalNode = cortical_nodes[destination_ID]
	connection.spawn_connected(source.connection_input, destination.connection_output, mapping_count, self)

