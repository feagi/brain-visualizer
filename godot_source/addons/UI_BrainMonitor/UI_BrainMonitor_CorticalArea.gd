extends Node
class_name UI_BrainMonitor_CorticalArea
## Class for rendering cortical areas in the Brain monitor
# NOTE: We will leave adding, removing, or changing parent region to the Brain Monitor itself, since those interactions affect multiple objects

var cortical_area: AbstractCorticalArea:
	get: return _representing_cortial_area

var renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer:
	get: return _dda_renderer

var is_volume_moused_over: bool:
	get: return _is_volume_moused_over

var _representing_cortial_area: AbstractCorticalArea
var _dda_renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer  # For translucent voxel structure
var _directpoints_renderer: UI_BrainMonitor_AbstractCorticalAreaRenderer  # For individual neuron firing

var _is_volume_moused_over: bool
var _hovered_neuron_coordinates: Array[Vector3i] = [] # wouldnt a dictionary be faster?
var _selected_neuron_coordinates: Array[Vector3i] = [] #TODO we should clear this and the hover on dimension changes!


func setup(defined_cortical_area: AbstractCorticalArea) -> void:
	_representing_cortial_area = defined_cortical_area
	name = "CA_" + defined_cortical_area.cortical_ID
	
	# Create DDA renderer for translucent voxel structure
	_dda_renderer = _create_renderer_depending_on_cortical_area_type(_representing_cortial_area)
	add_child(_dda_renderer)
	_dda_renderer.setup(_representing_cortial_area)
	
	# Create DirectPoints renderer for individual neuron firing
	_directpoints_renderer = UI_BrainMonitor_DirectPointsCorticalAreaRenderer.new()
	add_child(_directpoints_renderer)
	_directpoints_renderer.setup(_representing_cortial_area)
	
	# setup signals to update properties automatically for both renderers
	defined_cortical_area.friendly_name_updated.connect(_dda_renderer.update_friendly_name)
	defined_cortical_area.coordinates_3D_updated.connect(_dda_renderer.update_position_with_new_FEAGI_coordinate)
	defined_cortical_area.dimensions_3D_updated.connect(_dda_renderer.update_dimensions)
	
	defined_cortical_area.coordinates_3D_updated.connect(_directpoints_renderer.update_position_with_new_FEAGI_coordinate)
	defined_cortical_area.dimensions_3D_updated.connect(_directpoints_renderer.update_dimensions)
	
	# Connect legacy SVO visualization data to DDA renderer (for translucent structure)
	defined_cortical_area.recieved_new_neuron_activation_data.connect(_dda_renderer.update_visualization_data)
	
	# Connect direct points data to DirectPoints renderer (for individual firing neurons)
	if _directpoints_renderer.has_method("_on_received_direct_neural_points"):
		defined_cortical_area.recieved_new_direct_neural_points.connect(_directpoints_renderer._on_received_direct_neural_points)
		print("🔗 CONNECTED: Type 11 (Direct Neural Points) signal for DirectPoints renderer")
	
	print("✅ DUAL RENDERER SETUP: DDA (translucent structure) + DirectPoints (individual neurons)")

## Sets new position (in FEAGI space)
func set_new_position(new_position: Vector3i) -> void:
	_dda_renderer.update_position_with_new_FEAGI_coordinate(new_position)
	_directpoints_renderer.update_position_with_new_FEAGI_coordinate(new_position)

func set_hover_over_volume_state(is_moused_over: bool) -> void:
	if is_moused_over == _is_volume_moused_over:
		return
	_is_volume_moused_over = is_moused_over
	_dda_renderer.set_cortical_area_mouse_over_highlighting(is_moused_over)
	_directpoints_renderer.set_cortical_area_mouse_over_highlighting(is_moused_over)

func set_highlighted_neurons(neuron_coordinates: Array[Vector3i]) -> void:
		_hovered_neuron_coordinates = neuron_coordinates
		_dda_renderer.set_highlighted_neurons(neuron_coordinates)
		_directpoints_renderer.set_highlighted_neurons(neuron_coordinates)

func clear_hover_state_for_all_neurons() -> void:
	if len(_hovered_neuron_coordinates) != 0:
		_hovered_neuron_coordinates = []
		_dda_renderer.set_highlighted_neurons(_hovered_neuron_coordinates)
		_directpoints_renderer.set_highlighted_neurons(_hovered_neuron_coordinates)

func set_neuron_selection_state(neuron_coordinate: Vector3i, is_selected: bool) -> void:
	var index: int = _selected_neuron_coordinates.find(neuron_coordinate)
	if (index != -1 && is_selected):
		return #nothing to change
	if is_selected:
		_selected_neuron_coordinates.append(neuron_coordinate)
	else:
		_selected_neuron_coordinates.remove_at(index)
	_dda_renderer.set_neuron_selections(_selected_neuron_coordinates)
	_directpoints_renderer.set_neuron_selections(_selected_neuron_coordinates)

# flips the neuron coordinate selection state, and returns the new state (if its selected now)
func toggle_neuron_selection_state(neuron_coordinate: Vector3i) -> bool:
	var index: int = _selected_neuron_coordinates.find(neuron_coordinate)
	var is_selected: bool
	if index == -1:
		_selected_neuron_coordinates.append(neuron_coordinate)
		is_selected = true
	else:
		_selected_neuron_coordinates.remove_at(index)
		is_selected = false
	_dda_renderer.set_neuron_selections(_selected_neuron_coordinates)
	_directpoints_renderer.set_neuron_selections(_selected_neuron_coordinates)
	return is_selected

func clear_all_neuron_selection_states() -> void:
	if len(_selected_neuron_coordinates) != 0:
		_selected_neuron_coordinates =  []
		_dda_renderer.set_neuron_selections(_selected_neuron_coordinates)
		_directpoints_renderer.set_neuron_selections(_selected_neuron_coordinates)

func get_neuron_selection_states() -> Array[Vector3i]:
	return _selected_neuron_coordinates

func _create_renderer_depending_on_cortical_area_type(defined_cortical_area: AbstractCorticalArea) -> UI_BrainMonitor_AbstractCorticalAreaRenderer:
	# Use DDA renderer for translucent voxel structure visualization
	# DDA provides the shader-based translucent cortical area meshes
	
	print("🎮 BRAIN VISUALIZER RENDERER SELECTION:")
	print("   📊 Cortical Area: ", defined_cortical_area.cortical_ID)
	print("   🔄 USING: DDA Renderer (Sparse Voxel Octree)")
	print("   📝 Expected data format: Type 10 (NEURON_FLAT/SVO)")
	print("   🎯 Features: Translucent voxel structure, shader-based rendering")
	return UI_BrainMonitor_DDACorticalAreaRenderer.new()
