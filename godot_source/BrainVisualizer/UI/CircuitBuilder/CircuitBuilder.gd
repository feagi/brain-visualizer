extends GraphEdit
class_name CircuitBuilder
## A 2D Node based representation of a specific Genome Region

@export var move_time_delay_before_update_FEAGI: float = 5.0
@export var keyboard_movement_speed: Vector2 = Vector2(1,1)
@export var keyboard_move_speed: float = 50.0
@export var initial_fit_padding: Vector2 = Vector2(128, 128)
## Built-in minimap is sized as this fraction of the CircuitBuilder size.
@export var minimap_size_ratio: Vector2 = Vector2(0.20, 0.20)
## Minimum minimap size so it stays usable when the CircuitBuilder is small.
@export var minimap_min_size: Vector2 = Vector2(120, 90)

const PREFAB_NODE_CORTICALAREA: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeCorticalArea/CBNodeCorticalArea.tscn")
const PREFAB_NODE_BRAINREGION: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeBrainRegion/CBNodeRegion.tscn")
const PREFAB_NODE_CLASSIFIER: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeClassifier/CBNodeClassifier.tscn")
const PREFAB_NODE_REGIONIO: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBRegionIONode/CBRegionIONode.tscn")
const PREFAB_NODE_TERMINAL: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBNodeTerminal/CBNodeTerminal.tscn")#WARNING DELETE ME
const PREFAB_ENDPOINT: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBLineEndpoint/CBLineEndPoint.tscn")
const PREFAB_NODE_PORT: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CBLine/CBLineInterTerminal.tscn")
const LAYOUT_COLUMN_GAP: float = 480.0
const LAYOUT_ROW_GAP: float = 48.0
## Horizontal spacing between hierarchical layers inside the interconnect (middle) zone.
const LAYOUT_MIDDLE_LAYER_GAP: float = 480.0
## Duration of the modulate-only focus flash when centering from the combo (no transform; wires stay aligned).
const FOCUS_FLASH_DURATION_S: float = 1.0

var representing_region: BrainRegion:
	get: return _representing_region
var cortical_nodes: Dictionary:## All cortical nodes on CB, key'd by their cortical ID 
	get: return  _cortical_nodes 
var subregion_nodes: Dictionary: ## All subregion nodes on CB, key'd by their region ID
	get: return _subregion_nodes
var classifier_nodes: Dictionary: ## Classifier assembly nodes, key'd by classifier ID
	get: return _classifier_nodes

var _cortical_nodes: Dictionary = {}
var _subregion_nodes: Dictionary = {}
var _classifier_nodes: Dictionary = {}
var _classifier_twin_visual_ids: Dictionary = {}
var _representing_region: BrainRegion
var _move_timer: Timer
var _moved_genome_objects_buffer: Dictionary = {} # Key'd by object ref, value is new vector2 position
## First 2D coordinate of each object in the current drag flush. Captured before FEAGI accepts the move.
var _move_origin_2d: Dictionary = {}
## Model coordinates at the start of a multi-relocate gesture.
var _multi_relocate_model_starts: Dictionary = {}
var _move_flush_pending: bool = false
var _multi_relocate_active: bool = false
var _multi_relocate_anchor_mouse: Vector2 = Vector2.ZERO
var _multi_relocate_node_start_positions: Dictionary = {}
var _multi_relocate_nodes: Array[CBNodeConnectableBase] = []
var _suppress_move_buffer: bool = false
## True while [setup] is populating nodes/links so we do not run auto hierarchical layout (preserves saved 2D coords).
var _cb_setup_in_progress: bool = false
## Coalesces deferred auto-layout runs when multiple topology events occur in one frame.
var _auto_layout_scheduled_id: int = 0
var _initial_fit_done: bool = false
var _initial_fit_in_progress: bool = false
const INITIAL_FIT_RETRY_MAX: int = 12
const META_CB_GRAPH_TEARDOWN_SCHEDULED: StringName = &"_cb_graph_teardown_scheduled"

var _mouse_clicked_background: bool = false
var _mouse_clicked_prev_position: Vector2
var _combo: BrainObjectsCombo = null
## Prevents duplicate CBLine / terminals for the same ConnectionChainLink (phantom overlapping connections).
var _active_connection_link_render_ids: Dictionary = {}

## Hosted [UITabContainer] owns the styled tooltip overlay used by region description hover.
func get_custom_tooltip_manager() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("get_custom_tooltip_manager") and current != self:
			var manager: Node = current.get_custom_tooltip_manager()
			if manager != null:
				return manager
		current = current.get_parent()
	return null


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
	resized.connect(_update_minimap_size_from_ratio)
	child_entered_tree.connect(_attempt_initial_fit)
	_update_minimap_size_from_ratio()
	if has_node("BrainObjectsCombo"):
		_combo = $BrainObjectsCombo
		if _representing_region != null:
			_combo.set_2d_context(self, _representing_region)
		_sync_tab_menu_visibility()
	set_process(is_visible_in_tree())

func _notification(what: int) -> void:
	if what != NOTIFICATION_VISIBILITY_CHANGED:
		return
	set_process(is_visible_in_tree())
	_sync_tab_menu_visibility()
	if is_visible_in_tree():
		request_initial_fit()


## Show this tab's menu only while the pointer is on this Circuit Builder.
func _process(_delta: float) -> void:
	_sync_tab_menu_visibility()


## Hide the strip when the pointer leaves. Keep it while a menu from the strip is open.
func _sync_tab_menu_visibility() -> void:
	if _combo == null or not is_instance_valid(_combo):
		return
	_combo.sync_tab_strip_visibility(_pointer_inside_this_tab())


func _pointer_inside_this_tab() -> bool:
	if not is_visible_in_tree():
		return false
	return get_global_rect().has_point(get_global_mouse_position())



## Binds this GraphEdit to region and spawns graph nodes/lines. Call only after this node is in the
## scene tree so GraphEdit internal _connection_layer is in-tree when GraphElements are added (Godot 4.5
## skips item_rect_changed wiring otherwise, causing disconnect errors on removal).
func setup(region: BrainRegion) -> void:
	_cb_setup_in_progress = true
	_representing_region = region
	_initial_fit_done = false
	if _combo:
		_combo.set_2d_context(self, _representing_region)
	
	for area: AbstractCorticalArea in _representing_region.contained_cortical_areas:
		_CACHE_add_cortical_area(area)
	
	for subregion: BrainRegion in _representing_region.contained_regions:
		_CACHE_add_subregion(subregion)

	for classifier: GenomeClassifier in _representing_region.contained_classifiers:
		_CACHE_add_classifier(classifier)
	for classifier: GenomeClassifier in _representing_region.contained_classifiers:
		_CACHE_add_classifier_twin_visual(classifier)
	
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
	
	if not region.friendly_name_updated.is_connected(_CACHE_this_region_name_update):
		region.friendly_name_updated.connect(_CACHE_this_region_name_update)
	if not region.cortical_area_added_to_region.is_connected(_CACHE_add_cortical_area):
		region.cortical_area_added_to_region.connect(_CACHE_add_cortical_area)
	if not region.cortical_area_removed_from_region.is_connected(_CACHE_remove_cortical_area):
		region.cortical_area_removed_from_region.connect(_CACHE_remove_cortical_area)
	if not region.subregion_added_to_region.is_connected(_CACHE_add_subregion):
		region.subregion_added_to_region.connect(_CACHE_add_subregion)
	if not region.subregion_removed_from_region.is_connected(_CACHE_remove_subregion):
		region.subregion_removed_from_region.connect(_CACHE_remove_subregion)
	if not region.classifier_added_to_region.is_connected(_CACHE_add_classifier):
		region.classifier_added_to_region.connect(_CACHE_add_classifier)
	if not region.classifier_removed_from_region.is_connected(_CACHE_remove_classifier):
		region.classifier_removed_from_region.connect(_CACHE_remove_classifier)
	if not region.bridge_link_added.is_connected(_CACHE_link_bridge_added):
		region.bridge_link_added.connect(_CACHE_link_bridge_added)
	if not region.input_link_added.is_connected(_CACHE_link_parent_input_added):
		region.input_link_added.connect(_CACHE_link_parent_input_added)
	if not region.output_link_added.is_connected(_CACHE_link_parent_output_added):
		region.output_link_added.connect(_CACHE_link_parent_output_added)
	if not region.input_open_link_added.is_connected(_CACHE_link_region_input_open_added):
		region.input_open_link_added.connect(_CACHE_link_region_input_open_added)
	if not region.output_open_link_added.is_connected(_CACHE_link_region_output_open_added):
		region.output_open_link_added.connect(_CACHE_link_region_output_open_added)
	_cb_setup_in_progress = false
	call_deferred("_attempt_initial_fit")
	

## Registers a single graph representation per [ConnectionChainLink]. Without this, duplicate handler
## invocations (e.g. signal connected twice) spawn overlapping lines and extra ports ("phantom" connections).
func _try_begin_connection_link_visual(link: ConnectionChainLink) -> bool:
	var link_id: int = link.get_instance_id()
	if _active_connection_link_render_ids.has(link_id):
		return false
	_active_connection_link_render_ids[link_id] = true
	link.about_to_be_removed.connect(_on_connection_chain_link_visual_cleared.bind(link_id))
	return true

func _on_connection_chain_link_visual_cleared(link_id: int) -> void:
	_active_connection_link_render_ids.erase(link_id)

#region Responses to Cache Signals

## Twin is a standard interconnect node with a visual edge from the classifier.
func ensure_classifier_twin_visuals(classifier: GenomeClassifier) -> void:
	if classifier == null:
		return
	strip_hidden_classifier_areas()
	if not classifier.classifier_id in _classifier_nodes.keys():
		_CACHE_add_classifier(classifier)
	_CACHE_add_classifier_twin_visual(classifier)


func _CACHE_add_classifier_twin_visual(classifier: GenomeClassifier) -> void:
	if classifier == null:
		return
	for twin in classifier.get_visible_output_areas():
		_CACHE_add_one_classifier_twin_visual(classifier, twin)


func _CACHE_add_one_classifier_twin_visual(classifier: GenomeClassifier, twin: AbstractCorticalArea) -> void:
	if twin == null or GenomeClassifier.should_hide_area_in_circuit_builder(twin):
		return
	if not twin.cortical_ID in _cortical_nodes.keys():
		_CACHE_add_cortical_area(twin)
	if twin.cortical_ID in _classifier_twin_visual_ids:
		return
	if not classifier.classifier_id in _classifier_nodes.keys():
		return
	if not twin.cortical_ID in _cortical_nodes.keys():
		return
	var source_node: CBNodeConnectableBase = _classifier_nodes[classifier.classifier_id]
	var destination_node: CBNodeConnectableBase = _cortical_nodes[twin.cortical_ID]
	var source_terminal: CBNodeTerminal = source_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.OUTPUT, destination_node.title, PREFAB_NODE_TERMINAL)
	var destination_terminal: CBNodeTerminal = destination_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.INPUT, source_node.title, PREFAB_NODE_TERMINAL)
	if source_terminal == null or destination_terminal == null:
		return
	var line: CBLineInterTerminal = PREFAB_NODE_PORT.instantiate()
	add_child(line)
	move_child(line, 0)
	line.call_deferred("setup_visual_alias", source_terminal.active_port, destination_terminal.active_port)
	_classifier_twin_visual_ids[twin.cortical_ID] = true


func strip_hidden_classifier_areas() -> void:
	var stale_ids: Array[StringName] = []
	for cortical_id in _cortical_nodes.keys():
		var node: CBNodeCorticalArea = _cortical_nodes[cortical_id]
		if node == null or not is_instance_valid(node):
			stale_ids.append(cortical_id)
			continue
		var area: AbstractCorticalArea = node.representing_cortical_area
		if area != null and GenomeClassifier.should_hide_area_in_circuit_builder(area):
			stale_ids.append(cortical_id)
	for cortical_id in stale_ids:
		var node: CBNodeCorticalArea = _cortical_nodes.get(cortical_id, null)
		if node != null and is_instance_valid(node) and node.representing_cortical_area != null:
			_CACHE_remove_cortical_area(node.representing_cortical_area)
		else:
			_cortical_nodes.erase(cortical_id)


func _CACHE_add_cortical_area(area: AbstractCorticalArea) -> void:
	if area != null and GenomeClassifier.should_hide_area_in_circuit_builder(area):
		if area.cortical_ID in cortical_nodes.keys():
			_CACHE_remove_cortical_area(area)
		return
	if (area.cortical_ID in cortical_nodes.keys()):
		push_warning("UI CB: Cortical area %s node already exists; skipping duplicate add (can occur during FEAGI restart/cache resync)." % area.cortical_ID)
		return
	var cortical_node: CBNodeCorticalArea = PREFAB_NODE_CORTICALAREA.instantiate()
	_cortical_nodes[area.cortical_ID] = cortical_node
	add_child(cortical_node)
	cortical_node.setup(area)
	cortical_node.node_moved.connect(_genome_object_moved)
	if FeagiCore != null and FeagiCore.feagi_local_cache != null:
		var owner: GenomeClassifier = FeagiCore.feagi_local_cache.get_classifier_owning_area(area.cortical_ID)
		if owner != null and (owner.is_class_output_id(area.cortical_ID) or owner.is_answer_area_id(area.cortical_ID)):
			_CACHE_add_classifier_twin_visual(owner)
	if not _cb_setup_in_progress:
		_request_auto_layout_after_topology_change()

func _CACHE_remove_cortical_area(area: AbstractCorticalArea) -> void:
	if !(area.cortical_ID in cortical_nodes.keys()):
		push_error("UI CB: Unable to find cortical area %s to remove node of!" % area.cortical_ID)
		return
	BV.UI.selection_system.clear_all_highlighted()
	var node: CBNodeCorticalArea = _cortical_nodes[area.cortical_ID]
	_cortical_nodes.erase(area.cortical_ID)
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		_schedule_graph_node_removal(node)

func _CACHE_add_classifier(classifier: GenomeClassifier) -> void:
	if classifier == null:
		return
	if classifier.classifier_id in _classifier_nodes.keys():
		push_warning("UI CB: Classifier %s node already exists; skipping duplicate add." % classifier.classifier_id)
		return
	var classifier_node: CBNodeClassifier = PREFAB_NODE_CLASSIFIER.instantiate()
	_classifier_nodes[classifier.classifier_id] = classifier_node
	add_child(classifier_node)
	classifier_node.setup(classifier)
	classifier_node.node_moved.connect(_genome_object_moved)
	_CACHE_add_classifier_twin_visual(classifier)
	if not _cb_setup_in_progress:
		_request_auto_layout_after_topology_change()

func _CACHE_remove_classifier(classifier: GenomeClassifier) -> void:
	if classifier == null:
		return
	if !(classifier.classifier_id in _classifier_nodes.keys()):
		push_error("UI CB: Unable to find classifier %s to remove node of!" % classifier.classifier_id)
		return
	BV.UI.selection_system.clear_all_highlighted()
	for twin_id in classifier.class_output_ids():
		_classifier_twin_visual_ids.erase(twin_id)
	_classifier_twin_visual_ids.erase(classifier.error_area_id)
	_classifier_twin_visual_ids.erase(classifier.correct_area_id)
	var node: CBNodeClassifier = _classifier_nodes[classifier.classifier_id]
	_classifier_nodes.erase(classifier.classifier_id)
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		_schedule_graph_node_removal(node)
	
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
	if not _cb_setup_in_progress:
		_request_auto_layout_after_topology_change()

func _CACHE_remove_subregion(subregion: BrainRegion) -> void:
	if !(subregion.region_ID in subregion_nodes.keys()):
		push_error("UI CB: Unable to find region %s to remove node of!" % subregion.region_ID)
		return
	BV.UI.selection_system.clear_all_highlighted()
	#NOTE: We assume that all connections to / from this region have already been called to beremoved by the cache FIRST
	var node: CBNodeRegion = subregion_nodes[subregion.region_ID]
	subregion_nodes.erase(subregion.region_ID)
	if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
		_schedule_graph_node_removal(node)

## The name of the region this instance of CB has changed. Updating the Node name causes the tab name to update too
func _CACHE_this_region_name_update(new_name: StringName) -> void:
	name = new_name

func _CACHE_link_bridge_added(link: ConnectionChainLink) -> void:
	if link.parent_region != representing_region:
		return
	# Match parent input/output handlers: do not draw bridge lines or terminals when the mapping
	# set has no rules (count 0). Otherwise CB shows phantom ports/lines until BV restart.
	if link.parent_chain != null and link.parent_chain.is_registered_to_established_mapping_set() and link.parent_chain.mapping_set != null and link.parent_chain.mapping_set.number_mappings == 0:
		return
	if link.parent_chain != null and link.parent_chain.is_registered_to_partial_mapping_set() and link.parent_chain.partial_mapping_set != null and link.parent_chain.partial_mapping_set.number_mappings == 0:
		return
	if _is_hidden_classifier_internal_mapping(link.source, link.destination):
		return
	var source_node: CBNodeConnectableBase = _get_associated_connectable_graph_node(link.source)
	var destination_node: CBNodeConnectableBase = _get_associated_connectable_graph_node(link.destination)

	if (source_node == null) or (destination_node == null):
		push_error("UI CB: Failed to add link in CB of region %s" % _representing_region.region_ID)
		return

	if not _try_begin_connection_link_visual(link):
		push_warning("UI CB: Skipping duplicate graph render for same ConnectionChainLink (bridge).")
		return

	if source_node == destination_node:
		#This is a recursive connection
		source_node.CB_add_connection_terminal(CBNodeTerminal.TYPE.RECURSIVE, source_node.title, PREFAB_NODE_TERMINAL)
		if not _cb_setup_in_progress:
			_request_auto_layout_after_topology_change()
		return
	
	var source_title: StringName
	var destination_title: StringName
	if link.parent_chain.is_registered_to_established_mapping_set():
		source_title = source_node.title
		destination_title = destination_node.title
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
	if not _cb_setup_in_progress:
		_request_auto_layout_after_topology_change()

func _CACHE_link_parent_input_added(link: ConnectionChainLink) -> void:
	if _representing_region != null and _representing_region.is_root_region():
		return
	if link.parent_region != representing_region:
		return
	if link.parent_chain != null and link.parent_chain.is_registered_to_established_mapping_set() and link.parent_chain.mapping_set != null and link.parent_chain.mapping_set.number_mappings == 0:
		return
	if link.parent_chain != null and link.parent_chain.is_registered_to_partial_mapping_set() and link.parent_chain.partial_mapping_set != null and link.parent_chain.partial_mapping_set.number_mappings == 0:
		return
	var destination_node: CBNodeConnectableBase = _get_associated_connectable_graph_node(link.destination)
	
	if destination_node == null:
		push_error("UI CB: Failed to add link in CB of region %s" % _representing_region.region_ID)
		return

	if not _try_begin_connection_link_visual(link):
		push_warning("UI CB: Skipping duplicate graph render for same ConnectionChainLink (parent input).")
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
	if link.parent_chain != null and link.parent_chain.is_registered_to_established_mapping_set() and link.parent_chain.mapping_set != null and link.parent_chain.mapping_set.number_mappings == 0:
		return
	if link.parent_chain != null and link.parent_chain.is_registered_to_partial_mapping_set() and link.parent_chain.partial_mapping_set != null and link.parent_chain.partial_mapping_set.number_mappings == 0:
		return
	var source_node: CBNodeConnectableBase = _get_associated_connectable_graph_node(link.source)
	
	if source_node == null:
		push_error("UI CB: Failed to add link in CB of region %s" % _representing_region.region_ID)
		return

	if not _try_begin_connection_link_visual(link):
		push_warning("UI CB: Skipping duplicate graph render for same ConnectionChainLink (parent output).")
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
	if link.parent_chain != null and link.parent_chain.is_registered_to_partial_mapping_set():
		var partial_mapping := link.parent_chain.partial_mapping_set
		if partial_mapping != null and partial_mapping.number_mappings == 0:
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
	if link.parent_chain != null and link.parent_chain.is_registered_to_partial_mapping_set():
		var partial_mapping := link.parent_chain.partial_mapping_set
		if partial_mapping != null and partial_mapping.number_mappings == 0:
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
	if element is CBNodeClassifier:
		print("CB Selected " + (element as CBNodeClassifier).representing_classifier.friendly_name)
		BV.UI.selection_system.add_to_highlighted((element as CBNodeClassifier).representing_classifier)
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
	if element is CBNodeClassifier:
		print("CB Deselected " + (element as CBNodeClassifier).representing_classifier.friendly_name)
		BV.UI.selection_system.remove_from_highlighted((element as CBNodeClassifier).representing_classifier)
		return

## Ensure only the provided element remains selected in GraphEdit.
func _select_single_graph_element(element: GraphElement) -> void:
	for node in get_children():
		if node is GraphElement and node != element:
			(node as GraphElement).selected = false
	if element != null:
		element.selected = true

func _user_double_clicked_region(region_node: CBNodeRegion) -> void:
	var region: BrainRegion = region_node.representing_region
	if GenomeClassifier.region_hides_interior(region):
		BV.NOTIF.add_notification(GenomeClassifier.INTEGRATED_CIRCUIT_INTERNALS_TOOLTIP)
		return
	BV.UI.selection_system.clear_all_highlighted()
	user_request_viewing_subregion.emit(region)

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

	var destination_classifier: GenomeClassifier = FeagiCore.feagi_local_cache.classifiers.get(to_node, null) as GenomeClassifier
	if destination_classifier != null and source is AbstractCorticalArea:
		var quick_connect: WindowQuickConnect = BV.UI.window_manager.spawn_quick_connect(source as AbstractCorticalArea)
		if quick_connect != null:
			quick_connect.offer_classifier_destination(destination_classifier)
		return
	if source is GenomeClassifier or destination is GenomeClassifier:
		return
	if from_node in FeagiCore.feagi_local_cache.classifiers or to_node in FeagiCore.feagi_local_cache.classifiers:
		return

	BV.UI.window_manager.spawn_mapping_editor(source, destination)


#endregion

#region multi-select







#endregion

#region Internals

## GraphEdit wires GraphElement/GraphNode internals (e.g. item_rect_changed -> connections_layer /
## minimap queue_redraw). Use this for any direct GraphEdit child that is a [GraphElement].
func schedule_graph_element_removal(node: Node) -> void:
	_schedule_graph_node_removal(node)


## GraphEdit wires GraphElement/GraphNode internals (e.g. item_rect_changed -> queue_redraw). Calling
## remove_child on GraphEdit (Godot 4.5+) can trigger "disconnect nonexistent" in engine cleanup.
## Deferred path: clear selection, ensure expected item_rect_changed hooks exist, then queue_free.
func _schedule_graph_node_removal(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if node.get_meta(META_CB_GRAPH_TEARDOWN_SCHEDULED, false):
		return
	node.set_meta(META_CB_GRAPH_TEARDOWN_SCHEDULED, true)
	call_deferred("_deferred_remove_graph_child", node)


func _deferred_remove_graph_child(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if node is GraphElement:
		(node as GraphElement).selected = false
	node.queue_free()


## Every time a cortical node moves, store and send it when time is ready
func _genome_object_moved(node: CBNodeConnectableBase, new_position: Vector2i) -> void:
	if _suppress_move_buffer:
		return
	var genome_object: GenomeObject 
	if node is CBNodeCorticalArea:
		genome_object = (node as CBNodeCorticalArea).representing_cortical_area
	elif node is CBNodeRegion:
		genome_object = (node as CBNodeRegion).representing_region
	elif node is CBNodeClassifier:
		var classifier: GenomeClassifier = (node as CBNodeClassifier).representing_classifier
		classifier.FEAGI_change_coordinates_2D(new_position)
		var stamp: AbstractCorticalArea = classifier.get_stamp_area()
		if stamp == null:
			return
		genome_object = stamp
	else:
		return
	print("Buffering change in position of genome object ")
	if not _move_origin_2d.has(genome_object):
		_move_origin_2d[genome_object] = genome_object.coordinates_2D
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
	var position_edit := _position_edit_for_2d_payload("Move", payload, _move_origin_2d)
	for genome_object in payload.keys():
		_move_origin_2d.erase(genome_object)
	print("Sending change of 2D positions for %d objects(s)" % len(payload.keys()))
	var result: FeagiRequestOutput = await FeagiCore.requests.mass_move_genome_objects_2D(payload)
	if result.has_errored:
		print("CB_RELAYOUT_DEBUG: move save failed -> ", result.decode_response_as_generic_error_code())
		BV.NOTIF.add_notification(
			"Move failed to save positions.",
			NotificationSystemNotification.NOTIFICATION_TYPE.ERROR
		)
		return
	_record_position_edit(position_edit)
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
	_multi_relocate_model_starts.clear()
	for obj in selection:
		if obj is AbstractCorticalArea or obj is BrainRegion or obj is GenomeClassifier:
			var node = _get_associated_connectable_graph_node(obj)
			if node != null:
				_multi_relocate_nodes.append(node)
				_multi_relocate_node_start_positions[node] = node.position_offset
				var model: GenomeObject = _relocate_model_object(node)
				if model != null:
					_multi_relocate_model_starts[model] = model.coordinates_2D
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
	var relocate_origins: Dictionary = _multi_relocate_model_starts.duplicate()
	_multi_relocate_model_starts.clear()
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
	var position_edit := PositionEdit.new()
	position_edit.label = "Move"
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
		position_edit.append_2d_moves(relocate_origins, cortical_payload)
	if not region_payload.is_empty():
		print("Sending change of 2D positions for %d region(s)" % len(region_payload.keys()))
		var region_result: FeagiRequestOutput = await FeagiCore.requests.mass_move_genome_objects_2D(region_payload)
		if region_result.has_errored:
			print("CB_RELAYOUT_DEBUG: move save failed -> ", region_result.decode_response_as_generic_error_code())
			BV.NOTIF.add_notification(
				"Relocate failed to save regions.",
				NotificationSystemNotification.NOTIFICATION_TYPE.ERROR
			)
			_record_position_edit(position_edit)
			return
		position_edit.append_2d_moves(relocate_origins, region_payload)
	_record_position_edit(position_edit)
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

func _relocate_model_object(node: CBNodeConnectableBase) -> GenomeObject:
	if node is CBNodeCorticalArea:
		return (node as CBNodeCorticalArea).representing_cortical_area
	if node is CBNodeRegion:
		return (node as CBNodeRegion).representing_region
	if node is CBNodeClassifier:
		var classifier: GenomeClassifier = (node as CBNodeClassifier).representing_classifier
		if classifier == null:
			return null
		return classifier.get_stamp_area()
	return null


func _position_edit_for_2d_payload(move_label: String, destinations: Dictionary, origins: Dictionary) -> PositionEdit:
	return PositionEdit.from_2d_moves(move_label, origins, destinations)


func _record_position_edit(edit: PositionEdit) -> void:
	if BV == null or BV.UI == null:
		return
	BV.UI.record_position_edit(edit)


## Attempts to return the associated graph node for a given genome cache object. Returns null if fails
func _get_associated_connectable_graph_node(genome_object: GenomeObject) -> CBNodeConnectableBase:
	var resolved: GenomeObject = _resolve_visual_connectable(genome_object)
	if resolved is GenomeClassifier:
		var classifier: GenomeClassifier = resolved as GenomeClassifier
		if !(classifier.classifier_id in _classifier_nodes.keys()):
			push_error("UI CB: Unable to find classifier %s node in CB for region %s" % [classifier.classifier_id, _representing_region.region_ID])
			return null
		return _classifier_nodes[classifier.classifier_id]
	if resolved is AbstractCorticalArea:
		if !((resolved as AbstractCorticalArea).cortical_ID in _cortical_nodes.keys()):
			push_error("UI CB: Unable to find area %s node in CB for region %s" % [(resolved as AbstractCorticalArea).cortical_ID, _representing_region.region_ID])
			return null
		return _cortical_nodes[(resolved as AbstractCorticalArea).cortical_ID]
	if resolved is BrainRegion:
		if !((resolved as BrainRegion).region_ID in _subregion_nodes.keys()):
			push_error("UI CB: Unable to find region %s node in CB for region %s" % [(resolved as BrainRegion).region_ID, _representing_region.region_ID])
			return null
		return _subregion_nodes[(resolved as BrainRegion).region_ID]
	return null


func _resolve_visual_connectable(genome_object: GenomeObject) -> GenomeObject:
	if FeagiCore == null or FeagiCore.feagi_local_cache == null:
		return genome_object
	return FeagiCore.feagi_local_cache.resolve_visual_connectable(genome_object)


func _is_hidden_classifier_internal_mapping(source: GenomeObject, destination: GenomeObject) -> bool:
	if FeagiCore == null or FeagiCore.feagi_local_cache == null:
		return false
	return GenomeClassifier.is_internal_only_classifier_mapping(source, destination, FeagiCore.feagi_local_cache.classifiers)

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
	_deferred_center_and_emphasize(node)

func focus_on_cortical_area(area: AbstractCorticalArea) -> void:
	var node: CBNodeConnectableBase = _get_associated_connectable_graph_node(area)
	if node == null:
		return
	_deferred_center_and_emphasize(node)

func focus_on_classifier(classifier: GenomeClassifier) -> void:
	var node: CBNodeConnectableBase = _get_associated_connectable_graph_node(classifier)
	if node == null:
		return
	_deferred_center_and_emphasize(node)


func _deferred_center_and_emphasize(node: CBNodeConnectableBase) -> void:
	## GraphEdit [member size] can be zero when the combo callback runs before layout; defer one frame.
	if size == Vector2.ZERO:
		await get_tree().process_frame
	if not is_instance_valid(node):
		return
	_center_on_graph_element(node)
	_bring_node_to_front_and_flash(node)

## Rearrange nodes: inputs left, outputs right; interconnect in layered columns by bridge direction
## (downstream right); cycles share a layer via SCC + longest path on the component DAG.
func relayout_nodes() -> void:
	await apply_hierarchical_layout(true)


## Applies hierarchical layout to all graph nodes and persists 2D positions to FEAGI when [param show_success_notification] is used for the manual rearrange action; auto-layout passes false to avoid toasts.
func apply_hierarchical_layout(show_success_notification: bool = true) -> void:
	var layout_positions: Dictionary = _compute_relayout_positions()
	if layout_positions.is_empty():
		return
	if show_success_notification:
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
	if update_payload.is_empty():
		return
	var layout_origins: Dictionary = {}
	for genome_object in update_payload.keys():
		if genome_object is GenomeObject:
			layout_origins[genome_object] = (genome_object as GenomeObject).coordinates_2D
	var position_edit := PositionEdit.from_2d_moves("Arrange", layout_origins, update_payload)
	print("CB_RELAYOUT_DEBUG: saving %d objects to FEAGI" % update_payload.size())
	var result: FeagiRequestOutput = await FeagiCore.requests.mass_move_genome_objects_2D(update_payload)
	if result.has_errored:
		print("CB_RELAYOUT_DEBUG: save failed -> ", result.decode_response_as_generic_error_code())
		BV.NOTIF.add_notification(
			"Auto-arrange failed to save positions.",
			NotificationSystemNotification.NOTIFICATION_TYPE.ERROR
		)
		return
	_record_position_edit(position_edit)
	print("CB_RELAYOUT_DEBUG: saving genome after relayout")
	var save_result: FeagiRequestOutput = await FeagiCore.requests.save_genome()
	if save_result.has_errored:
		print("CB_RELAYOUT_DEBUG: genome save failed -> ", save_result.decode_response_as_generic_error_code())
		BV.NOTIF.add_notification(
			"Auto-arrange saved positions but failed to save genome.",
			NotificationSystemNotification.NOTIFICATION_TYPE.WARNING
		)
		return
	if show_success_notification:
		BV.NOTIF.add_notification(
			"Auto-arrange saved positions to genome.",
			NotificationSystemNotification.NOTIFICATION_TYPE.INFO
		)


func _request_auto_layout_after_topology_change() -> void:
	if not is_inside_tree():
		return
	_auto_layout_scheduled_id += 1
	var run_id: int = _auto_layout_scheduled_id
	call_deferred("_run_auto_layout_deferred", run_id)


func _run_auto_layout_deferred(run_id: int) -> void:
	if run_id != _auto_layout_scheduled_id:
		return
	await get_tree().process_frame
	if run_id != _auto_layout_scheduled_id:
		return
	await apply_hierarchical_layout(false)

## Compute layout positions with [LayeredGraphLayout]: IPU/OPU fixed columns, region IO in the inner
## columns, interconnect in directed-bridge SCC layers (longest path on the condensation DAG) for
## increasing X, barycenter Y within each layer. Returns graph node -> Vector2.
func _compute_relayout_positions() -> Dictionary:
	var items: Array = []
	for node: CBNodeConnectableBase in _cortical_nodes.values():
		items.append(_layout_item(node))
	for node: CBNodeConnectableBase in _subregion_nodes.values():
		items.append(_layout_item(node))
	for node: CBNodeConnectableBase in _classifier_nodes.values():
		items.append(_layout_item(node))
	for io_node: CBAbstractNode in _collect_region_io_nodes():
		var io_column: LayeredGraphLayout.COLUMN = LayeredGraphLayout.COLUMN.INNER_INPUT if _is_region_io_input(io_node) else LayeredGraphLayout.COLUMN.INNER_OUTPUT
		items.append({"key": io_node, "size": io_node.size, "position": io_node.position_offset, "column": io_column})
	return LayeredGraphLayout.compute(items, _build_bridge_edges(), LAYOUT_COLUMN_GAP, LAYOUT_ROW_GAP, LAYOUT_MIDDLE_LAYER_GAP)


func _layout_item(node: CBNodeConnectableBase) -> Dictionary:
	var column: LayeredGraphLayout.COLUMN = LayeredGraphLayout.COLUMN.MIDDLE
	var priority: int = 0
	if node is CBNodeCorticalArea:
		var area: AbstractCorticalArea = (node as CBNodeCorticalArea).representing_cortical_area
		column = CorticalLayoutSide.layout_column(area)
		if column != LayeredGraphLayout.COLUMN.MIDDLE:
			priority = CorticalLayoutSide.io_priority(area, column == LayeredGraphLayout.COLUMN.INPUT)
	return {"key": node, "size": node.size, "position": node.position_offset, "column": column, "priority": priority}


## Directed bridge edges between this region's graph nodes, in link order (FEAGI direction: source -> destination).
func _build_bridge_edges() -> Array:
	var edges: Array = []
	if _representing_region == null:
		return edges
	for link: ConnectionChainLink in _representing_region.bridge_chain_links:
		if _is_hidden_classifier_internal_mapping(link.source, link.destination):
			continue
		var source_node: CBNodeConnectableBase = _node_for_genome_object(link.source)
		var destination_node: CBNodeConnectableBase = _node_for_genome_object(link.destination)
		if source_node == null or destination_node == null:
			continue
		edges.append([source_node, destination_node])
	return edges


func _node_for_genome_object(obj: GenomeObject) -> CBNodeConnectableBase:
	var resolved: GenomeObject = _resolve_visual_connectable(obj)
	if resolved is AbstractCorticalArea:
		return _cortical_nodes.get((resolved as AbstractCorticalArea).cortical_ID, null)
	if resolved is BrainRegion:
		return _subregion_nodes.get((resolved as BrainRegion).region_ID, null)
	if resolved is GenomeClassifier:
		return _classifier_nodes.get((resolved as GenomeClassifier).classifier_id, null)
	return null

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
	for classifier_node in _classifier_nodes.values():
		all_nodes.append(classifier_node)
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
	if node is CBNodeClassifier:
		var classifier: GenomeClassifier = (node as CBNodeClassifier).representing_classifier
		return "CLASSIFIER|%s|%s|%s" % [String(classifier.classifier_id), String(classifier.friendly_name), str(pos)]
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
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MODULATOR:
			return "MODULATOR"
		_:
			return "UNKNOWN"

## Ensure the chosen node is on top and visually emphasized.
func _bring_node_to_front_and_flash(node: GraphElement) -> void:
	if node == null or not is_instance_valid(node):
		return
	# Raise above overlapping nodes in the GraphEdit canvas.
	var parent_node := node.get_parent()
	if parent_node != null:
		parent_node.move_child(node, parent_node.get_child_count() - 1)
	node.z_index = 4096
	# Do not tween rotation or scale: GraphEdit connection lines use port geometry; transforming the
	# GraphNode desyncs wires until a full redraw (e.g. pan). Brightness flash via modulate/self_modulate only.
	# A small RGB multiplier is often invisible on GraphNode's themed titlebar; lerp toward white is obvious.
	var base_m: Color = node.modulate
	var base_s: Color = node.self_modulate
	var rise_s: float = FOCUS_FLASH_DURATION_S * 0.22
	var fall_s: float = FOCUS_FLASH_DURATION_S - rise_s
	const FLASH_LERP_TO_WHITE: float = 0.88
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	var apply_lerp := func(lerp_w: float) -> void:
		if not is_instance_valid(node):
			return
		node.modulate = base_m.lerp(Color.WHITE, lerp_w)
		node.self_modulate = base_s.lerp(Color.WHITE, lerp_w)
	tween.tween_method(apply_lerp, 0.0, FLASH_LERP_TO_WHITE, rise_s)
	tween.tween_method(apply_lerp, FLASH_LERP_TO_WHITE, 0.0, fall_s)

func _center_on_graph_element(element: GraphElement) -> void:
	# Determine a target zoom to fit the node comfortably in the current viewport, then zoom out a bit
	var viewport_px: Vector2 = size
	var node_px: Vector2 = element.size + Vector2(64, 64) # padding margin
	var fit_zoom_x: float = viewport_px.x / max(node_px.x, 1.0)
	var fit_zoom_y: float = viewport_px.y / max(node_px.y, 1.0)
	# Zoom out aggressively so the chosen node is clearly visible within split views
	var target_zoom: float = min(fit_zoom_x, fit_zoom_y) * 0.3 # zoom out 70%
	# Clamp to GraphEdit zoom limits
	target_zoom = clamp(target_zoom, zoom_min, zoom_max)
	self.zoom = target_zoom

	# Match [method _fit_circuit_to_viewport]: scroll_offset is in screen pixels; center is in graph space.
	var zoom_value: float = max(self.zoom, 0.0001)
	var node_center_graph: Vector2 = element.position_offset + (element.size * 0.5)
	var viewport_center_px: Vector2 = viewport_px * 0.5
	scroll_offset = (node_center_graph * zoom_value) - viewport_center_px

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
	var target_zoom: float = min(fit_zoom_x, fit_zoom_y) * 0.5
	target_zoom = clamp(target_zoom, zoom_min, zoom_max)
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

## Sizes the built-in GraphEdit minimap to a fraction of the CircuitBuilder size,
## clamped to a usable minimum so it stays visible at small CB dimensions.
func _update_minimap_size_from_ratio() -> void:
	var ratio: Vector2 = Vector2(maxf(minimap_size_ratio.x, 0.0), maxf(minimap_size_ratio.y, 0.0))
	var target: Vector2 = size * ratio
	target.x = maxf(target.x, minimap_min_size.x)
	target.y = maxf(target.y, minimap_min_size.y)
	minimap_size = target

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
