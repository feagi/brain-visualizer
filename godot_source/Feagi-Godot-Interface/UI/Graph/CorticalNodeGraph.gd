extends GraphEdit
class_name CorticalNodeGraph

const NODE_SIZE: Vector2i = Vector2i(300, 100) ## Controls spacing betweeen nodes on intiial load

var cortical_nodes: Dictionary = {} ## All cortical nodes on CB, key'd by their ID
var connections: Dictionary = {} ## Connection lines key'd by their name function string output

@export var algorithm_cortical_area_spacing: Vector2i =  Vector2i(10,6)
@export var move_time_delay_before_update_FEAGI: float = 5.0

var _cortical_node_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/CorticalNode/CortexNode.tscn")
var intercortical_connection_prefab: PackedScene = preload("res://Feagi-Godot-Interface/UI/Graph/CorticalNode/Connection/InterCorticalConnection.tscn")
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


func set_outlining_state_of_connection(source_area: BaseCorticalArea, destination_area: BaseCorticalArea, highlighting: bool) -> void:
	var line_name: StringName = InterCorticalConnection.generate_name(source_area.cortical_ID, destination_area.cortical_ID)
	if !(line_name in connections.keys()):
		push_warning("Unable to find connection line to set outlining! Skipping!")
		return
	var line: InterCorticalConnection = connections[line_name]
	line.toggle_outlining(highlighting)

## Spawns a cortical Node, should only be called via FEAGI
func feagi_spawn_single_cortical_node(cortical_area: BaseCorticalArea) -> CorticalNode:
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
	
	return cortical_node

## Deletes a cortical Node, should only be called via FEAGI
func feagi_deleted_single_cortical_node(cortical_area: BaseCorticalArea) -> void:
	if cortical_area.cortical_ID not in cortical_nodes.keys():
		push_error("GRAPH: Attempted to remove non-existant cortex node " + cortical_area.cortical_ID + "! Skipping...")
	var node: CorticalNode = cortical_nodes[cortical_area.cortical_ID]
	node.FEAGI_delete_cortical_area()
	cortical_nodes.erase(cortical_area.cortical_ID)
	
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
	VisConfig.UI_manager.window_manager.spawn_edit_mappings(FeagiCache.cortical_areas_cache.cortical_areas[from_cortical_ID], FeagiCache.cortical_areas_cache.cortical_areas[to_cortical_ID], true)

func _on_genome_reset():
	_spawn_sorter = CorticalNodeSpawnSorter.new(algorithm_cortical_area_spacing, NODE_SIZE)
	_moved_cortical_areas_buffer = {}
	_move_timer.stop()


