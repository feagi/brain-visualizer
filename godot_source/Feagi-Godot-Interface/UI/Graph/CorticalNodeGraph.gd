extends NodeGraph
class_name CorticalNodeGraph

var cortical_nodes: Dictionary = {}

var _cortical_node_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/CorticalNode/CortexNode.tscn")

func _ready():
	super._ready()
	FeagiCacheEvents.cortical_area_added.connect(spawn_single_cortical_area)




## Spawns a cortical Node 
func spawn_single_cortical_area(cortical_area: CorticalArea) -> CorticalNode:
	var cortical_node: CorticalNode = _cortical_node_prefab.instantiate()
	var offset: Vector2
	if cortical_area.is_coordinates_2D_available:
		offset = cortical_area.coordinates_2D
	else:
		offset = VisConfig.screen_size / 2.0
	_background.add_child(cortical_node)
	cortical_node.setup(cortical_area, offset)
	cortical_nodes[cortical_area.cortical_ID] = cortical_node
	return cortical_node

