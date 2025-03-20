extends Node
class_name UI_BrainMonitor_AbstractCorticalAreaRenderer
## Base class for all rendering methods for cortical areas. Essentially just a fancy interface

#NOTE All neuron selection / mouse events go up via signals, which will then call functions here to set highlighting to ensure predictable states!

@export var cortical_area_outline_mouse_over_color: Color = Color.AQUA
@export var cortical_area_outline_mouse_over_alpha: float = 0.7
@export var cortical_area_outline_select_color: Color = Color.ALICE_BLUE
@export var cortical_area_outline_select_alpha: float = 0.8
@export var cortical_area_outline_both_color: Color = Color.WHITE_SMOKE
@export var cortical_area_outline_both_alpha: float = 0.9

func setup(area: AbstractCorticalArea) -> void:
	assert(false, "Not Implemented!")

func update_friendly_name(new_name: String) -> void:
	assert(false, "Not Implemented!")

func update_position(new_position: Vector3i) -> void:
	assert(false, "Not Implemented!")

func update_dimensions(new_dimensions: Vector3i) -> void:
	assert(false, "Not Implemented!")

func set_cortical_area_mouse_over_highlighting(is_highlighted: bool) -> void:
	assert(false, "Not Implemented!")

func set_cortical_area_selection(is_selected: bool) -> void:
	assert(false, "Not Implemented!")

func set_neuron_highlighting(neuron_coordinate: Vector3i, is_highlighted: bool) -> void:
	assert(false, "Not Implemented!")
	
func set_neuron_selection(neuron_coordinate: Vector3i, is_selected: bool) -> void:
	assert(false, "Not Implemented!")

func clear_all_neuron_highlighting() -> void:
	assert(false, "Not Implemented!")

func clear_all_neuron_selection() -> void:
	assert(false, "Not Implemented!")

func update_visualization_data(visualization_data: PackedByteArray) -> void: # NOTE: The data is an SVO TODO document this!
	assert(false, "Not Implemented!")

func does_world_position_map_to_neuron_coordinate(world_position: Vector3) -> bool:
	assert(false, "Not Implemented!")
	return false

## Helper function that converts a world coordinate to neuron coordinate
func world_godot_position_to_neuron_coordinate(world_position: Vector3) -> Vector3i:
	assert(false, "Not Implemented!")
	return Vector3i(-1,-1,-1)
