extends Node3D
class_name UI_BrainMonitor_CorticalArea
## Class for rendering cortical areas in the Brain monitor
# NOTE: We will leave adding, removing, or changing parent region to the Brain Monitor itself, since those interactions affect multiple objects

var _selected_neuron_coordinates: Array[Vector3i] = [] ## Neurons that are selected for use in manual firing
var _moused_over_neuron_coordinates: Array[Vector3i] = []

var _representing_cortial_area: AbstractCorticalArea
var _renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer

static func create_renderer_depending_on_cortical_area_type(cortical_area: AbstractCorticalArea) -> UI_BrainMonitor_AbstractCorticalAreaRenderer:
	# TODO this is temporary, later add actual selection mechanism
	return UI_BrainMonitor_DDACorticalAreaRenderer.new()

func setup(cortical_area: AbstractCorticalArea) -> void:
	_representing_cortial_area = cortical_area
	name = "CA_" + cortical_area.cortical_ID
	_renderer = create_renderer_depending_on_cortical_area_type(_representing_cortial_area)
	_renderer.setup(_representing_cortial_area)
	
	# setup signals to update properties automatically
	cortical_area.friendly_name_updated.connect(_renderer.update_friendly_name)
	cortical_area.coordinates_3D_updated.connect(_renderer.update_position)
	cortical_area.dimensions_3D_updated.connect(_renderer.update_dimensions)
	

#region Helper Functions
func get_cortical_area() -> AbstractCorticalArea:
	return _representing_cortial_area

#endregion
