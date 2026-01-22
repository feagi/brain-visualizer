extends GraphEdit
class_name CircuitBuilder
## A 2D Node based representation of a specific Genome Region

@export var move_time_delay_before_update_FEAGI: float = 5.0
@export var keyboard_movement_speed: Vector2 = Vector2(1,1)
@export var keyboard_move_speed: float = 50.0
@export var initial_fit_padding: Vector2 = Vector2(128, 128)

const PREFAB_NODE_CORTICALAREA: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeCorticalArea/CBNodeCorticalArea.tscn")
const PREFAB_NODE_BRAINREGION: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeBrainRegion/CBNodeRegion.tscn")
const PREFAB_NODE_REGIONIO: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBRegionIONode/CBRegionIONode.tscn")
const PREFAB_NODE_TERMINAL: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeTerminal/CBNodeTerminal.tscn")#WARNING DELETE ME
const PREFAB_ENDPOINT: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBLineEndpoint/CBLineEndPoint.tscn")
const PREFAB_NODE_PORT: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBLine/CBLineInterTerminal.tscn")
const LAYOUT_COLUMN_GAP: float = 480.0
const LAYOUT_ROW_GAP: float = 48.0

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
var _move_flush_pending: bool = false
var _multi_relocate_active: bool = false
var _multi_relocate_anchor_mouse: Vector2 = Vector2.ZERO
var _multi_relocate_node_start_positions: Dictionary = {}
var _multi_relocate_nodes: Array[CBNodeConnectableBase] = []
var _suppress_move_buffer: bool = false
var _initial_fit_done: bool = false
var _initial_fit_in_progress: bool = false
const INITIAL_FIT_RETRY_MAX: int = 12

var _mouse_clicked_background: bool = false
var _mouse_clicked_prev_position: Vector2
var _combo: BrainObjectsCombo = null

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
	visibility_changed.connect(_attempt_initial_fit)
	resized.connect(_attempt_initial_fit)
	child_entered_tree.connect(_attempt_initial_fit)
	if has_node("BrainObjectsCombo"):
		_combo = $BrainObjectsCombo
		if _representing_region != null:
			_combo.set_2d_context(self, _representing_region)

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		request_initial_fit()



func setup(region: BrainRegion) -> void:
	_representing_region = region
	_initial_fit_done = false
	if _combo:
		_combo.set_2d_context(self, _representing_region)
	
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
	region.output_open_link_added.connect(_CACHE_link_region_output_open_added)
	call_deferred("_attempt_initial_fit")
	

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
	BV.UI.selection_system.clear_all_highlighted()
	var node: CBNodeCorticalArea = _cortical_nodes[area.cortical_ID]
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()
	_cortical_nodes.erase(area.cortical_ID)
	
func _CACHE_add_subregion(subregion: BrainRegion) -> void:
	if (subregion.region_ID in subregion_nodes.keys()):
		push_error("UI CB: Unable to add region %s node when a node of it already exists!!" % subregion.region_ID)
		return
	BV.UI.selection_system.clear_all_highlighted()
	var region_node: CBNodeRegion = PREFAB_NODE_BRAINREGION.instantiate()
	_subregion_nodes[subregion.region_ID] = region_node
	add_child(region_node)
	region_node.setup(subregion)
	region_node.double_clicked.connect(_user_double_clicked_region)
	region_node.node_moved.connect(_genome_object_moved)
	subregion.subregion_removed_from_region.connect(_CACHE_remove_subregion)
	for link: ConnectionChainLink in subregion.input_open_chain_links:
		_CACHE_link_region_input_open_added(link)
	for link: ConnectionChainLink in subregion.output_open_chain_links:
		_CACHE_link_region_output_open_added(link)
	#TODO  _CACHE_link_region_input_open_added _CACHE_link_region_output_open_added need to be signal responsive!

func _CACHE_remove_subregion(subregion: BrainRegion) -> void:
	if !(subregion.region_ID in subregion_nodes.keys()):
		push_error("UI CB: Unable to find region %s to remove node of!" % subregion.region_ID)
		return
	BV.UI.selection_system.clear_all_highlighted()
	#NOTE: We assume that all connections to / from this region have already been called to beremoved by the cache FIRST
	var node: CBNodeRegion = subregion_nodes[subregion.region_ID]
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		node.queue_free()
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
	line.call_deferred("setup", source_terminal.active_port, destination_terminal.active_port, link)

func _CACHE_link_parent_input_added(link: ConnectionChainLink) -> void:
	if _representing_region != null and _representing_region.is_root_region():
		return
	if link.parent_region != representing_region:
		return
	var destination_node: CBNodeConnectableBase = _get_associated_connectable_graph_node(link.destination)
	
	if destination_node == null:
		push_error("UI CB: Failed to add link in CB of region %s" % _representing_region.region_ID)
		return
	
	var source_node: CBRegionIONode = _spawn_and_position_region_IO_node(true, destination_node, destination_node.get_number_inputs())
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
	line.call_deferred("setup", source_endpoint, destination_terminal.active_port, link)

func _CACHE_link_parent_output_added(link: ConnectionChainLink) -> void:
	if _representing_region != null and _representing_region.is_root_region():
		return
	if link.parent_region != representing_region:
		return
	var source_node: CBNodeConnectableBase = _get_associated_connectable_graph_node(link.source)
	
	if source_node == null:
		push_error("UI CB: Failed to add link in CB of region %s" % _representing_region.region_ID)
		return
	
	var destination_node: CBRegionIONode = _spawn_and_position_region_IO_node(false, source_node, source_node.get_number_outputs())
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
	line.call_deferred("setup", source_terminal.active_port, destination_endpoint, link)

# This is called from the Brain Region nodes directly
func _CACHE_link_region_input_open_added(link: ConnectionChainLink) -> void:
	var target_region: BrainRegion = null
	if link.is_destination_region():
		target_region = link.destination as BrainRegion
	elif link.is_source_region():
		target_region = link.source as BrainRegion
	
	if target_region == null:
		return
	if !(target_region.region_ID in _subregion_nodes):
		return
	
	var region_node: CBNodeRegion = _subregion_nodes[target_region.region_ID]
	region_node.CB_add_connection_terminal(
		CBNodeTerminal.TYPE.INPUT_OPEN,
		link.parent_chain.partial_mapping_set.internal_target_cortical_area.friendly_name,
		PREFAB_NODE_TERMINAL
	)
	
# This is called from the Brain Region nodes directly
func _CACHE_link_region_output_open_added(link: ConnectionChainLink) -> void:
	var target_region: BrainRegion = null
	if link.is_source_region():
		target_region = link.source as BrainRegion
	elif link.is_destination_region():
		target_region = link.destination as BrainRegion
	
	if target_region == null:
		return
	if !(target_region.region_ID in _subregion_nodes):
		return
	
	var region_node: CBNodeRegion = _subregion_nodes[target_region.region_ID]
	region_node.CB_add_connection_terminal(
		CBNodeTerminal.TYPE.OUTPUT_OPEN,
		link.parent_chain.partial_mapping_set.internal_target_cortical_area.friendly_name,
		PREFAB_NODE_TERMINAL
	)
	

#endregion


#region User Interactions
signal user_request_viewing_subregion(region: BrainRegion)

func _gui_input(event):
	if _multi_relocate_active:
		_handle_multi_relocate_input(event)
		return
	if !(event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		for node in get_children(): # BAD
			if !(node is GraphElement):
				continue
			if (node as GraphElement).get_global_rect().has_point(get_global_mouse_position()):
				return
		
		if !_mouse_clicked_background:
			_mouse_clicked_background = true
			_mouse_clicked_prev_position = get_global_mouse_position()
		return
	else:
		if _mouse_clicked_background:
			_mouse_clicked_background = false
			if (_mouse_clicked_prev_position - get_global_mouse_position()).length() > 1.0:
				print("drag box detected!")
				BV.UI.selection_system.select_objects(SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_DRAG)


func _node_select(element: GraphElement) -> void:
	if element is CBNodeRegion:
		print("CB Selected " + (element as CBNodeRegion).representing_region.friendly_name)
		BV.UI.selection_system.add_to_highlighted((element as CBNodeRegion).representing_region)
		return
	if element is CBNodeCorticalArea:
		print("CB Selected " + (element as CBNodeCorticalArea).representing_cortical_area.friendly_name)
		BV.UI.selection_system.add_to_highlighted((element as CBNodeCorticalArea).representing_cortical_area)
		return

func _node_deselect(element: GraphElement) -> void:
	if element is CBNodeRegion:
		print("CB Deselected " + (element as CBNodeRegion).representing_region.friendly_name)
		BV.UI.selection_system.remove_from_highlighted((element as CBNodeRegion).representing_region)
		return
	if element is CBNodeCorticalArea:
		print("CB Deselected " + (element as CBNodeCorticalArea).representing_cortical_area.friendly_name)
		BV.UI.selection_system.remove_from_highlighted((element as CBNodeCorticalArea).representing_cortical_area)
		return

## Ensure only the provided element remains selected in GraphEdit.
func _select_single_graph_element(element: GraphElement) -> void:
	for node in get_children():
		if node is GraphElement and node != element:
			(node as GraphElement).selected = false
	if element != null:
		element.selected = true

func _user_double_clicked_region(region_node: CBNodeRegion) -> void:
	BV.UI.selection_system.clear_all_highlighted()
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


#endregion

#region multi-select







#endregion

#region Internals

## Every time a cortical node moves, store and send it when time is ready
func _genome_object_moved(node: CBNodeConnectableBase, new_position: Vector2i) -> void:
	if _suppress_move_buffer:
		return
	var genome_object: GenomeObject 
	if node is CBNodeCorticalArea:
		genome_object = (node as CBNodeCorticalArea).representing_cortical_area
	elif node is CBNodeRegion:
		genome_object = (node as CBNodeRegion).representing_region
	else:
		return
	print("Buffering change in position of genome object ")
	_moved_genome_objects_buffer[genome_object] = new_position
	_request_immediate_move_flush()

## When the move timer goes off, send all the buffered genome objects with their new positions to feagi
func _move_timer_finished():
	await _flush_move_buffer()

func _request_immediate_move_flush() -> void:
	if _move_flush_pending:
		return
	_move_flush_pending = true
	get_tree().create_timer(0.0).timeout.connect(_move_timer_finished)

func _flush_move_buffer() -> void:
	_move_flush_pending = false
	if _moved_genome_objects_buffer.is_empty():
		return
	var payload := _moved_genome_objects_buffer
	_moved_genome_objects_buffer = {}
	print("Sending change of 2D positions for %d objects(s)" % len(payload.keys()))
	var result: FeagiRequestOutput = await FeagiCore.requests.mass_move_genome_objects_2D(payload)
	if result.has_errored:
		print("CB_RELAYOUT_DEBUG: move save failed -> ", result.decode_response_as_generic_error_code())
		BV.NOTIF.add_notification(
			"Move failed to save positions.",
			NotificationSystemNotification.NOTIFICATION_TYPE.ERROR
		)
		return
	var save_result: FeagiRequestOutput = await FeagiCore.requests.save_genome()
	if save_result.has_errored:
		print("CB_RELAYOUT_DEBUG: genome save failed -> ", save_result.decode_response_as_generic_error_code())
		BV.NOTIF.add_notification(
			"Move saved positions but failed to save genome.",
			NotificationSystemNotification.NOTIFICATION_TYPE.WARNING
		)
		return
	BV.NOTIF.add_notification(
		"Move saved positions to genome.",
		NotificationSystemNotification.NOTIFICATION_TYPE.INFO
	)

func start_multi_relocate(selection: Array[GenomeObject]) -> void:
	_multi_relocate_nodes.clear()
	_multi_relocate_node_start_positions.clear()
	for obj in selection:
		if obj is AbstractCorticalArea or obj is BrainRegion:
			var node = _get_associated_connectable_graph_node(obj)
			if node != null:
				_multi_relocate_nodes.append(node)
				_multi_relocate_node_start_positions[node] = node.position_offset
	if _multi_relocate_nodes.is_empty():
		BV.NOTIF.add_notification("No selectable areas found for relocate.")
		return
	_multi_relocate_active = true
	_suppress_move_buffer = true
	_multi_relocate_anchor_mouse = get_global_mouse_position()
	BV.NOTIF.add_notification("Relocate mode: move mouse, left-click to commit.")

func _handle_multi_relocate_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var delta_pixels: Vector2 = get_global_mouse_position() - _multi_relocate_anchor_mouse
		var delta_graph: Vector2 = delta_pixels / max(zoom, 0.0001)
		for node in _multi_relocate_nodes:
			if _multi_relocate_node_start_positions.has(node):
				var start_pos: Vector2 = _multi_relocate_node_start_positions[node]
				node.position_offset = start_pos + delta_graph
		return
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_end_multi_relocate(true)
		return

func _end_multi_relocate(commit: bool) -> void:
	_multi_relocate_active = false
	_suppress_move_buffer = false
	if not commit:
		return
	call_deferred("_commit_multi_relocate")

func _commit_multi_relocate() -> void:
	if _multi_relocate_nodes.is_empty():
		return
	var cortical_payload: Dictionary = {}
	var region_payload: Dictionary = {}
	for node in _multi_relocate_nodes:
		if node is CBNodeCorticalArea:
			cortical_payload[(node as CBNodeCorticalArea).representing_cortical_area] = Vector2i(node.position_offset)
		elif node is CBNodeRegion:
			region_payload[(node as CBNodeRegion).representing_region] = Vector2i(node.position_offset)
	if cortical_payload.is_empty() and region_payload.is_empty():
		return
	if not cortical_payload.is_empty():
		print("Sending change of 2D positions for %d cortical area(s)" % len(cortical_payload.keys()))
		var cortical_result: FeagiRequestOutput = await FeagiCore.requests.mass_move_genome_objects_2D(cortical_payload)
		if cortical_result.has_errored:
			print("CB_RELAYOUT_DEBUG: move save failed -> ", cortical_result.decode_response_as_generic_error_code())
			BV.NOTIF.add_notification(
				"Relocate failed to save cortical areas.",
				NotificationSystemNotification.NOTIFICATION_TYPE.ERROR
			)
			return
	if not region_payload.is_empty():
		print("Sending change of 2D positions for %d region(s)" % len(region_payload.keys()))
		var region_result: FeagiRequestOutput = await FeagiCore.requests.mass_move_genome_objects_2D(region_payload)
		if region_result.has_errored:
			print("CB_RELAYOUT_DEBUG: move save failed -> ", region_result.decode_response_as_generic_error_code())
			BV.NOTIF.add_notification(
				"Relocate failed to save regions.",
				NotificationSystemNotification.NOTIFICATION_TYPE.ERROR
			)
			return
	var save_result: FeagiRequestOutput = await FeagiCore.requests.save_genome()
	if save_result.has_errored:
		print("CB_RELAYOUT_DEBUG: genome save failed -> ", save_result.decode_response_as_generic_error_code())
		BV.NOTIF.add_notification(
			"Relocate saved positions but failed to save genome.",
			NotificationSystemNotification.NOTIFICATION_TYPE.WARNING
		)
		return
	BV.NOTIF.add_notification(
		"Relocate saved positions to genome.",
		NotificationSystemNotification.NOTIFICATION_TYPE.INFO
	)

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

func _spawn_and_position_region_IO_node(is_region_input: bool, target_node: CBNodeConnectableBase, y_offset_index: int) -> CBRegionIONode:
	var IO_node: CBRegionIONode = PREFAB_NODE_REGIONIO.instantiate()
	add_child(IO_node)
	if is_region_input:
		IO_node.position_offset = target_node.position_offset - CBRegionIONode.CONNECTED_NODE_OFFSET + Vector2(0, (y_offset_index * CBRegionIONode.CONNECTED_NODE_OFFSET.y))
	else:
		IO_node.position_offset = target_node.position_offset + CBRegionIONode.CONNECTED_NODE_OFFSET - Vector2(0, (y_offset_index * CBRegionIONode.CONNECTED_NODE_OFFSET.y))
	return IO_node

func _toggle_draggability_based_on_focus() -> void:
	var are_nodes_draggable = has_focus()
	for child in get_children():
		if child is CBNodeConnectableBase:
			(child as CBNodeConnectableBase).draggable = are_nodes_draggable
			continue

## Focus helpers used by BrainObjectsCombo
func focus_on_region(region: BrainRegion) -> void:
	var node: CBNodeConnectableBase = _get_associated_connectable_graph_node(region)
	if node == null:
		return
	_center_on_graph_element(node)
	_bring_node_to_front_and_jiggle(node)

func focus_on_cortical_area(area: AbstractCorticalArea) -> void:
	var node: CBNodeConnectableBase = _get_associated_connectable_graph_node(area)
	if node == null:
		return
	_center_on_graph_element(node)
	_bring_node_to_front_and_jiggle(node)

	## Rearrange all nodes into columns (inputs left, interconnect/memory/regions middle, outputs right).
func relayout_nodes() -> void:
	var layout_positions: Dictionary = _compute_relayout_positions()
	if layout_positions.is_empty():
		return
	_log_relayout_debug(layout_positions)
	var update_payload: Dictionary = {}
	for node in layout_positions.keys():
		var new_pos: Vector2 = layout_positions[node]
		if node.position_offset != new_pos:
			node.position_offset = new_pos
		if node is CBNodeCorticalArea:
			update_payload[(node as CBNodeCorticalArea).representing_cortical_area] = Vector2i(new_pos)
		elif node is CBNodeRegion:
			update_payload[(node as CBNodeRegion).representing_region] = Vector2i(new_pos)
	if not update_payload.is_empty():
		print("CB_RELAYOUT_DEBUG: saving %d objects to FEAGI" % update_payload.size())
		var result: FeagiRequestOutput = await FeagiCore.requests.mass_move_genome_objects_2D(update_payload)
		if result.has_errored:
			print("CB_RELAYOUT_DEBUG: save failed -> ", result.decode_response_as_generic_error_code())
			BV.NOTIF.add_notification(
				"Auto-arrange failed to save positions.",
				NotificationSystemNotification.NOTIFICATION_TYPE.ERROR
			)
			return
		print("CB_RELAYOUT_DEBUG: saving genome after relayout")
		var save_result: FeagiRequestOutput = await FeagiCore.requests.save_genome()
		if save_result.has_errored:
			print("CB_RELAYOUT_DEBUG: genome save failed -> ", save_result.decode_response_as_generic_error_code())
			BV.NOTIF.add_notification(
				"Auto-arrange saved positions but failed to save genome.",
				NotificationSystemNotification.NOTIFICATION_TYPE.WARNING
			)
			return
		BV.NOTIF.add_notification(
			"Auto-arrange saved positions to genome.",
			NotificationSystemNotification.NOTIFICATION_TYPE.INFO
		)

## Compute layout positions using simple barycenter ordering to reduce connection overlap.
func _compute_relayout_positions() -> Dictionary:
	var nodes: Array[CBNodeConnectableBase] = []
	nodes.assign(_cortical_nodes.values())
	for region_node in _subregion_nodes.values():
		nodes.append(region_node)
	var region_io_nodes: Array[CBAbstractNode] = _collect_region_io_nodes()
	if nodes.is_empty() and region_io_nodes.is_empty():
		return {}
	var adjacency: Dictionary = _build_cortical_adjacency()
	var outputs: Array[CBNodeConnectableBase] = []
	var inputs: Array[CBNodeConnectableBase] = []
	var inner_outputs: Array[CBAbstractNode] = []
	var inner_inputs: Array[CBAbstractNode] = []
	var middle: Array[CBNodeConnectableBase] = []
	for node in nodes:
		if node is CBNodeCorticalArea:
			var area: AbstractCorticalArea = (node as CBNodeCorticalArea).representing_cortical_area
			var side := _classify_cortical_io_side(area)
			if side == "left":
				inputs.append(node)
			elif side == "right":
				outputs.append(node)
			else:
				middle.append(node)
		else:
			middle.append(node)
	for io_node in region_io_nodes:
		if _is_region_io_input(io_node):
			inner_inputs.append(io_node)
		else:
			inner_outputs.append(io_node)
	var min_x := _compute_min_x(nodes)
	var min_y := _compute_min_y(nodes)
	var left_x := min_x
	var inner_left_x := left_x + _compute_max_width(inputs) + LAYOUT_COLUMN_GAP
	var middle_x := inner_left_x + _compute_max_width_region_io(inner_inputs) + LAYOUT_COLUMN_GAP
	var inner_right_x := middle_x + _compute_max_width(middle) + LAYOUT_COLUMN_GAP
	var right_x := inner_right_x + _compute_max_width_region_io(inner_outputs) + LAYOUT_COLUMN_GAP
	# Place IO columns first, then position interconnects between them.
	var ordered_inputs := _sort_io_nodes(inputs, true)
	var ordered_outputs := _sort_io_nodes(outputs, false)
	var input_positions := _layout_column(ordered_inputs, left_x, min_y)
	var output_positions := _layout_column(ordered_outputs, right_x, min_y)
	var inner_input_positions := _layout_column_region_io(_sort_region_io_by_current_y(inner_inputs), inner_left_x, min_y)
	var inner_output_positions := _layout_column_region_io(_sort_region_io_by_current_y(inner_outputs), inner_right_x, min_y)
	var io_y_map := _build_target_y_map(input_positions)
	for node in output_positions.keys():
		io_y_map[node] = (output_positions[node] as Vector2).y
	for node in inner_input_positions.keys():
		io_y_map[node] = (inner_input_positions[node] as Vector2).y
	for node in inner_output_positions.keys():
		io_y_map[node] = (inner_output_positions[node] as Vector2).y
	var ordered_middle := _sort_nodes_by_barycenter(middle, adjacency, io_y_map)
	var middle_positions := _layout_column(ordered_middle, middle_x, min_y)
	var layout_positions: Dictionary = {}
	for node in output_positions.keys():
		layout_positions[node] = output_positions[node]
	for node in inner_output_positions.keys():
		layout_positions[node] = inner_output_positions[node]
	for node in middle_positions.keys():
		layout_positions[node] = middle_positions[node]
	for node in inner_input_positions.keys():
		layout_positions[node] = inner_input_positions[node]
	for node in input_positions.keys():
		layout_positions[node] = input_positions[node]
	# Enforce strict column placement for all cortical areas.
	for node in nodes:
		if node is CBNodeCorticalArea:
			var area: AbstractCorticalArea = (node as CBNodeCorticalArea).representing_cortical_area
			var target_x := middle_x
			var side := _classify_cortical_io_side(area)
			if side == "left":
				target_x = left_x
			elif side == "right":
				target_x = right_x
			_set_node_column_x(layout_positions, node, target_x)
	for io_node in region_io_nodes:
		var io_target_x := inner_left_x if _is_region_io_input(io_node) else inner_right_x
		_set_node_column_x(layout_positions, io_node, io_target_x)
	return layout_positions

func _build_cortical_adjacency() -> Dictionary:
	var adjacency: Dictionary = {}
	if _representing_region == null:
		return adjacency
	for link: ConnectionChainLink in _representing_region.bridge_chain_links:
		if not (link.source is AbstractCorticalArea and link.destination is AbstractCorticalArea):
			continue
		var source_area: AbstractCorticalArea = link.source as AbstractCorticalArea
		var destination_area: AbstractCorticalArea = link.destination as AbstractCorticalArea
		var source_node: CBNodeConnectableBase = _cortical_nodes.get(source_area.cortical_ID, null)
		var destination_node: CBNodeConnectableBase = _cortical_nodes.get(destination_area.cortical_ID, null)
		if source_node == null or destination_node == null:
			continue
		if not adjacency.has(source_node):
			adjacency[source_node] = []
		if not adjacency.has(destination_node):
			adjacency[destination_node] = []
		adjacency[source_node].append(destination_node)
		adjacency[destination_node].append(source_node)
	return adjacency

func _sort_nodes_by_barycenter(nodes: Array[CBNodeConnectableBase], adjacency: Dictionary, ref_y_map: Dictionary) -> Array[CBNodeConnectableBase]:
	var sortable: Array[Dictionary] = []
	for node in nodes:
		var neighbors: Array = adjacency.get(node, [])
		var neighbor_ys: Array[float] = []
		for neighbor in neighbors:
			if not ref_y_map.is_empty() and ref_y_map.has(neighbor):
				neighbor_ys.append(ref_y_map[neighbor])
			else:
				neighbor_ys.append((neighbor as CBNodeConnectableBase).position_offset.y)
		var desired_y: float = node.position_offset.y
		if not neighbor_ys.is_empty():
			desired_y = _average(neighbor_ys)
		sortable.append({"node": node, "y": desired_y})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("y", 0.0)) < float(b.get("y", 0.0))
	)
	var ordered: Array[CBNodeConnectableBase] = []
	for item in sortable:
		ordered.append(item["node"])
	return ordered

func _layout_column(nodes: Array[CBNodeConnectableBase], column_x: float, start_y: float) -> Dictionary:
	var positions: Dictionary = {}
	var cursor_y: float = start_y
	for node in nodes:
		positions[node] = Vector2(column_x, cursor_y)
		cursor_y += node.size.y + LAYOUT_ROW_GAP
	return positions

func _layout_column_region_io(nodes: Array[CBAbstractNode], column_x: float, start_y: float) -> Dictionary:
	var positions: Dictionary = {}
	var cursor_y: float = start_y
	for node in nodes:
		positions[node] = Vector2(column_x, cursor_y)
		cursor_y += node.size.y + LAYOUT_ROW_GAP
	return positions

func _sort_region_io_by_current_y(nodes: Array[CBAbstractNode]) -> Array[CBAbstractNode]:
	var sortable: Array[Dictionary] = []
	for node in nodes:
		sortable.append({"node": node, "y": node.position_offset.y})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("y", 0.0)) < float(b.get("y", 0.0))
	)
	var ordered: Array[CBAbstractNode] = []
	for item in sortable:
		ordered.append(item["node"])
	return ordered

func _sort_nodes_by_current_y(nodes: Array[CBNodeConnectableBase]) -> Array[CBNodeConnectableBase]:
	var sortable: Array[Dictionary] = []
	for node in nodes:
		sortable.append({"node": node, "y": node.position_offset.y})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("y", 0.0)) < float(b.get("y", 0.0))
	)
	var ordered: Array[CBNodeConnectableBase] = []
	for item in sortable:
		ordered.append(item["node"])
	return ordered

func _sort_io_nodes(nodes: Array[CBNodeConnectableBase], is_input_column: bool) -> Array[CBNodeConnectableBase]:
	var sortable: Array[Dictionary] = []
	for node in nodes:
		var priority: int = _io_priority_for_node(node, is_input_column)
		sortable.append({"node": node, "priority": priority, "y": node.position_offset.y})
	sortable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var priority_a: int = int(a.get("priority", 0))
		var priority_b: int = int(b.get("priority", 0))
		if priority_a == priority_b:
			return float(a.get("y", 0.0)) < float(b.get("y", 0.0))
		return priority_a < priority_b
	)
	var ordered: Array[CBNodeConnectableBase] = []
	for item in sortable:
		ordered.append(item["node"])
	return ordered

func _io_priority_for_node(node: CBNodeConnectableBase, is_input_column: bool) -> int:
	if node is CBNodeCorticalArea:
		var area: AbstractCorticalArea = (node as CBNodeCorticalArea).representing_cortical_area
		if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE:
			var label := _core_io_label(area)
			if is_input_column and label == "power":
				return -100
			if (not is_input_column) and label == "fatigue":
				return -100
			if (not is_input_column) and label == "death":
				return -90
	return 0

func _classify_cortical_io_side(area: AbstractCorticalArea) -> String:
	var area_id_lower := String(area.cortical_ID).to_lower()
	var area_name_lower := String(area.friendly_name).to_lower()
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
		return "left"
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
		return "right"
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE:
		var core_label := _core_io_label(area)
		if core_label == "power":
			return "left"
		if core_label in ["fatigue", "death"]:
			return "right"
		if area_id_lower.begins_with("i") or area_name_lower.contains("input") or area_name_lower.contains("ipu"):
			return "left"
		if area_id_lower.begins_with("o") or area_name_lower.contains("output") or area_name_lower.contains("opu"):
			return "right"
		return "right"
	if area_id_lower.begins_with("i"):
		return "left"
	if area_id_lower.begins_with("o"):
		return "right"
	return "middle"

func _core_io_label(area: AbstractCorticalArea) -> String:
	var area_id_lower := String(area.cortical_ID).to_lower()
	var area_name_lower := String(area.friendly_name).to_lower()
	if area_id_lower.contains("pwr") or area_name_lower.contains("power"):
		return "power"
	if area_name_lower.contains("fatigue"):
		return "fatigue"
	if area_name_lower.contains("death"):
		return "death"
	return "other"

func _set_node_column_x(layout_positions: Dictionary, node: GraphElement, target_x: float) -> void:
	var new_position := Vector2(target_x, node.position_offset.y)
	if layout_positions.has(node):
		new_position.y = (layout_positions[node] as Vector2).y
	layout_positions[node] = new_position

func _collect_region_io_nodes() -> Array[CBAbstractNode]:
	var nodes: Array[CBAbstractNode] = []
	for child in get_children():
		if child is CBRegionIONode or child is CBNodeRegionIO:
			nodes.append(child)
	return nodes

func _is_region_io_input(node: Node) -> bool:
	if node is CBRegionIONode:
		return (node as CBRegionIONode)._is_region_input
	if node is CBNodeRegionIO:
		return (node as CBNodeRegionIO)._is_input
	return false

func _log_relayout_debug(layout_positions: Dictionary) -> void:
	var inputs: Array[String] = []
	var outputs: Array[String] = []
	var middle: Array[String] = []
	var inner_inputs: Array[String] = []
	var inner_outputs: Array[String] = []
	var all_nodes: Array[CBNodeConnectableBase] = []
	all_nodes.assign(_cortical_nodes.values())
	for region_node in _subregion_nodes.values():
		all_nodes.append(region_node)
	var region_io_nodes: Array[CBAbstractNode] = _collect_region_io_nodes()
	for node in all_nodes:
		var entry := _format_relayout_entry(node, layout_positions)
		if node is CBNodeCorticalArea:
			var area: AbstractCorticalArea = (node as CBNodeCorticalArea).representing_cortical_area
			var area_id_lower := String(area.cortical_ID).to_lower()
			if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU or area_id_lower.begins_with("i"):
				inputs.append(entry)
			elif area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU or area_id_lower.begins_with("o"):
				outputs.append(entry)
			else:
				middle.append(entry)
		else:
			middle.append(entry)
	for io_node in region_io_nodes:
		var io_entry := _format_relayout_entry(io_node, layout_positions)
		if _is_region_io_input(io_node):
			inner_inputs.append(io_entry)
		else:
			inner_outputs.append(io_entry)
	var log_entry := {
		"relayout": "complete",
		"region": _representing_region.region_ID if _representing_region != null else "unknown",
		"columns": {
			"inputs_left": inputs,
			"inputs_inner": inner_inputs,
			"intermediate": middle,
			"outputs_inner": inner_outputs,
			"outputs_right": outputs
		}
	}
	print("CB_RELAYOUT_DEBUG: %s" % JSON.stringify(log_entry))

func _format_relayout_entry(node: GraphElement, layout_positions: Dictionary) -> String:
	var pos: Vector2 = layout_positions.get(node, node.position_offset)
	if node is CBNodeCorticalArea:
		var area: AbstractCorticalArea = (node as CBNodeCorticalArea).representing_cortical_area
		var type_label: String = _cortical_type_to_label(area.cortical_type)
		return "%s|%s|%s|%s" % [
			String(area.cortical_ID),
			type_label,
			String(area.friendly_name),
			str(pos)
		]
	if node is CBNodeRegion:
		var region: BrainRegion = (node as CBNodeRegion).representing_region
		return "REGION|%s|%s|%s" % [String(region.region_ID), String(region.friendly_name), str(pos)]
	if node is CBRegionIONode:
		var io_label := "INPUT" if _is_region_io_input(node as CBAbstractNode) else "OUTPUT"
		return "REGION_IO|%s|%s" % [io_label, str(pos)]
	if node is CBNodeRegionIO:
		var internal_label := "INPUT" if _is_region_io_input(node as CBAbstractNode) else "OUTPUT"
		return "REGION_INTERNAL_IO|%s|%s" % [internal_label, str(pos)]
	return "NODE|%s|%s" % [String(node.name), str(pos)]

func _cortical_type_to_label(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> String:
	match(cortical_type):
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			return "IPU"
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			return "OPU"
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			return "CUSTOM"
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			return "MEMORY"
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE:
			return "CORE"
		_:
			return "UNKNOWN"

func _build_target_y_map(positions: Dictionary) -> Dictionary:
	var target_map: Dictionary = {}
	for node in positions.keys():
		target_map[node] = (positions[node] as Vector2).y
	return target_map

func _compute_min_x(nodes: Array[CBNodeConnectableBase]) -> float:
	var min_x: float = nodes[0].position_offset.x
	for node in nodes:
		min_x = min(min_x, node.position_offset.x)
	return min_x

func _compute_min_y(nodes: Array[CBNodeConnectableBase]) -> float:
	var min_y: float = nodes[0].position_offset.y
	for node in nodes:
		min_y = min(min_y, node.position_offset.y)
	return min_y

func _compute_max_width(nodes: Array[CBNodeConnectableBase]) -> float:
	var max_width: float = 0.0
	for node in nodes:
		max_width = max(max_width, node.size.x)
	return max_width

func _compute_max_width_region_io(nodes: Array[CBAbstractNode]) -> float:
	var max_width: float = 0.0
	for node in nodes:
		max_width = max(max_width, node.size.x)
	return max_width

func _average(values: Array[float]) -> float:
	var total: float = 0.0
	for value in values:
		total += value
	return total / float(values.size())

## Ensure the chosen node is on top and visually emphasized.
func _bring_node_to_front_and_jiggle(node: GraphElement) -> void:
	if node == null or not is_instance_valid(node):
		return
	# Raise above overlapping nodes in the GraphEdit canvas.
	var parent_node := node.get_parent()
	if parent_node != null:
		parent_node.move_child(node, parent_node.get_child_count() - 1)
	node.z_index = 4096
	# Soft jiggle without changing graph position (avoid triggering moves).
	var original_rotation: float = node.rotation
	var original_scale: Vector2 = node.scale
	node.pivot_offset = node.size * 0.5
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "rotation", original_rotation + 0.06, 0.08)
	tween.tween_property(node, "rotation", original_rotation - 0.06, 0.08)
	tween.tween_property(node, "rotation", original_rotation, 0.08)
	tween.tween_property(node, "scale", original_scale * 1.03, 0.08)
	tween.tween_property(node, "scale", original_scale, 0.1)

func _center_on_graph_element(element: GraphElement) -> void:
	# Determine a target zoom to fit the node comfortably in the current viewport, then zoom out a bit
	var viewport_px: Vector2 = size
	var node_px: Vector2 = element.size + Vector2(64, 64) # padding margin
	var fit_zoom_x: float = viewport_px.x / max(node_px.x, 1.0)
	var fit_zoom_y: float = viewport_px.y / max(node_px.y, 1.0)
	# Zoom out aggressively so the chosen node is clearly visible within split views
	var target_zoom: float = min(fit_zoom_x, fit_zoom_y) * 0.3 # zoom out 70%
	# Clamp to GraphEdit zoom limits if available
	var min_z: float = 0.2
	var max_z: float = 2.0
	if "min_zoom" in self:
		min_z = self.min_zoom
	if "max_zoom" in self:
		max_z = self.max_zoom
	target_zoom = clamp(target_zoom, min_z, max_z)
	self.zoom = target_zoom

	# Compute node center in content units (position_offset is content units; convert size from pixels to content)
	var node_center_local: Vector2 = element.position_offset + (element.size / (2.0 * max(self.zoom, 0.0001)))

	# Convert viewport pixels to content units based on zoom
	var viewport_content_units: Vector2 = viewport_px / max(self.zoom, 0.0001)
	# Center scroll so node center is in the middle of the visible area
	scroll_offset = node_center_local - (viewport_content_units / 2.0)

func _fit_circuit_to_viewport() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if size == Vector2.ZERO:
		return
	var view_px: Vector2 = size
	if view_px == Vector2.ZERO:
		return
	var elements: Array[GraphElement] = []
	for child in get_children():
		if child is GraphElement:
			elements.append(child)
	if elements.is_empty():
		return
	var min_pos: Vector2 = elements[0].position_offset
	var max_pos: Vector2 = elements[0].position_offset + elements[0].size
	var sum_centers: Vector2 = Vector2.ZERO
	var element_count: int = 0
	for element in elements:
		min_pos.x = min(min_pos.x, element.position_offset.x)
		min_pos.y = min(min_pos.y, element.position_offset.y)
		max_pos.x = max(max_pos.x, element.position_offset.x + element.size.x)
		max_pos.y = max(max_pos.y, element.position_offset.y + element.size.y)
		sum_centers += element.position_offset + (element.size * 0.5)
		element_count += 1
	var bounds_size: Vector2 = max_pos - min_pos
	var viewport_px: Vector2 = view_px
	var padded_size: Vector2 = bounds_size + initial_fit_padding
	var fit_zoom_x: float = viewport_px.x / max(padded_size.x, 1.0)
	var fit_zoom_y: float = viewport_px.y / max(padded_size.y, 1.0)
	var target_zoom: float = min(fit_zoom_x, fit_zoom_y)
	var min_z: float = 0.2
	var max_z: float = 2.0
	if "min_zoom" in self:
		min_z = self.min_zoom
	if "max_zoom" in self:
		max_z = self.max_zoom
	target_zoom = clamp(target_zoom, min_z, max_z)
	self.zoom = target_zoom
	var bounds_center: Vector2 = min_pos + (bounds_size * 0.5)
	var average_center: Vector2 = bounds_center
	if element_count > 0:
		average_center = sum_centers / float(element_count)
	var zoom_value: float = max(self.zoom, 0.0001)
	var viewport_center_px: Vector2 = viewport_px * 0.5
	scroll_offset = (average_center * zoom_value) - viewport_center_px
	if not _initial_fit_done:
		print(
			"CB_FIT_DEBUG: avg_center=",
			average_center,
			" zoom=",
			zoom_value,
			" viewport_center_px=",
			viewport_center_px,
			" scroll_offset=",
			scroll_offset
		)

func _get_visible_global_rect(base_rect: Rect2) -> Rect2:
	var visible_rect: Rect2 = base_rect
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	visible_rect = visible_rect.intersection(viewport_rect)
	var parent_control: Control = get_parent_control()
	while parent_control != null:
		var parent_rect: Rect2 = parent_control.get_global_rect()
		visible_rect = visible_rect.intersection(parent_rect)
		parent_control = parent_control.get_parent_control()
	return visible_rect

func _global_to_local(point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * point

## Attempts initial layout fit, ignoring optional signal args.
func _attempt_initial_fit(_node: Node = null) -> void:
	if _initial_fit_done or _initial_fit_in_progress or !is_visible_in_tree():
		return
	_initial_fit_in_progress = true
	await _run_initial_fit_retries()
	_initial_fit_in_progress = false

## Try multiple frames until elements exist and size is ready.
func _run_initial_fit_retries() -> void:
	for _i in range(INITIAL_FIT_RETRY_MAX):
		if await _try_fit_once():
			_initial_fit_done = true
			return
		await get_tree().process_frame

## Returns true when we successfully fit content.
func _try_fit_once() -> bool:
	if size == Vector2.ZERO:
		return false
	var elements: Array[GraphElement] = []
	for child in get_children():
		if child is GraphElement:
			elements.append(child)
	if elements.is_empty():
		return false
	await _fit_circuit_to_viewport()
	return true

func request_initial_fit() -> void:
	_initial_fit_done = false
	call_deferred("_attempt_initial_fit")
#endregion
