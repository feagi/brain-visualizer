extends GraphEdit
class_name CircuitBuilder
## A 2D Node based representation of a specific Genome Region

@export var move_time_delay_before_update_FEAGI: float = 5.0
@export var initial_position: Vector2
@export var initial_zoom: float
@export var keyboard_movement_speed: Vector2 = Vector2(1,1)
@export var keyboard_move_speed: float = 50.0

const PREFAB_NODE_CORTICALAREA: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeCorticalArea/CBNodeCorticalArea.tscn")
const PREFAB_NODE_BRAINREGION: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeBrainRegion/CBNodeRegion.tscn")

var representing_region: BrainRegion:
	get: return _representing_region
var cortical_nodes: Dictionary:## All cortical nodes on CB, key'd by their cortical ID 
	get: return  _cortical_nodes 
var subregion_nodes: Dictionary: ## All subregion nodes on CB, key'd by their region ID
	get: return _subregion_nodes

var _cortical_nodes: Dictionary = {}
var _subregion_nodes: Dictionary = {}
var _representing_region: BrainRegion

func setup(region: BrainRegion) -> void:
	_representing_region = region
	
	for area: BaseCorticalArea in _representing_region.contained_cortical_areas:
		CACHE_add_cortical_area(area)
	
	for subregion: BrainRegion in _representing_region.contained_regions:
		CACHE_add_subregion(subregion)
	
	name = region.name
	
	region.name_changed.connect(CACHE_this_region_name_update)
	region.cortical_area_added_to_region.connect(CACHE_add_cortical_area)
	region.cortical_area_removed_from_region.connect(CACHE_remove_cortical_area)
	region.subregion_added_to_region.connect(CACHE_add_subregion)
	region.subregion_removed_from_region.connect(CACHE_remove_subregion)

#region Responses to Cache Signals

func CACHE_add_cortical_area(area: BaseCorticalArea) -> void:
	if (area.cortical_ID in cortical_nodes.keys()):
		push_error("UI CB: Unable to add cortical area %s node when a node of it already exists!!" % area.cortical_ID)
		return
	var cortical_node: CBNodeCorticalArea = PREFAB_NODE_CORTICALAREA.instantiate()
	cortical_nodes[area.cortical_ID] = cortical_node
	add_child(cortical_node)
	cortical_node.setup(area)

func CACHE_remove_cortical_area(area: BaseCorticalArea) -> void:
	if !(area.cortical_ID in cortical_nodes.keys()):
		push_error("UI CB: Unable to find cortical area %s to remove node of!" % area.cortical_ID)
		return
	#NOTE: We assume that all connections to / from this area have already been called to be removed by the cache FIRST
	cortical_nodes[area.cortical_ID].queue_free()
	cortical_nodes.erase(area.cortical_ID)
	

func CACHE_add_subregion(subregion: BrainRegion) -> void:
	if (subregion.ID in subregion_nodes.keys()):
		push_error("UI CB: Unable to add region %s node when a node of it already exists!!" % subregion.ID)
		return
	var region_node: CBNodeRegion = PREFAB_NODE_BRAINREGION.instantiate()
	subregion_nodes[subregion.ID] = region_node
	add_child(region_node)
	region_node.setup(subregion)

func CACHE_remove_subregion(subregion: BrainRegion) -> void:
	if !(subregion.ID in subregion_nodes.keys()):
		push_error("UI CB: Unable to find region %s to remove node of!" % subregion.ID)
		return
	#NOTE: We assume that all connections to / from this region have already been called to beremoved by the cache FIRST
	subregion_nodes[subregion.ID].queue_free()
	subregion_nodes.erase(subregion.ID)

## The name of the region this instance of CB has changed. Updating the Node name causes the tab name to update too
func CACHE_this_region_name_update(new_name: StringName) -> void:
	name = new_name