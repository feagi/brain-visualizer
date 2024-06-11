extends GraphEdit
class_name CorticalNodeGraph

const NODE_SIZE: Vector2i = Vector2i(300, 100) ## Controls spacing betweeen nodes on intiial load

var cortical_nodes: Dictionary = {} ## All cortical nodes on CB, key'd by their ID
var connections: Dictionary = {} ## Connection lines key'd by their name function string output

@export var algorithm_cortical_area_spacing: Vector2i =  Vector2i(10,6)
@export var move_time_delay_before_update_FEAGI: float = 5.0
@export var initial_position: Vector2
@export var initial_zoom: float
@export var keyboard_movement_speed: Vector2 = Vector2(1,1)
@export var keyboard_move_speed: float = 50.0


var _cortical_node_prefab: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CorticalNode/CortexNode.tscn")
var intercortical_connection_prefab: PackedScene = preload("res://BrainVisualizer/UI/CircuitBuilder/CorticalNode/Connection/InterCorticalConnection.tscn")
var _spawn_sorter: CorticalNodeSpawnSorter
var _move_timer: Timer
var _moved_cortical_areas_buffer: Dictionary = {}

func _ready():
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_added.connect(feagi_spawn_single_cortical_node)
	FeagiCore.feagi_local_cache.cortical_areas.cortical_area_about_to_be_removed.connect(feagi_deleted_single_cortical_node)
	FeagiCore.genome_load_state_changed.connect(_on_genome_change_state)
	_spawn_sorter = CorticalNodeSpawnSorter.new(algorithm_cortical_area_spacing, NODE_SIZE)
	BV.UI.user_selected_single_cortical_area.connect(select_single_cortical_area)

	_move_timer = $Timer
	_move_timer.wait_time = move_time_delay_before_update_FEAGI
	_move_timer.one_shot = true
	_move_timer.timeout.connect(_move_timer_finished)

	connection_request.connect(_user_request_connection)
	scroll_offset = initial_position
	zoom = initial_zoom

func _gui_input(event):
	if !(event is InputEventKey):
		return
	
	if !has_focus():
		return
	
	var keyboard_event: InputEventKey = event as InputEventKey
	if !keyboard_event.is_pressed():
		return
	
	var dir: Vector2 = Vector2(0,0)

	if Input.is_action_pressed("forward"):
		dir += Vector2(0,-1)
	if Input.is_action_pressed("backward"):
		dir += Vector2(0,1)
	if Input.is_action_pressed("left"):
		dir += Vector2(-1,0)
	if Input.is_action_pressed("right"):
		dir += Vector2(1,0)
	
	scroll_offset += dir * zoom * keyboard_move_speed
	
	

func set_outlining_state_of_connection(source_area: AbstractCorticalArea, destination_area: AbstractCorticalArea, highlighting: bool) -> void:
	if source_area == null:
		push_error("Unable to set connection line details with a null source area! Skip[ping!]")
		return
	if destination_area == null:
		push_error("Unable to set connection line details with a null destination area! Skipping!")
		return
	
	var line_name: StringName = InterCorticalConnection.generate_name(source_area.cortical_ID, destination_area.cortical_ID)
	if !(line_name in connections.keys()):
		if source_area.cortical_ID != destination_area.cortical_ID: # If the source and destination are the same, then its a recursive connection (IE no line), so this is expected
			push_warning("Unable to find connection line to set outlining! Skipping!")
		return
	var line: InterCorticalConnection = connections[line_name]
	line.toggle_outlining(highlighting)


## highlights / selects a cortical area in CB
func select_single_cortical_area(cortical_area: AbstractCorticalArea) -> void:
	if !(cortical_area.cortical_ID in cortical_nodes.keys()):
		push_error("CB: Unable to find cortical area as a node to select!")
		return
	var cortical_node: CorticalNode = cortical_nodes[cortical_area.cortical_ID]
	set_selected(cortical_node)

func center_on_cortical_area(cortical_area: AbstractCorticalArea) -> void:
	if !(cortical_area.cortical_ID in cortical_nodes.keys()):
		push_error("CB: Unable to find cortical area as a node to focus!")
		return
	var cortical_node: CorticalNode = cortical_nodes[cortical_area.cortical_ID]
	scroll_offset = cortical_node.position_offset - (size / 2.0)

## Spawns a cortical Node, should only be called via FEAGI
func feagi_spawn_single_cortical_node(cortical_area: AbstractCorticalArea) -> CorticalNode:
	var cortical_node: CorticalNode = _cortical_node_prefab.instantiate()
	var offset: Vector2
	if cortical_area.is_coordinates_2D_available:
		offset = cortical_area.coordinates_2D
	else:
		if FeagiCore.genome_load_state == FeagiCore.GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI:
			offset = _spawn_sorter.add_cortical_area_to_memory_and_return_position(cortical_area.cortical_type)
		else:
			offset = Vector2(0.0,0.0) # TODO use center of view instead
	add_child(cortical_node)
	cortical_node.setup(cortical_area, offset)
	cortical_node.moved.connect(_cortical_node_moved)
	cortical_nodes[cortical_area.cortical_ID] = cortical_node
	
	return cortical_node

## Deletes a cortical Node, should only be called via FEAGI
func feagi_deleted_single_cortical_node(cortical_area: AbstractCorticalArea) -> void:
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
	FeagiCore.requests.mass_move_cortical_areas_2D(_moved_cortical_areas_buffer)
	_moved_cortical_areas_buffer = {}

## User requested a connection. Note that this function is going to be redone in the graph edit refactor
func _user_request_connection(from_cortical_ID: StringName, _from_port: int, to_cortical_ID: StringName, _to_port: int) -> void:
	BV.WM.spawn_mapping_editor(FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[from_cortical_ID], FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[to_cortical_ID])

func _on_genome_change_state(new_state: FeagiCore.GENOME_LOAD_STATE, _prev_state: FeagiCore.GENOME_LOAD_STATE):
	if new_state != FeagiCore.GENOME_LOAD_STATE.RELOADING_GENOME_FROM_FEAGI:
		return
	_spawn_sorter = CorticalNodeSpawnSorter.new(algorithm_cortical_area_spacing, NODE_SIZE)
	_moved_cortical_areas_buffer = {}
	_move_timer.stop()
	

