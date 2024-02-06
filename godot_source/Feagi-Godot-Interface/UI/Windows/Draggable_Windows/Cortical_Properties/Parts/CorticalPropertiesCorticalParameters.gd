extends VBoxContainer
class_name CorticalPropertiesCorticalParameters
## Top Section of the Cortical Properties Window
## TODO add field color changing

## User pressed update button, the following changes are requested
signal user_requested_update(changed_values: Dictionary)

var top_panel: WindowCorticalProperties
var _line_cortical_name: TextInput
var _line_cortical_ID: TextInput
var _line_cortical_type: TextInput
var _line_voxel_neuron_density: IntInput
var _line_synaptic_attractivity: IntInput
var _vector_position: Vector3iSpinboxField
var _vector_dimensions: Vector3iSpinboxField
var _update_button: TextButton_Element
var _growing_cortical_update: Dictionary
var _preview_handler: GenericSinglePreviewHandler = null


func _ready():
	_line_cortical_name = $Row_Cortical_Name/Cortical_Name
	_line_cortical_ID = $Row_Cortical_ID/Cortical_ID
	_line_cortical_type = $Row_Cortical_Type/Cortical_Type
	_line_voxel_neuron_density = $Row_Voxel_Neuron_Density/Voxel_Neuron_Density
	_line_synaptic_attractivity = $Synaptic_Attractivity/Synaptic_Attractivity
	_vector_position = $Cortical_Position
	_vector_dimensions = $Cortical_Size
	_update_button = $Update_Button
	
	
	_line_cortical_name.text_confirmed.connect(_user_edit_name)
	_line_voxel_neuron_density.int_confirmed.connect(_user_edit_voxel_density)
	_line_synaptic_attractivity.int_confirmed.connect(_user_edit_synaptic_attractivity)
	_vector_position.user_updated_vector.connect(_user_edit_3D_position)
	_vector_dimensions.user_updated_vector.connect(_user_edit_dimension)
	_update_button.pressed.connect(_user_requests_update)
	

## Displays properties of a cortical area, toggles editability depending on corticala rea configuraiton
func display_cortical_properties(cortical_reference: BaseCorticalArea) -> void:
	_line_cortical_name.text = cortical_reference.name
	_line_cortical_ID.text = cortical_reference.cortical_ID
	_line_cortical_type.text = BaseCorticalArea.cortical_type_to_str(cortical_reference.group)
	_line_voxel_neuron_density.current_int = cortical_reference.cortical_neuron_per_vox_count
	_line_synaptic_attractivity.current_int = cortical_reference.cortical_synaptic_attractivity
	_vector_dimensions.current_vector = cortical_reference.dimensions
	_vector_position.current_vector = cortical_reference.coordinates_3D
	
	_line_cortical_name.editable = cortical_reference.user_can_edit_name
	_line_voxel_neuron_density.editable = cortical_reference.user_can_edit_cortical_neuron_per_vox_count
	_line_synaptic_attractivity.editable = cortical_reference.user_can_edit_cortical_synaptic_attractivity
	_vector_dimensions.editable = cortical_reference.user_can_edit_dimensions
	
	cortical_reference.name_updated.connect(FEAGI_set_cortical_name)
	cortical_reference.cortical_neuron_per_vox_count_updated.connect(FEAGI_set_voxel_neuron_density)
	cortical_reference.cortical_synaptic_attractivity_updated.connect(FEAGI_set_synaptic_attractivity)
	cortical_reference.dimensions_updated.connect(FEAGI_set_cortical_dimension)
	cortical_reference.coordinates_3D_updated.connect(FEAGI_set_cortical_position)


func FEAGI_set_cortical_name(new_name: StringName, _duplicate_ref: BaseCorticalArea):
	_line_cortical_name.text = new_name
	_FEAGI_confirmed_update()

func FEAGI_set_voxel_neuron_density(new_val: int, _duplicate_ref: BaseCorticalArea):
	_line_voxel_neuron_density.current_int = new_val
	_FEAGI_confirmed_update()

func FEAGI_set_synaptic_attractivity(new_val: int, _duplicate_ref: BaseCorticalArea):
	_line_synaptic_attractivity.current_int = new_val
	_FEAGI_confirmed_update()

func FEAGI_set_cortical_dimension(new_dimension: Vector3i, _duplicate_ref: BaseCorticalArea):
	_vector_dimensions.current_vector = new_dimension
	_FEAGI_confirmed_update()

func FEAGI_set_cortical_position(new_position: Vector3i, _duplicate_ref: BaseCorticalArea):
	_vector_position.current_vector = new_position
	_FEAGI_confirmed_update()


## FEAGI confirmed changes, show this in the UI and clear the backend dict
func _FEAGI_confirmed_update() -> void:
	_growing_cortical_update = {} # reset queued changes
	_update_button.disabled = true
	# TODO change edited color of fields

## User pressed update button
func _user_requests_update() -> void:
	if _growing_cortical_update == {}:
		# If user presses update button but no properties are set to change, do nothing
		return
	print("User requesing Summary changes to cortical area")
	user_requested_update.emit(_growing_cortical_update)

func _user_edit_name(new_name: String) -> void:
	_append_to_growing_update("cortical_name", new_name)

func _user_edit_voxel_density(new_val: int) -> void:
	_append_to_growing_update("cortical_neuron_per_vox_count", new_val)

func _user_edit_synaptic_attractivity(new_val: int) -> void:
	_append_to_growing_update("cortical_synaptic_attractivity", new_val)

func _user_edit_3D_position(new_position: Vector3i) -> void:
	_append_to_growing_update("cortical_coordinates", FEAGIUtils.vector3i_to_array(new_position))
	if !is_instance_valid(_preview_handler):
		_enable_3D_preview()

func _user_edit_dimension(new_dimension: Vector3i) -> void:
	_append_to_growing_update("cortical_dimensions", FEAGIUtils.vector3i_to_array(new_dimension))
	if !is_instance_valid(_preview_handler):
		_enable_3D_preview()

func _append_to_growing_update(key: StringName, value: Variant) -> void:
	_growing_cortical_update[key] = value
	_update_button.disabled = false

func _enable_3D_preview():
		var preview_close_signals: Array[Signal] = [_update_button.pressed, top_panel.close_window_requested, top_panel.tree_exiting]
		_preview_handler = GenericSinglePreviewHandler.new()
		_preview_handler.start_BM_preview(_vector_dimensions.current_vector, _vector_position.current_vector)
		_preview_handler.connect_BM_preview(_vector_position.user_updated_vector, _vector_dimensions.user_updated_vector, preview_close_signals)
