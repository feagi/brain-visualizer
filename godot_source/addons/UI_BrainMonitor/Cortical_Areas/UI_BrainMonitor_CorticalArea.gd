extends Node3D
class_name UI_BrainMonitor_CorticalArea
## Class for rendering cortical areas in the Brain monitor
# NOTE: We will leave adding, removing, or changing parent region to the Brain Monitor itself, since those interactions affect multiple objects

var cortical_area: AbstractCorticalArea:
	get: return _representing_cortial_area

var renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer:
	get: return _renderer

var is_volume_moused_over: bool:
	get: return _is_volume_moused_over

var _representing_cortial_area: AbstractCorticalArea
var _renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer

var _is_volume_moused_over: bool
var _moused_over_neuron_coordinates: Array[Vector3i] = [] # wouldnt a dictionary be faster?


func setup(defined_cortical_area: AbstractCorticalArea) -> void:
	_representing_cortial_area = defined_cortical_area
	name = "CA_" + defined_cortical_area.cortical_ID
	_renderer = _create_renderer_depending_on_cortical_area_type(_representing_cortial_area)
	add_child(_renderer)
	_renderer.setup(_representing_cortial_area)
	
	# setup signals to update properties automatically
	defined_cortical_area.friendly_name_updated.connect(_renderer.update_friendly_name)
	defined_cortical_area.coordinates_3D_updated.connect(_renderer.update_position)
	defined_cortical_area.dimensions_3D_updated.connect(_renderer.update_dimensions)
	defined_cortical_area.recieved_new_neuron_activation_data.connect(_renderer.update_visualization_data)


func set_mouse_over_volume_state(is_moused_over: bool) -> void:
	_is_volume_moused_over = is_moused_over
	_renderer.set_cortical_area_mouse_over_highlighting(is_moused_over)

func set_highlighted_neurons(neuron_coordinates: Array[Vector3i]) -> void:
		_moused_over_neuron_coordinates = neuron_coordinates
		_renderer.set_highlighted_neurons(neuron_coordinates)

func clear_mouse_over_state_for_all_neurons() -> void:
	if len(_moused_over_neuron_coordinates) != 0:
		_moused_over_neuron_coordinates = []
		_renderer.set_highlighted_neurons(_moused_over_neuron_coordinates)

func _create_renderer_depending_on_cortical_area_type(defined_cortical_area: AbstractCorticalArea) -> UI_BrainMonitor_AbstractCorticalAreaRenderer:
	# TODO this is temporary, later add actual selection mechanism
	return UI_BrainMonitor_DDACorticalAreaRenderer.new()
