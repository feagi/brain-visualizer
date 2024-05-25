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
const PREFAB_NODE_TERMINAL: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeTerminal/CBNodeTerminal.tscn")
const PREFAB_NODE_PORT: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBLine/CBLineInterTerminal.tscn")

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
	
	for bridge_link: ConnectionChainLink in _representing_region.bridge_chain_links:
		CACHE_link_bridge_added(bridge_link)
	
	name = region.name
	
	region.name_updated.connect(CACHE_this_region_name_update)
	region.cortical_area_added_to_region.connect(CACHE_add_cortical_area)
	region.cortical_area_removed_from_region.connect(CACHE_remove_cortical_area)
	region.subregion_added_to_region.connect(CACHE_add_subregion)
	region.subregion_removed_from_region.connect(CACHE_remove_subregion)
	region.bridge_link_added.connect(CACHE_link_bridge_added)

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
	region_node.double_clicked.connect(_user_double_clicked_region)

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

func CACHE_link_bridge_added(link: ConnectionChainLink) -> void:
	var source_node: CBNodeConnectableBase =  _get_associated_connectable_graph_node(link.source)
	var destination_node: CBNodeConnectableBase =  _get_associated_connectable_graph_node(link.destination)
	if (source_node == null) or (destination_node == null):
		push_error("UI CB: Failed to add link in CB of region %s" % _representing_region.ID)
		return

	if source_node == destination_node:
		#This is a recursive connection
		source_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.RECURSIVE, source_node.title, PREFAB_NODE_TERMINAL)
		return
	var source_terminal: CBNodeTerminal = source_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.OUTPUT, destination_node.title, PREFAB_NODE_TERMINAL)
	var destination_terminal: CBNodeTerminal = destination_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.INPUT, source_node.title, PREFAB_NODE_TERMINAL)
	
	var line: CBLineInterTerminal = PREFAB_NODE_PORT.instantiate()
	add_child(line)
	line.setup(source_terminal.active_port, destination_terminal.active_port, link)

#endregion


#region User Interactions
signal user_request_viewing_subregion(region: BrainRegion)

func _user_double_clicked_region(region_node: CBNodeRegion) -> void:
	user_request_viewing_subregion.emit(region_node.representing_region)

#endregion

#region Internals

## Attempts to return the associated graph node for a given genome cache object. Returns null if fails
func _get_associated_connectable_graph_node(genome_object: GenomeObject) -> CBNodeConnectableBase:
	if genome_object is BaseCorticalArea:
		if !((genome_object as BaseCorticalArea).cortical_ID in _cortical_nodes.keys()):
			push_error("UI CB: Unable to find area %s node in CB for region %s" % [(genome_object as BaseCorticalArea).cortical_ID, _representing_region.ID])
			return null
		return _cortical_nodes[(genome_object as BaseCorticalArea).cortical_ID]
	else:
		#brain region
		if !((genome_object as BrainRegion).ID in _subregion_nodes.keys()):
			push_error("UI CB: Unable to find region %s node in CB for region %s" % [(genome_object as BrainRegion).ID, _representing_region.ID])
			return null
		return _subregion_nodes[(genome_object as BrainRegion).ID]
#endregion
