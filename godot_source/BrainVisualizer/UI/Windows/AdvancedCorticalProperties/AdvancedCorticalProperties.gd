extends BaseDraggableWindow
class_name AdvancedCorticalProperties
## Shows properties of various cortical areas and allows multi-editing

#TODO URGENT: Major missing feature -> per unit connection to cache for live cahce updates

# region Window Global

const WINDOW_NAME: StringName = "adv_cortical_properties"
var _cortical_area_refs: Array[AbstractCorticalArea]
var _growing_cortical_update: Dictionary = {}


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
	
	# Some sections are only in single cortical area mode
	if len(cortical_area_references) == 1:
		_section_connections.visible = true
	else:
		_section_connections.visible = false
	
	# init sections (that are relevant given the selected)
	_init_summary()
	_refresh_from_cache_summary()
	
	# Request the newest state from feagi, and dont continue until then
	await FeagiCore.requests.get_cortical_areas(_cortical_area_refs)
	
	# refresh all relevant sections again
	_refresh_from_cache_summary()
	
	# Establish connections from core to the UI elements
	#TODO
	



func _update_control_with_value_from_areas(control: Control, composition_section_name: StringName, property_name: StringName) -> void:
	if AbstractCorticalArea.do_cortical_areas_have_matching_values_for_property(_cortical_area_refs, composition_section_name, property_name):
		_set_control_to_value(control, _cortical_area_refs[0].return_property_by_name_and_section(composition_section_name, property_name))
	else:
		_set_control_as_conflicting_values(control)

func _set_control_as_conflicting_values(control: Control) -> void:
	if control is AbstractLineInput:
		(control as AbstractLineInput).set_text_as_invalid()
		return
	if control is ToggleButton:
		(control as ToggleButton).is_inbetween = true
		return
	#NOTE: Vectors only handled here temporarily

func _set_control_to_value(control: Control, value: Variant) -> void:
	if control is TextInput:
		(control as TextInput).text = value
		return
	if control is IntInput:
		(control as IntInput).set_int(value)
		return
	if control is FloatInput:
		(control as FloatInput).set_float(value)
		return
	if control is ToggleButton:
		(control as ToggleButton).set_toggle_no_signal(value)
		return
	if control is Vector3iField:
		(control as Vector3iField).current_vector = value
		return
	if control is Vector3iSpinboxField:
		(control as Vector3iSpinboxField).current_vector = value
		return
	if control is Vector3fField:
		(control as Vector3fField).current_vector = value
		return
		

func _connect_control_to_update_button(control: Control, FEAGI_key_name: StringName, send_update_button: Button) -> void:
	if (control as Variant).has_signal("user_interacted"):
		(control as Variant).user_interacted.connect(_enable_button.bind(send_update_button))
	if control is TextInput:
		(control as TextInput).text_confirmed.connect(_add_to_dict_to_send.bindv([send_update_button, FEAGI_key_name]))
		return
	if control is IntInput:
		(control as IntInput).int_confirmed.connect(_add_to_dict_to_send.bindv([send_update_button, FEAGI_key_name]))
		return
	if control is FloatInput:
		(control as FloatInput).float_confirmed.connect(_add_to_dict_to_send.bindv([send_update_button, FEAGI_key_name]))
		return
	if control is ToggleButton:
		(control as ToggleButton).toggled.connect(_add_to_dict_to_send.bindv([send_update_button, FEAGI_key_name]))
		return
	if control is Vector3iField:
		(control as Vector3iField).user_updated_vector.connect(_add_to_dict_to_send.bindv([send_update_button, FEAGI_key_name]))
		return
	if control is Vector3iSpinboxField:
		(control as Vector3iSpinboxField).user_updated_vector.connect(_add_to_dict_to_send.bindv([send_update_button, FEAGI_key_name]))
		return
	if control is Vector3fField:
		(control as Vector3fField).user_updated_vector.connect(_add_to_dict_to_send.bindv([send_update_button, FEAGI_key_name]))
		return
	
	
func _add_to_dict_to_send(value: Variant, send_button: Button, key_name: StringName) -> void:
	if !send_button.name in _growing_cortical_update:
		_growing_cortical_update[send_button.name] = {}
	if value is Vector3i:
		value = FEAGIUtils.vector3i_to_array(value)
	elif value is Vector3:
		value = FEAGIUtils.vector3_to_array(value)
	_growing_cortical_update[send_button.name][key_name] = value

func _send_update(send_button: Button) -> void:
	if send_button.name in _growing_cortical_update:
		FeagiCore.requests.update_cortical_areas(_cortical_area_refs, _growing_cortical_update[send_button.name])
		_growing_cortical_update[send_button.name] = {}
	send_button.disabled = true

func _enable_button(send_button: Button) -> void:
	send_button.disabled = false
	
	
## OVERRIDDEN from Window manager, to save previous position and collapsible states
func export_window_details() -> Dictionary:
	return {
		"position": position,
		"toggles": _get_expanded_sections()
	}

## OVERRIDDEN from Window manager, to load previous position and collapsible states
func import_window_details(previous_data: Dictionary) -> void:
	position = previous_data["position"]
	if "toggles" in previous_data.keys():
		_set_expanded_sections(previous_data["toggles"])

## Flexible method to return all collapsed sections in Cortical Properties
func _get_expanded_sections() -> Array[bool]:
	var output: Array[bool] = []
	for child in _window_internals.get_children():
		if child is VerticalCollapsibleHiding:
			output.append((child as VerticalCollapsibleHiding).is_open)
	return output

## Flexible method to set all collapsed sections in Cortical Properties
func _set_expanded_sections(expanded: Array[bool]) -> void:
	var collapsibles: Array[VerticalCollapsibleHiding] = []
	
	for child in _window_internals.get_children():
		if child is VerticalCollapsibleHiding:
			collapsibles.append((child as VerticalCollapsibleHiding))
	
	var masimum: int = len(collapsibles)
	if len(expanded) < masimum:
		masimum = len(expanded)
	
	for i: int in masimum:
		collapsibles[i].is_open = expanded[i]





#endregion


#region Summary
var _preview_handler: GenericSinglePreviewHandler = null #TODO

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

func _init_summary() -> void:
	var type: AbstractCorticalArea.CORTICAL_AREA_TYPE =  AbstractCorticalArea.array_oc_cortical_areas_type_identification(_cortical_area_refs)
	if type == AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN:
		_line_cortical_type.text = "Multiple Selected"
	else:
		_line_cortical_type.text = AbstractCorticalArea.cortical_type_to_str(type)
	
	_connect_control_to_update_button(_line_voxel_neuron_density, "cortical_neuron_per_vox_count", _button_summary_send)
	_connect_control_to_update_button(_line_synaptic_attractivity, "cortical_synaptic_attractivity", _button_summary_send)
	
	# TODO renable region button, but check to make sure all types can be moved
	
	
	if len(_cortical_area_refs) != 1:
		_line_cortical_name.text = "Multiple Selected"
		_line_cortical_name.editable = false
		_region_button.text = "Multiple Selected"
		_line_cortical_ID.text = "Multiple Selected"
		_vector_position.editable = false # TODO show multiple values
		_vector_dimensions_spin.visible = false
		_vector_dimensions_nonspin.visible = true
		_connect_control_to_update_button(_vector_dimensions_nonspin, "cortical_dimensions", _button_summary_send)
	else:
		_connect_control_to_update_button(_vector_position, "coordinates_3d", _button_summary_send)
		_connect_control_to_update_button(_vector_dimensions_spin, "cortical_dimensions", _button_summary_send)
	
	_button_summary_send.pressed.connect(_send_update.bind(_button_summary_send))

func _refresh_from_cache_summary() -> void:
	_line_cortical_name.text = "Multiple Selected"
	
	_update_control_with_value_from_areas(_line_voxel_neuron_density, "", "cortical_neuron_per_vox_count")
	_update_control_with_value_from_areas(_line_synaptic_attractivity, "", "cortical_synaptic_attractivity")
	_update_control_with_value_from_areas(_vector_dimensions_nonspin, "", "dimensions_3D")
	_update_control_with_value_from_areas(_vector_dimensions_spin, "", "dimensions_3D")
	
	_vector_dimensions_spin.user_updated_vector.connect(func(_irrelevant): if !is_instance_valid(_preview_handler): _enable_3D_preview())
	_vector_position.user_updated_vector.connect(func(_irrelevant): if !is_instance_valid(_preview_handler): _enable_3D_preview())
	
	if len(_cortical_area_refs) != 1:
		pass
		#TODO connect size vector
	else:
		# single
		_line_cortical_name.text = _cortical_area_refs[0].friendly_name
		_region_button.text = _cortical_area_refs[0].current_parent_region.friendly_name
		_line_cortical_ID.text = _cortical_area_refs[0].cortical_ID
		_vector_position.current_vector = _cortical_area_refs[0].coordinates_3D
		_vector_dimensions_spin.current_vector = _cortical_area_refs[0].dimensions_3D

func _user_press_edit_region() -> void:
	var config: SelectGenomeObjectSettings = SelectGenomeObjectSettings.config_for_single_brain_region_selection(FeagiCore.feagi_local_cache.brain_regions.get_root_region(), _cortical_area_refs[0].current_parent_region)
	var window: WindowSelectGenomeObject = BV.WM.spawn_select_genome_object(config)
	window.final_selection.connect(_user_edit_region)

func _user_edit_region(selected_objects: Array[GenomeObject]) -> void:
	_add_to_dictionary(_button_summary_send, "parent_region_id", selected_objects[0].genome_ID)

func _enable_3D_preview(): #NOTE only currently works with single
		var move_signals: Array[Signal] = [_vector_position.user_updated_vector]
		var resize_signals: Array[Signal] = [_vector_dimensions_spin.user_updated_vector,  _vector_dimensions_nonspin.user_updated_vector]
		var preview_close_signals: Array[Signal] = [_button_summary_send.pressed, tree_exiting]
		BV.UI.start_cortical_area_preview(_vector_position.current_vector, _vector_dimensions_spin.current_vector, move_signals, resize_signals, preview_close_signals)

#endregion







































# Sections
# Summary


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

# Memory
@export var _section_memory: VerticalCollapsibleHiding
@export var _line_initial_neuron_lifespan: IntInput
@export var _line_lifespan_growth_rate: IntInput
@export var _line_longterm_memory_threshold: IntInput
@export var _button_memory_send: Button

# PostSynapticPotential
@export var _section_post_synaptic_potential_parameters: VerticalCollapsibleHiding
@export var _line_Post_Synaptic_Potential: FloatInput
@export var _line_PSP_Max: FloatInput
@export var _line_Degeneracy_Constant: FloatInput
@export var _button_PSP_Uniformity: ToggleButton
@export var _button_MP_Driven_PSP: ToggleButton
@export var _button_pspp_send: Button

# Monitoring
# NOTE: This section works differently since the membrane / synaptic monitoring refer to seperate endpoints
@export var _section_cortical_area_monitoring: VerticalCollapsibleHiding
@export var membrane_toggle: ToggleButton
@export var post_synaptic_toggle: ToggleButton
@export var render_activity_toggle: ToggleButton
@export var _button_monitoring_send: Button

# Connections
@export var _section_connections: VerticalCollapsibleHiding
@export var _scroll_afferent: ScrollSectionGeneric
@export var _scroll_efferent: ScrollSectionGeneric
@export var _button_recursive: Button


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

# pspp
var _setup_Post_Synaptic_Potential: CorticalPropertyMultiReferenceHandler
var _setup_PSP_Max: CorticalPropertyMultiReferenceHandler
var _setup_Degeneracy_Constant: CorticalPropertyMultiReferenceHandler
var _setup_button_PSP_Uniformity: CorticalPropertyMultiReferenceHandler
var _setup_MP_Driven_PSP: CorticalPropertyMultiReferenceHandler

# Monitoring
var _setup_membrane_monitoring: CorticalPropertyMultiReferenceHandler
var _setup_post_synaptic_monitoring: CorticalPropertyMultiReferenceHandler
var _setup_render_activity: CorticalPropertyMultiReferenceHandler






## Load in initial values of the cortical area from Cache
func setup_prev(cortical_area_references: Array[AbstractCorticalArea]) -> void:
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
		_section_connections.visible = true
		_vector_dimensions_spin.visible = true
		_vector_dimensions_nonspin.visible = false
		_setup_connection_info(_cortical_area_refs[0])
		_region_button.pressed.connect(_user_press_edit_region) # do not allow region editing for multiple cortical areas at this time
		
	else:
		# Multiple Cortical Areas Mode window setup
		_section_connections.visible = false
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
		_setup_initial_neuron_lifespan = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_initial_neuron_lifespan, "memory_parameters", "initial_neuron_lifespan", "neuron_init_lifespan", _button_memory_send)
		_setup_lifespan_growth_rate = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_lifespan_growth_rate, "memory_parameters", "lifespan_growth_rate", "neuron_lifespan_growth_rate", _button_memory_send)
		_setup_longterm_memory_threshold = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_longterm_memory_threshold, "memory_parameters", "longterm_memory_threshold", "neuron_longterm_mem_threshold", _button_memory_send)
		
		_setup_initial_neuron_lifespan.send_to_update_button.connect(_add_to_dictionary)
		_setup_lifespan_growth_rate.send_to_update_button.connect(_add_to_dictionary)
		_setup_longterm_memory_threshold.send_to_update_button.connect(_add_to_dictionary)
	else:
		_section_memory.visible = false
	
	# PSPP
	if true: # As of now, all cortical areas have post_synaptic_potential_paramamters, but this is still a seperate section in case this changes
		_setup_Post_Synaptic_Potential = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Post_Synaptic_Potential, "post_synaptic_potential_paramamters", "neuron_post_synaptic_potential", "neuron_post_synaptic_potential", _button_pspp_send)
		_setup_PSP_Max = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_PSP_Max, "post_synaptic_potential_paramamters", "neuron_post_synaptic_potential_max", "neuron_post_synaptic_potential_max", _button_pspp_send)
		_setup_Degeneracy_Constant = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _line_Degeneracy_Constant, "post_synaptic_potential_paramamters", "neuron_degeneracy_coefficient", "neuron_degeneracy_coefficient", _button_pspp_send)
		_setup_button_PSP_Uniformity = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _button_PSP_Uniformity, "post_synaptic_potential_paramamters", "neuron_psp_uniform_distribution", "neuron_psp_uniform_distribution", _button_pspp_send)
		_setup_MP_Driven_PSP = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, _button_MP_Driven_PSP, "post_synaptic_potential_paramamters", "neuron_mp_driven_psp", "neuron_mp_driven_psp", _button_pspp_send)
		
		_setup_Post_Synaptic_Potential.send_to_update_button.connect(_add_to_dictionary)
		_setup_PSP_Max.send_to_update_button.connect(_add_to_dictionary)
		_setup_Degeneracy_Constant.send_to_update_button.connect(_add_to_dictionary)
		_setup_button_PSP_Uniformity.send_to_update_button.connect(_add_to_dictionary)
		_setup_MP_Driven_PSP.send_to_update_button.connect(_add_to_dictionary)
	
	# Monitoring
	_setup_membrane_monitoring = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, membrane_toggle, "", "is_monitoring_membrane_potential", "", _button_monitoring_send)
	_setup_post_synaptic_monitoring = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, post_synaptic_toggle, "", "is_monitoring_synaptic_potential", "", _button_monitoring_send)
	_setup_render_activity = CorticalPropertyMultiReferenceHandler.new(_cortical_area_refs, render_activity_toggle, "", "cortical_visibility", "", _button_monitoring_send)
	# NOTE due to having multiple endpoints, we have a custom handler for the update button sending things

	
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

	if true: #pspp
		_setup_Post_Synaptic_Potential.post_load_setup_and_connect_signals_from_FEAGI("neuron_post_synaptic_potential_updated")
		_setup_PSP_Max.post_load_setup_and_connect_signals_from_FEAGI("neuron_post_synaptic_potential_max_updated")
		_setup_Degeneracy_Constant.post_load_setup_and_connect_signals_from_FEAGI("neuron_degeneracy_coefficient_updated")
		_setup_button_PSP_Uniformity.post_load_setup_and_connect_signals_from_FEAGI("neuron_psp_uniform_distribution_updated")
		_setup_MP_Driven_PSP.post_load_setup_and_connect_signals_from_FEAGI("neuron_neuron_mp_driven_psp_updated")
	
	# monitoring
	#_setup_membrane_monitoring.post_load_setup_and_connect_signals_from_FEAGI("neuron_degeneracy_coefficient_updated")
	#_setup_post_synaptic_monitoring.post_load_setup_and_connect_signals_from_FEAGI("neuron_psp_uniform_distribution_updated")
	_setup_render_activity.post_load_setup_and_connect_signals_from_FEAGI("cortical_visibility_updated")


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
	
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_memory_parameters"):
		_setup_initial_neuron_lifespan.refresh_values_from_cache_and_update_control()
		_setup_lifespan_growth_rate.refresh_values_from_cache_and_update_control()
		_setup_longterm_memory_threshold.refresh_values_from_cache_and_update_control()

	if true: #pspp
		_setup_Post_Synaptic_Potential.refresh_values_from_cache_and_update_control()
		_setup_PSP_Max.refresh_values_from_cache_and_update_control()
		_setup_Degeneracy_Constant.refresh_values_from_cache_and_update_control()
		_setup_button_PSP_Uniformity.refresh_values_from_cache_and_update_control()
		_setup_MP_Driven_PSP.refresh_values_from_cache_and_update_control()
	
	# monitoring
	_setup_membrane_monitoring.refresh_values_from_cache_and_update_control()
	_setup_post_synaptic_monitoring.refresh_values_from_cache_and_update_control()
	_setup_render_activity.refresh_values_from_cache_and_update_control()

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
	close_window()


	# TODO calculate neuron count changes

func _montoring_update_button_pressed() -> void:
	#TODO this only works for single areas, improve
	FeagiCore.requests.toggle_membrane_monitoring(_cortical_area_refs, membrane_toggle.button_pressed)
	FeagiCore.requests.toggle_synaptic_monitoring(_cortical_area_refs, post_synaptic_toggle.button_pressed)
	FeagiCore.requests.update_cortical_areas(_cortical_area_refs, {"cortical_visibility": render_activity_toggle.button_pressed})
	_button_monitoring_send.disabled = true

#region Cortical Connections

func _setup_connection_info(cortical_reference: AbstractCorticalArea) -> void:
	# Recursive
	for recursive_area: AbstractCorticalArea in cortical_reference.recursive_mappings.keys():
		_add_recursive_area(recursive_area)
	
	# Inputs
	for afferent_area: AbstractCorticalArea in cortical_reference.afferent_mappings.keys():
		_add_afferent_area(afferent_area)
		afferent_area.afferent_input_cortical_area_removed.connect(_remove_afferent_area)
	# Outputs
	for efferent_area: AbstractCorticalArea in cortical_reference.efferent_mappings.keys():
		_add_efferent_area(efferent_area)
		efferent_area.efferent_input_cortical_area_removed.connect(_remove_efferent_area)

	cortical_reference.recursive_cortical_area_added.connect(_add_recursive_area)
	cortical_reference.recursive_cortical_area_added.connect(_remove_recursive_area)
	cortical_reference.afferent_input_cortical_area_added.connect(_add_afferent_area)
	cortical_reference.efferent_input_cortical_area_added.connect(_add_efferent_area)
	cortical_reference.afferent_input_cortical_area_removed.connect(_remove_afferent_area)
	cortical_reference.efferent_input_cortical_area_removed.connect(_remove_efferent_area)

func _add_recursive_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	_button_recursive.text = "Recursive Connection"

func _add_afferent_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	var call_mapping_window: Callable = BV.WM.spawn_mapping_editor.bind(area, _cortical_area_refs[0])
	var item: ScrollSectionGenericItem = _scroll_afferent.add_text_button_with_delete(
		area,
		" " + area.friendly_name + " ",
		call_mapping_window,
		ScrollSectionGeneric.DEFAULT_BUTTON_THEME_VARIANT,
		false
	)
	var delete_request: Callable = FeagiCore.requests.delete_mappings_between_corticals.bind(area, _cortical_area_refs[0])
	var delete_popup: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_cancel_and_action_popup(
		"Delete these mappings?",
		"Are you sure you wish to delete the mappings from %s to this cortical area?" % area.friendly_name,
		delete_request,
		"Yes"
		)
	var popup_request: Callable = BV.WM.spawn_popup.bind(delete_popup)
	item.get_delete_button().pressed.connect(popup_request)

func _add_efferent_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	var call_mapping_window: Callable = BV.WM.spawn_mapping_editor.bind(_cortical_area_refs[0], area)
	var item: ScrollSectionGenericItem = _scroll_efferent.add_text_button_with_delete(
		area,
		area.friendly_name,
		call_mapping_window,
		ScrollSectionGeneric.DEFAULT_BUTTON_THEME_VARIANT,
		false
	)
	var delete_request: Callable = FeagiCore.requests.delete_mappings_between_corticals.bind(_cortical_area_refs[0], area)
	var delete_popup: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_cancel_and_action_popup(
		"Delete these mappings?",
		"Are you sure you wish to delete the mappings from this cortical area to %s?" % area.friendly_name,
		delete_request,
		"Yes"
		)
	var popup_request: Callable = BV.WM.spawn_popup.bind(delete_popup)
	item.get_delete_button().pressed.connect(popup_request)

func _remove_recursive_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	_button_recursive.text = "None Recursive"

func _remove_afferent_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	_scroll_afferent.attempt_remove_item(area)

func _remove_efferent_area(area: AbstractCorticalArea, _irrelevant_mapping = null) -> void:
	_scroll_efferent.attempt_remove_item(area)

func _user_pressed_recursive_button() -> void:
	BV.WM.spawn_mapping_editor(_cortical_area_refs[0], _cortical_area_refs[0])

func _user_pressed_add_afferent_button() -> void:
	BV.WM.spawn_mapping_editor(null, _cortical_area_refs[0])

func _user_pressed_add_efferent_button() -> void:
	BV.WM.spawn_mapping_editor(_cortical_area_refs[0], null)

#endregion



func _user_pressed_delete_button() -> void:
	var genome_objects: Array[GenomeObject] = []
	genome_objects.assign(_cortical_area_refs)
	BV.WM.spawn_confirm_deletion(genome_objects)
	close_window()


