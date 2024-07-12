extends BaseDraggableWindow
class_name AdvancedCorticalProperties
## Shows properties of various cortical areas and allows multi-editing


const WINDOW_NAME: StringName = "adv_cortical_properties"

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
@export var _button_summary_send: Button

#Firing Paramters
@export var _section_firing_parameters: VerticalCollapsibleHiding
@export var _line_Fire_Threshold: IntInput
@export var _line_Threshold_Limit: IntInput
@export var _line_neuron_excitability: IntInput
@export var _line_Refactory_Period: IntInput
@export var _line_Leak_Constant: IntInput
@export var _line_Leak_Variability: FloatInput
@export var _line_Consecutive_Fire_Count: IntInput
@export var _line_Snooze_Period: IntInput
@export var _line_Threshold_Inc: Vector3fField
@export var _button_MP_Accumulation: ToggleButton
@export var _button_firing_send: Button

@export var _section_memory: VerticalCollapsibleHiding
@export var _line_initial_neuron_lifespan: IntInput
@export var _line_lifespan_growth_rate: IntInput
@export var _line_longterm_memory_threshold: IntInput
@export var _button_memory_send: Button

@export var _section_cortical_marea_monitoring: VerticalCollapsibleHiding
@export var membrane_toggle: ToggleButton
@export var post_synaptic_toggle: ToggleButton

@export var _section_connections: VerticalCollapsibleHiding

@export var _section_dangerzone: VerticalCollapsibleHiding

# Firing Paramters
var _setup_voxel_neuron_density: CorticalPropertyMultiReferenceHandler
var _setup_synaptic_attractivity: CorticalPropertyMultiReferenceHandler
var _setup_Fire_Threshold: CorticalPropertyMultiReferenceHandler
var _setup_Threshold_Limit: CorticalPropertyMultiReferenceHandler
var _setup_Refactory_Period: CorticalPropertyMultiReferenceHandler
var _setup_Leak_Variability: CorticalPropertyMultiReferenceHandler
var _setup_Consecutive_Fire_Count: CorticalPropertyMultiReferenceHandler
var _setup_Snooze_Period: CorticalPropertyMultiReferenceHandler
var _setup_Threshold_Inc: CorticalPropertyMultiReferenceHandler
var _setup_MP_Accumulation: CorticalPropertyMultiReferenceHandler

# Memory
var _setup_initial_neuron_lifespan: CorticalPropertyMultiReferenceHandler
var _setup_lifespan_growth_rate: CorticalPropertyMultiReferenceHandler
var _setup_longterm_memory_threshold: CorticalPropertyMultiReferenceHandler


var _growing_cortical_update: Dictionary = {}


var _preview_handler: GenericSinglePreviewHandler = null #TODO


func _ready():
	super()


## Load in initial values of the cortical area from Cache
func setup(cortical_area_references: Array[AbstractCorticalArea]) -> void:
	# NOTE: We load initial values from cache while showing the relevant sections, however we do 
	# not connect the signals for cache events updating the window until all relevant cortical area
	# information has been updated. If we did not do this, this window would refresh with every
	# cortical area update, which may be many depending on the selection and would cause a large
	# lag spike. While this method is more tenous, it ultimately provides a better experience for
	# the end user
	
	_setup_base_window(WINDOW_NAME)
	_cortical_area_refs = cortical_area_references
	
	# Setup window for multi vs single mode
	if len(cortical_area_references) == 1:
		# Single Cortical Area Mode window setup
		_section_connections.visible = false
		_vector_dimensions_spin.visible = true
		_vector_dimensions_nonspin.visible = false
		
	else:
		# Multiple Cortical Areas Mode window setup
		_section_connections.visible = true
		_vector_dimensions_spin.visible = false
		_vector_dimensions_nonspin.visible = true
	
	# Initialize Summary Section part 1 (all cortical areas have this), other stuff setup in "refresh_from_core"
	_setup_voxel_neuron_density = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_voxel_neuron_density, "", "cortical_neuron_per_vox_count", "cortical_neuron_per_vox_count", _button_summary_send)
	_setup_synaptic_attractivity = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_synaptic_attractivity, "", "cortical_synaptic_attractivity", "cortical_synaptic_attractivity", _button_summary_send)
	
	_setup_voxel_neuron_density.send_to_update_button.connect(_add_to_dictionary)
	_setup_synaptic_attractivity.send_to_update_button.connect(_add_to_dictionary)
	
	_button_summary_send.pressed.connect(_send_button_pressed.bind(_button_summary_send))
	
	## Setup Neuron firing parameters if ALL selected cortical areas have this property. Otherwise hide the section
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_neuron_firing_parameters"):
		_setup_Fire_Threshold = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Fire_Threshold, "neuron_firing_parameters", "neuron_fire_threshold", "neuron_fire_threshold", _button_firing_send)
		_setup_Threshold_Limit = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Refactory_Period, "neuron_firing_parameters", "neuron_firing_threshold_limit", "neuron_firing_threshold_limit", _button_firing_send)
		_setup_Refactory_Period = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Leak_Constant, "neuron_firing_parameters", "neuron_refractory_period", "neuron_refractory_period", _button_firing_send)
		_setup_Leak_Variability = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Leak_Variability, "neuron_firing_parameters", "neuron_leak_coefficient", "neuron_leak_coefficient", _button_firing_send)
		_setup_Consecutive_Fire_Count = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Consecutive_Fire_Count, "neuron_firing_parameters", "neuron_consecutive_fire_count", "neuron_consecutive_fire_count", _button_firing_send)
		_setup_Snooze_Period = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Snooze_Period, "neuron_firing_parameters", "neuron_snooze_period", "neuron_snooze_period", _button_firing_send)
		_setup_Threshold_Inc = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Threshold_Inc, "neuron_firing_parameters", "neuron_fire_threshold_increment", "neuron_fire_threshold_increment", _button_firing_send)
		_setup_MP_Accumulation = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _button_MP_Accumulation, "neuron_firing_parameters", "neuron_mp_charge_accumulation", "neuron_mp_charge_accumulation", _button_firing_send)
		
		_setup_Fire_Threshold.send_to_update_button.connect(_add_to_dictionary)
		_setup_Threshold_Limit.send_to_update_button.connect(_add_to_dictionary)
		_setup_Refactory_Period.send_to_update_button.connect(_add_to_dictionary)
		_setup_Leak_Variability.send_to_update_button.connect(_add_to_dictionary)
		_setup_Consecutive_Fire_Count.send_to_update_button.connect(_add_to_dictionary)
		_setup_Snooze_Period.send_to_update_button.connect(_add_to_dictionary)
		_setup_Threshold_Inc.send_to_update_button.connect(_add_to_dictionary)
		_setup_MP_Accumulation.send_to_update_button.connect(_add_to_dictionary)
		
		_button_firing_send.pressed.connect(_send_button_pressed.bind(_button_firing_send))
	else:
		_section_firing_parameters.visible = false
	
	# Memory
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_memory_parameters"):
		_setup_initial_neuron_lifespan = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Snooze_Period, "memory_parameters", "initial_neuron_lifespan", "neuron_init_lifespan", _button_memory_send)
		_setup_lifespan_growth_rate = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Threshold_Inc, "memory_parameters", "lifespan_growth_rate", "neuron_lifespan_growth_rate", _button_memory_send)
		_setup_longterm_memory_threshold = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _button_MP_Accumulation, "memory_parameters", "longterm_memory_threshold", "neuron_longterm_mem_threshold", _button_memory_send)
		
		_setup_initial_neuron_lifespan.send_to_update_button.connect(_add_to_dictionary)
		_setup_lifespan_growth_rate.send_to_update_button.connect(_add_to_dictionary)
		_setup_longterm_memory_threshold.send_to_update_button.connect(_add_to_dictionary)
	else:
		_section_memory.visible = false
		
	
	# Everything that happened prior was just making connections, not loading actual data. Loading
	# data comes now in "refresh_from_core"
	refresh_from_core()
	await FeagiCore.requests.get_cortical_areas(_cortical_area_refs)
	refresh_from_core()
	
	# Now that we have loaded data and can avoid the risk to spam, now connect the relevant loaded parts
	
	_setup_voxel_neuron_density.post_load_setup_and_connect_signals_from_FEAGI("cortical_neuron_per_vox_count_updated")
	_setup_synaptic_attractivity.post_load_setup_and_connect_signals_from_FEAGI("cortical_synaptic_attractivity_updated")
	
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_neuron_firing_parameters"):
		_setup_Fire_Threshold.post_load_setup_and_connect_signals_from_FEAGI("neuron_fire_threshold_updated")
		_setup_Threshold_Limit.post_load_setup_and_connect_signals_from_FEAGI("neuron_firing_threshold_limit_updated")
		_setup_Refactory_Period.post_load_setup_and_connect_signals_from_FEAGI("neuron_refractory_period_updated")
		_setup_Leak_Variability.post_load_setup_and_connect_signals_from_FEAGI("neuron_leak_variability_updated")
		_setup_Consecutive_Fire_Count.post_load_setup_and_connect_signals_from_FEAGI("neuron_consecutive_fire_count_updated")
		_setup_Snooze_Period.post_load_setup_and_connect_signals_from_FEAGI("neuron_snooze_period_updated")
		_setup_Threshold_Inc.post_load_setup_and_connect_signals_from_FEAGI("neuron_fire_threshold_increment_updated")
		_setup_MP_Accumulation.post_load_setup_and_connect_signals_from_FEAGI("neuron_mp_charge_accumulation_updated")
	
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_memory_parameters"):
		_setup_initial_neuron_lifespan.post_load_setup_and_connect_signals_from_FEAGI("initial_neuron_lifespan_updated")
		_setup_lifespan_growth_rate.post_load_setup_and_connect_signals_from_FEAGI("lifespan_growth_rate_updated")
		_setup_longterm_memory_threshold.post_load_setup_and_connect_signals_from_FEAGI("longterm_memory_threshold_updated")

	


## Actually load in relevant data to window
func refresh_from_core() -> void:
	# Handle exceptions here
	if len(_cortical_area_refs) == 1:
		var cortical_ref: AbstractCorticalArea = _cortical_area_refs[0]
		_line_cortical_name.text = cortical_ref.friendly_name
		_region_button.text = cortical_ref.current_parent_region.friendly_name
		_line_cortical_ID.text = cortical_ref.cortical_ID
		_line_cortical_type.text = cortical_ref.type_as_string
		_vector_dimensions_spin.current_vector = cortical_ref.dimensions_3D
		_vector_position.current_vector = cortical_ref.coordinates_3D

	else:
		_line_cortical_name.text = "Multiple Selected"
		_region_button.text = "Multiple Selected"
		_line_cortical_ID.text = "Multiple Selected"
		var type: AbstractCorticalArea.CORTICAL_AREA_TYPE =  AbstractCorticalArea.array_oc_cortical_areas_type_identification(_cortical_area_refs)
		if type == AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN:
			_line_cortical_type.text = "Multiple Selected"
		else:
			_line_cortical_type.text = AbstractCorticalArea.cortical_type_to_str(type)
		_vector_position.editable = false
		# TODO Dimensions

	_setup_voxel_neuron_density.refresh_values_from_cache_and_update_control()
	_setup_synaptic_attractivity.refresh_values_from_cache_and_update_control()
	
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_neuron_firing_parameters"):
		_setup_Fire_Threshold.refresh_values_from_cache_and_update_control()
		_setup_Threshold_Limit.refresh_values_from_cache_and_update_control()
		_setup_Refactory_Period.refresh_values_from_cache_and_update_control()
		_setup_Leak_Variability.refresh_values_from_cache_and_update_control()
		_setup_Consecutive_Fire_Count.refresh_values_from_cache_and_update_control()
		_setup_Snooze_Period.refresh_values_from_cache_and_update_control()
		_setup_Threshold_Inc.refresh_values_from_cache_and_update_control()
		_setup_MP_Accumulation.refresh_values_from_cache_and_update_control()




func _add_to_dictionary(update_button: Button, key: StringName, value: Variant) -> void:
	# NOTE: The button node name should be the section name
	update_button.disabled = false
	if ! update_button.name in _growing_cortical_update:
		_growing_cortical_update[update_button.name] = {}
	_growing_cortical_update[update_button.name][key] = value

func _send_button_pressed(button_pressing: Button) -> void:
	button_pressing.disabled = true
	if _growing_cortical_update[button_pressing.name] == {}:
		return
	FeagiCore.requests.update_cortical_areas(_cortical_area_refs, _growing_cortical_update[button_pressing.name])
	_growing_cortical_update[button_pressing.name] = {}
	
	# TODO calculate neuron count changes



