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
const PREFAB_NODE_REGIONIO: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeRegionIO/CBNodeRegionIO.tscn") #WARNING DELETE ME
const PREFAB_REGIONIO_NODE: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBRegionIONode/CBRegionIONode.tscn")
const PREFAB_NODE_TERMINAL: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeTerminal/CBNodeTerminal.tscn")#WARNING DELETE ME
const PREFAB_ENDPOINT: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBLineEndpoint/CBLineEndPoint.tscn")
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
var _move_timer: Timer
var _moved_genome_objects_buffer: Dictionary = {} # Key'd by object ref, value is new vector2 position

func _ready():
	_move_timer = $Timer
	_move_timer.wait_time = move_time_delay_before_update_FEAGI
	_move_timer.one_shot = true
	_move_timer.timeout.connect(_move_timer_finished)
	focus_entered.connect(_toggle_draggability_based_on_focus)
	focus_exited.connect(_toggle_draggability_based_on_focus)
	connection_request.connect(_on_connection_request)
	node_selected.connect(_node_select)
	node_deselected.connect(_node_deselect)


func setup(region: BrainRegion) -> void:
	_representing_region = region
	
	for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
		_CACHE_add_cortical_area(area)
	
	for subregion: BrainRegion in _representing_region.contained_regions:
		_CACHE_add_subregion(subregion)
	
	for bridge_link: ConnectionChainLink in _representing_region.bridge_chain_links:
		_CACHE_link_bridge_added(bridge_link)
	
	for parent_input: ConnectionChainLink in _representing_region.input_chain_links:
		if parent_input.parent_region != _representing_region:
			continue # We do not care about conneciton links that are inside other regions
		_CACHE_link_parent_input_added(parent_input)
	
	for parent_output: ConnectionChainLink in _representing_region.output_chain_links:
		if parent_output.parent_region != _representing_region:
			continue # We do not care about conneciton links that are inside other regions
		_CACHE_link_parent_output_added(parent_output)
	
	
	name = region.friendly_name
	
	region.friendly_name_updated.connect(_CACHE_this_region_name_update)
	region.cortical_area_added_to_region.connect(_CACHE_add_cortical_area)
	region.cortical_area_removed_from_region.connect(_CACHE_remove_cortical_area)
	region.subregion_added_to_region.connect(_CACHE_add_subregion)
	region.subregion_removed_from_region.connect(_CACHE_remove_subregion)
	region.bridge_link_added.connect(_CACHE_link_bridge_added)
	region.input_link_added.connect(_CACHE_link_parent_input_added)
	region.output_link_added.connect(_CACHE_link_parent_output_added)
	region.input_open_link_added.connect(_CACHE_link_region_input_open_added)
	
	BV.UI.user_selected_single_cortical_area.connect(_highlight_area)

#region Responses to Cache Signals

func _CACHE_add_cortical_area(area: AbstractCorticalArea) -> void:
	if (area.cortical_ID in cortical_nodes.keys()):
		push_error("UI CB: Unable to add cortical area %s node when a node of it already exists!!" % area.cortical_ID)
		return
	var cortical_node: CBNodeCorticalArea = PREFAB_NODE_CORTICALAREA.instantiate()
	_cortical_nodes[area.cortical_ID] = cortical_node
	add_child(cortical_node)
	cortical_node.setup(area)
	cortical_node.node_moved.connect(_genome_object_moved)
	
func _CACHE_remove_cortical_area(area: AbstractCorticalArea) -> void:
	if !(area.cortical_ID in cortical_nodes.keys()):
		push_error("UI CB: Unable to find cortical area %s to remove node of!" % area.cortical_ID)
		return
	_cortical_nodes[area.cortical_ID].queue_free()
	_cortical_nodes.erase(area.cortical_ID)
	
func _CACHE_add_subregion(subregion: BrainRegion) -> void:
	if (subregion.region_ID in subregion_nodes.keys()):
		push_error("UI CB: Unable to add region %s node when a node of it already exists!!" % subregion.region_ID)
		return
	var region_node: CBNodeRegion = PREFAB_NODE_BRAINREGION.instantiate()
	_subregion_nodes[subregion.region_ID] = region_node
	add_child(region_node)
	region_node.setup(subregion)
	region_node.double_clicked.connect(_user_double_clicked_region)
	region_node.node_moved.connect(_genome_object_moved)
	subregion.subregion_removed_from_region.connect(_CACHE_remove_subregion)
	for link: ConnectionChainLink in subregion.input_open_chain_links:
		_CACHE_link_region_input_open_added(region_node, link)
	for link: ConnectionChainLink in subregion.output_open_chain_links:
		_CACHE_link_region_output_open_added(region_node, link)
	#TODO  _CACHE_link_region_input_open_added _CACHE_link_region_output_open_added need to be signal responsive!

func _CACHE_remove_subregion(subregion: BrainRegion) -> void:
	if !(subregion.region_ID in subregion_nodes.keys()):
		push_error("UI CB: Unable to find region %s to remove node of!" % subregion.region_ID)
		return
	#NOTE: We assume that all connections to / from this region have already been called to beremoved by the cache FIRST
	subregion_nodes[subregion.region_ID].queue_free()
	subregion_nodes.erase(subregion.region_ID)

## The name of the region this instance of CB has changed. Updating the Node name causes the tab name to update too
func _CACHE_this_region_name_update(new_name: StringName) -> void:
	name = new_name

func _CACHE_link_bridge_added(link: ConnectionChainLink) -> void:
	if link.parent_region != representing_region:
		return
	var source_node: CBNodeConnectableBase = _get_associated_connectable_graph_node(link.source)
	var destination_node: CBNodeConnectableBase = _get_associated_connectable_graph_node(link.destination)

	if (source_node == null) or (destination_node == null):
		push_error("UI CB: Failed to add link in CB of region %s" % _representing_region.region_ID)
		return

	if source_node == destination_node:
		#This is a recursive connection
		source_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.RECURSIVE, source_node.title, PREFAB_NODE_TERMINAL)
		return
	
	var source_title: StringName
	var destination_title: StringName
	if link.parent_chain.is_registered_to_established_mapping_set():
		source_title = link.parent_chain.source.friendly_name
		destination_title = link.parent_chain.destination.friendly_name
	else:
		# TODO fallback for partial mapping set
		source_title = source_node.title
		destination_title = destination_node.title
	
	var source_terminal: CBNodeTerminal = source_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.OUTPUT, destination_title, PREFAB_NODE_TERMINAL)
	var destination_terminal: CBNodeTerminal = destination_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.INPUT, source_title, PREFAB_NODE_TERMINAL)
	
	var line: CBLineInterTerminal = PREFAB_NODE_PORT.instantiate()
	add_child(line)
	move_child(line, 0)
	line.setup(source_terminal.active_port, destination_terminal.active_port, link)

func _CACHE_link_parent_input_added(link: ConnectionChainLink) -> void:
	if link.parent_region != representing_region:
		return
	var destination_node: CBNodeConnectableBase = _get_associated_connectable_graph_node(link.destination)
	
	if destination_node == null:
		push_error("UI CB: Failed to add link in CB of region %s" % _representing_region.region_ID)
		return
	
	var source_node: CBRegionIONode = _spawn_and_position_region_IO_node(true, destination_node)
	source_node.setup(link.parent_chain.source, link.parent_chain.destination, true)
	
	var source_title: StringName
	if link.parent_chain.is_registered_to_established_mapping_set():
		source_title = link.parent_chain.source.friendly_name
	else:
		# TODO fallback for partial mapping set
		pass
	
	#var source_terminal: CBNodeTerminal = source_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.OUTPUT, destination_title, PREFAB_NODE_TERMINAL)
	var source_endpoint: CBLineEndpoint = source_node.add_output_endpoint(PREFAB_ENDPOINT, CBLineEndpoint.PORT_STYLE.FULL)
	var destination_terminal: CBNodeTerminal = destination_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.INPUT, source_title, PREFAB_NODE_TERMINAL)

	var line: CBLineInterTerminal = PREFAB_NODE_PORT.instantiate()
	add_child(line)
	move_child(line, 0)
	line.setup(source_endpoint, destination_terminal.active_port, link)

func _CACHE_link_parent_output_added(link: ConnectionChainLink) -> void:
	if link.parent_region != representing_region:
		return
	var source_node: CBNodeConnectableBase = _get_associated_connectable_graph_node(link.source)
	
	if source_node == null:
		push_error("UI CB: Failed to add link in CB of region %s" % _representing_region.region_ID)
		return
	
	var destination_node: CBRegionIONode = _spawn_and_position_region_IO_node(false, source_node)
	destination_node.setup(link.parent_chain.destination, link.parent_chain.source, false)
	
	var destination_title: StringName
	if link.parent_chain.is_registered_to_established_mapping_set():
		destination_title = link.parent_chain.destination.friendly_name
	else:
		# TODO fallback for partial mapping set
		pass
	
	var source_terminal: CBNodeTerminal = source_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.OUTPUT, destination_title, PREFAB_NODE_TERMINAL)
	var destination_endpoint: CBLineEndpoint = destination_node.add_input_endpoint(PREFAB_ENDPOINT, CBLineEndpoint.PORT_STYLE.FULL)

	var line: CBLineInterTerminal = PREFAB_NODE_PORT.instantiate()
	add_child(line)
	move_child(line, 0)
	line.setup(source_terminal.active_port, destination_endpoint, link)

# This is called from the Brain Region nodes directly
func _CACHE_link_region_input_open_added(region_node: CBNodeRegion, link: ConnectionChainLink) -> void:
	region_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.INPUT_OPEN, link.parent_chain.partial_mapping_set.internal_target_cortical_area.friendly_name, PREFAB_NODE_TERMINAL)
	
# This is called from the Brain Region nodes directly
func _CACHE_link_region_output_open_added(region_node: CBNodeRegion, link: ConnectionChainLink) -> void:
	region_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.OUTPUT_OPEN, link.parent_chain.partial_mapping_set.internal_target_cortical_area.friendly_name, PREFAB_NODE_TERMINAL)
	

#endregion


#region User Interactions
signal user_request_viewing_subregion(region: BrainRegion)
signal user_adds_object_to_selected_object_pool(object: GenomeObject)
signal user_removes_object_from_selected_object_pool(object: GenomeObject)
signal user_request_action_on_selected_objects()

var _number_selected_objects: int = 0
var _last_selected_object: GenomeObject = null

func _input(event):
	#NOTE: This fires before selection/deselection graphnode signals
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_number_selected_objects = len(BV.UI.currently_selected_objects)
			if _number_selected_objects == 1:
				_last_selected_object = BV.UI.currently_selected_objects[0]
		else:
			if _number_selected_objects != len(BV.UI.currently_selected_objects) and len(BV.UI.currently_selected_objects) != 0:
				user_request_action_on_selected_objects.emit()
				return
			if len(BV.UI.currently_selected_objects) == 1 and _last_selected_object != BV.UI.currently_selected_objects[0]:
				user_request_action_on_selected_objects.emit()
				return
				
func unhighlight_all_area_nodes() -> void:
	for node in _cortical_nodes.values():
		node.selected = false

func _node_select(element: GraphElement) -> void:
	if element is CBNodeRegion:
		print("CB Selected " + (element as CBNodeRegion).representing_region.friendly_name)
		user_adds_object_to_selected_object_pool.emit((element as CBNodeRegion).representing_region)
		return
	if element is CBNodeCorticalArea:
		print("CB Selected " + (element as CBNodeCorticalArea).representing_cortical_area.friendly_name)
		user_adds_object_to_selected_object_pool.emit((element as CBNodeCorticalArea).representing_cortical_area)
		return

func _node_deselect(element: GraphElement) -> void:
	if element is CBNodeRegion:
		print("CB Deselected " + (element as CBNodeRegion).representing_region.friendly_name)
		user_removes_object_from_selected_object_pool.emit((element as CBNodeRegion).representing_region)
		return
	if element is CBNodeCorticalArea:
		print("CB Deselected " + (element as CBNodeCorticalArea).representing_cortical_area.friendly_name)
		user_removes_object_from_selected_object_pool.emit((element as CBNodeCorticalArea).representing_cortical_area)
		return

func _user_double_clicked_region(region_node: CBNodeRegion) -> void:
	user_request_viewing_subregion.emit(region_node.representing_region)

func _on_connection_request(from_node: StringName, _from_port: int, to_node: StringName, _to_port: int) -> void:
	var source: GenomeObject = null
	var destination: GenomeObject = null
	
	if (from_node in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas):
		source = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[from_node]
	elif from_node in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
		source = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions[from_node]
	
	if (to_node in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas):
			destination = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[to_node]
	elif to_node in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions:
		destination = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions[to_node]

	BV.UI.window_manager.spawn_mapping_editor(source, destination)

func _highlight_area(area: AbstractCorticalArea) -> void:
	if area.cortical_ID in _cortical_nodes:
		if _cortical_nodes[area.cortical_ID].selected:
			return
	unhighlight_all_area_nodes()
	if area.cortical_ID in _cortical_nodes:
		_cortical_nodes[area.cortical_ID].selected = true


#endregion

#region multi-select







#endregion

#region Internals

## Every time a cortical node moves, store and send it when time is ready
func _genome_object_moved(node: CBNodeConnectableBase, new_position: Vector2i) -> void:
	var genome_object: GenomeObject 
	if node is CBNodeCorticalArea:
		genome_object = (node as CBNodeCorticalArea).representing_cortical_area
	elif node is CBNodeRegion:
		genome_object = (node as CBNodeRegion).representing_region
	else:
		return
	print("Buffering change in position of genome object ")
	if _moved_genome_objects_buffer == {}:
		print("Starting 2D move timer for %d seconds" % move_time_delay_before_update_FEAGI)
		_move_timer.start()
	_moved_genome_objects_buffer[genome_object] = new_position

## When the move timer goes off, send all the buffered genome objects with their new positions to feagi
func _move_timer_finished():
	print("Sending change of 2D positions for %d objects(s)" % len(_moved_genome_objects_buffer.keys()))
	FeagiCore.requests.mass_move_genome_objects_2D(_moved_genome_objects_buffer)
	_moved_genome_objects_buffer = {}

## Attempts to return the associated graph node for a given genome cache object. Returns null if fails
func _get_associated_connectable_graph_node(genome_object: GenomeObject) -> CBNodeConnectableBase:
	if genome_object is AbstractCorticalArea:
		if !((genome_object as AbstractCorticalArea).cortical_ID in _cortical_nodes.keys()):
			push_error("UI CB: Unable to find area %s node in CB for region %s" % [(genome_object as AbstractCorticalArea).cortical_ID, _representing_region.region_ID])
			return null
		return _cortical_nodes[(genome_object as AbstractCorticalArea).cortical_ID]
	else:
		#brain region
		if !((genome_object as BrainRegion).region_ID in _subregion_nodes.keys()):
			push_error("UI CB: Unable to find region %s node in CB for region %s" % [(genome_object as BrainRegion).region_ID, _representing_region.region_ID])
			return null
		return _subregion_nodes[(genome_object as BrainRegion).region_ID]

func _spawn_and_position_region_IO_node(is_region_input: bool, target_node: CBNodeConnectableBase) -> CBRegionIONode:
	var IO_node: CBRegionIONode = PREFAB_REGIONIO_NODE.instantiate()
	add_child(IO_node)
	if is_region_input:
		IO_node.position_offset = target_node.position_offset - CBRegionIONode.CONNECTED_NODE_OFFSET
	else:
		IO_node.position_offset = target_node.position_offset + CBRegionIONode.CONNECTED_NODE_OFFSET
	return IO_node

func _DEPRECATED_spawn_and_position_region_IO_node(is_region_input: bool, target_node: CBNodeConnectableBase) -> CBNodeRegionIO:
	var IO_node: CBNodeRegionIO = PREFAB_NODE_REGIONIO.instantiate()
	add_child(IO_node)
	if is_region_input:
		IO_node.position_offset = target_node.position_offset - CBNodeRegionIO.CONNECTED_NODE_OFFSET
	else:
		IO_node.position_offset = target_node.position_offset + CBNodeRegionIO.CONNECTED_NODE_OFFSET
	return IO_node

func _toggle_draggability_based_on_focus() -> void:
	var are_nodes_draggable = has_focus()
	for child in get_children():
		if child is CBNodeConnectableBase:
			(child as CBNodeConnectableBase).draggable = are_nodes_draggable
			continue
#endregion

