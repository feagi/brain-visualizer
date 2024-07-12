extends BaseDraggableWindow
class_name AdvancedCorticalProperties
## Shows properties of various cortical areas and allows multi-editing


const WINDOW_NAME: StringName = "cortical_properties"

var _cortical_area_refs: Array[AbstractCorticalArea]

# Sections
# Summary
@export var _section_summary: VerticalCollapsibleHiding
@export var _line_cortical_name: TextInput
@export var _region_button: Button
@export var _line_cortical_ID: TextInput
@export var _line_cortical_type: TextInput
@export var _line_voxel_neuron_density: IntInput
@export var _line_synaptic_attractivity: IntInput
@export var _vector_dimensions_spin: Vector3iSpinboxField
@export var _vector_dimensions_nonspin: Vector3iField
@export var _vector_position: Vector3iSpinboxField


var _growing_cortical_update: Dictionary = {}


var _preview_handler: GenericSinglePreviewHandler = null #TODO


func _ready():
	super()


## Load in initial values of the cortical area from Cache
func setup(cortical_area_references: Array[AbstractCorticalArea]) -> void:
	_setup_base_window(WINDOW_NAME)
	_cortical_area_refs = cortical_area_references
	
	var setup_voxel_neuron_density: CorticalPropertyMultiReferenceHandler = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_voxel_neuron_density, "", "cortical_neuron_per_vox_count")
	var setup_synaptic_attractivity: CorticalPropertyMultiReferenceHandler = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_synaptic_attractivity, "", "cortical_synaptic_attractivity")
	
	# Handle exceptions here
	if len(cortical_area_references) == 1:
		var cortical_ref: AbstractCorticalArea = cortical_area_references[0]
		
		_line_cortical_name.text = cortical_ref.friendly_name
		_region_button.text = cortical_ref.current_parent_region.friendly_name
		_line_cortical_ID.text = cortical_ref.cortical_ID
		_line_cortical_type.text = cortical_ref.type_as_string
		_vector_dimensions_spin.current_vector = cortical_ref.dimensions_3D
		_vector_position.current_vector = cortical_ref.coordinates_3D
		

	else:
		_line_cortical_name.text = "Multiple Selected"
		#_region_button.text = cortical_ref.current_parent_region.friendly_name?
		_line_cortical_ID.text = "Multiple Selected"
		_line_cortical_type.text = "Multiple Selected"
		_vector_dimensions_spin.visible = false
		_vector_dimensions_nonspin.visible = true
		# TODO Dimensions
		# TODO Position
	

func _add_to_dictionary(update_button: Button, key: StringName, value: Variant) -> void:
	# NOTE: The button node name should be the section name
	update_button.disabled = false
	if ! update_button.name in _growing_cortical_update:
		_growing_cortical_update[update_button.name] = {}
	_growing_cortical_update[update_button.name][key] = value

func _button_pressed(button_pressing: Button) -> void:
	button_pressing.disabled = true
	if _growing_cortical_update[button_pressing.name] == {}:
		return
	FeagiCore.requests.mass_update_cortical_areas(AbstractCorticalArea.cortical_area_array_to_ID_array(_cortical_area_refs), _growing_cortical_update[button_pressing.name])
	_growing_cortical_update[button_pressing.name] = {}
	
	# TODO calculate neuron count changes






## F

