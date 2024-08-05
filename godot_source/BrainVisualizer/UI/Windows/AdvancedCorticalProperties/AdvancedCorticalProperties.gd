extends BaseDraggableWindow
class_name AdvancedCorticalProperties
## Shows properties of various cortical areas and allows multi-editing

#TODO URGENT: Major missing feature -> per unit connection to cache for live cahce updates

# region Window Global

@export var controls_to_hide_in_simple_mode: Array[Control] = [] #NOTE custom logic for sections, do not include those here

const WINDOW_NAME: StringName = "adv_cortical_properties"
var _cortical_area_refs: Array[AbstractCorticalArea]
var _growing_cortical_update: Dictionary = {}
var _memory_section_enabled: bool # NOTE: exists so we need to renable it or not given advanced mode changes

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
	
	_toggle_visiblity_based_on_advanced_mode(BV.UI.is_in_advanced_mode)
	BV.UI.advanced_mode_setting_changed.connect(_toggle_visiblity_based_on_advanced_mode)
	
	_setup_base_window(WINDOW_NAME)
	_cortical_area_refs = cortical_area_references
	
	# Some sections are only in single cortical area mode
	if len(cortical_area_references) == 1:
		_section_connections.visible = true
		_setup_connection_info(cortical_area_references[0])
	else:
		_section_connections.visible = false
	
	# init sections (that are relevant given the selected)
	_init_summary()
	_init_monitoring()
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_neuron_firing_parameters"):
		_init_firing_parameters()
	else:
		_section_firing_parameters.visible = false
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_memory_parameters"):
		_init_memory()
		_memory_section_enabled = true
	else:
		_section_memory.visible = false
	if true: # currently, all cortical areas have this
		_init_psp()
	
	
	_refresh_all_relevant()
	
	# Request the newest state from feagi, and dont continue until then
	await FeagiCore.requests.get_cortical_areas(_cortical_area_refs)
	
	# refresh all relevant sections again
	_refresh_all_relevant()
	
	# Establish connections from core to the UI elements
	#TODO
	
func _refresh_all_relevant() -> void:
	_refresh_from_cache_summary() # all cortical areas have these
	_refresh_from_cache_monitoring()
	
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_neuron_firing_parameters"):
		_refresh_from_cache_firing_parameters()
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_memory_parameters"):
		_refresh_from_cache_memory()
	if true: # currently, all cortical areas have this
		_refresh_from_cache_psp()

#NOTE custom logic for sections
func _toggle_visiblity_based_on_advanced_mode(is_advanced_options_visible: bool) -> void:
	for control in controls_to_hide_in_simple_mode:
		control.visible = is_advanced_options_visible
	if _memory_section_enabled:
		_section_memory.visible = is_advanced_options_visible
	_section_cortical_area_monitoring.visible = is_advanced_options_visible

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
	if control is IntSpinBox:
		(control as IntSpinBox).value_changed.connect(_add_to_dict_to_send.bindv([send_update_button, FEAGI_key_name]))
	
func _add_to_dict_to_send(value: Variant, send_button: Button, key_name: StringName) -> void:
	if !send_button.name in _growing_cortical_update:
		_growing_cortical_update[send_button.name] = {}
	if value is Vector3i:
		value = FEAGIUtils.vector3i_to_array(value)
	elif value is Vector3:
		value = FEAGIUtils.vector3_to_array(value)
	_growing_cortical_update[send_button.name][key_name] = value
	send_button.disabled = false

func _send_update(send_button: Button) -> void:
	if send_button.name in _growing_cortical_update:
		if len(_cortical_area_refs) > 1:
			FeagiCore.requests.update_cortical_areas(_cortical_area_refs, _growing_cortical_update[send_button.name])
		else:
			FeagiCore.requests.update_cortical_area(_cortical_area_refs[0].cortical_ID, _growing_cortical_update[send_button.name])
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
@export var _device_count_section: HBoxContainer
@export var _device_count: IntSpinBox
@export var _line_voxel_neuron_density: IntInput
@export var _line_synaptic_attractivity: IntInput
@export var _dimensions_label: Label
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
		# Single
		_connect_control_to_update_button(_line_cortical_name, "cortical_name", _button_summary_send)
		_connect_control_to_update_button(_vector_position, "coordinates_3d", _button_summary_send)
		_connect_control_to_update_button(_vector_dimensions_spin, "cortical_dimensions", _button_summary_send)
		if _cortical_area_refs[0].is_device_count_available:
			_connect_control_to_update_button(_device_count, "dev_count", _button_summary_send)
			_dimensions_label.text = "Dimensions Per Device"
		
	
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
		if _cortical_area_refs[0].is_device_count_available:
			_device_count_section.visible = true
			_update_control_with_value_from_areas(_device_count, "", "dev_count")
			

func _user_press_edit_region() -> void:
	var config: SelectGenomeObjectSettings = SelectGenomeObjectSettings.config_for_single_brain_region_selection(FeagiCore.feagi_local_cache.brain_regions.get_root_region(), _cortical_area_refs[0].current_parent_region)
	var window: WindowSelectGenomeObject = BV.WM.spawn_select_genome_object(config)
	window.final_selection.connect(_user_edit_region)

func _user_edit_region(selected_objects: Array[GenomeObject]) -> void:
	_add_to_dict_to_send(selected_objects[0].genome_ID, _button_summary_send, "parent_region_id")

func _enable_3D_preview(): #NOTE only currently works with single
		var move_signals: Array[Signal] = [_vector_position.user_updated_vector]
		var resize_signals: Array[Signal] = [_vector_dimensions_spin.user_updated_vector,  _vector_dimensions_nonspin.user_updated_vector]
		var preview_close_signals: Array[Signal] = [_button_summary_send.pressed, tree_exiting]
		BV.UI.start_cortical_area_preview(_vector_position.current_vector, _vector_dimensions_spin.current_vector, move_signals, resize_signals, preview_close_signals)

#endregion

#region firing parameters

@export var _section_firing_parameters: VerticalCollapsibleHiding
@export var _line_Fire_Threshold: FloatInput
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


func _init_firing_parameters() -> void:
	_connect_control_to_update_button(_button_MP_Accumulation, "neuron_mp_charge_accumulation", _button_firing_send)
	_connect_control_to_update_button(_line_Fire_Threshold, "neuron_fire_threshold", _button_firing_send)
	_connect_control_to_update_button(_line_Threshold_Limit, "neuron_firing_threshold_limit", _button_firing_send)
	_connect_control_to_update_button(_line_neuron_excitability, "neuron_excitability", _button_firing_send)
	_connect_control_to_update_button(_line_Refactory_Period, "neuron_refractory_period", _button_firing_send)
	_connect_control_to_update_button(_line_Leak_Constant, "neuron_leak_coefficient", _button_firing_send)
	_connect_control_to_update_button(_line_Leak_Variability, "neuron_leak_variability", _button_firing_send)
	_connect_control_to_update_button(_line_Consecutive_Fire_Count, "neuron_consecutive_fire_count", _button_firing_send)
	_connect_control_to_update_button(_line_Snooze_Period, "neuron_snooze_period", _button_firing_send)
	_connect_control_to_update_button(_line_Threshold_Inc, "neuron_fire_threshold_increment", _button_firing_send)
	
	_button_firing_send.pressed.connect(_send_update.bind(_button_firing_send))

func _refresh_from_cache_firing_parameters() -> void:
	_update_control_with_value_from_areas(_button_MP_Accumulation, "neuron_firing_parameters", "neuron_mp_charge_accumulation")
	_update_control_with_value_from_areas(_line_Fire_Threshold, "neuron_firing_parameters", "neuron_fire_threshold")
	_update_control_with_value_from_areas(_line_Threshold_Limit, "neuron_firing_parameters", "neuron_firing_threshold_limit")
	_update_control_with_value_from_areas(_line_neuron_excitability, "neuron_firing_parameters", "neuron_excitability")
	_update_control_with_value_from_areas(_line_Refactory_Period, "neuron_firing_parameters", "neuron_refractory_period")
	_update_control_with_value_from_areas(_line_Leak_Constant, "neuron_firing_parameters", "neuron_leak_coefficient")
	_update_control_with_value_from_areas(_line_Leak_Variability, "neuron_firing_parameters", "neuron_leak_variability")
	_update_control_with_value_from_areas(_line_Consecutive_Fire_Count, "neuron_firing_parameters", "neuron_consecutive_fire_count")
	_update_control_with_value_from_areas(_line_Snooze_Period, "neuron_firing_parameters", "neuron_snooze_period")
	_update_control_with_value_from_areas(_line_Threshold_Inc, "neuron_firing_parameters", "neuron_fire_threshold_increment")

#endregion


#region Memory
@export var _section_memory: VerticalCollapsibleHiding
@export var _line_initial_neuron_lifespan: IntInput
@export var _line_lifespan_growth_rate: IntInput
@export var _line_longterm_memory_threshold: IntInput
@export var _button_memory_send: Button

func _init_memory() -> void:
	_connect_control_to_update_button(_line_initial_neuron_lifespan, "neuron_init_lifespan", _button_memory_send)
	_connect_control_to_update_button(_line_lifespan_growth_rate, "neuron_lifespan_growth_rate", _button_memory_send)
	_connect_control_to_update_button(_line_longterm_memory_threshold, "neuron_longterm_mem_threshold", _button_memory_send)
	
	_button_memory_send.pressed.connect(_send_update.bind(_button_memory_send))

func _refresh_from_cache_memory() -> void:
	_update_control_with_value_from_areas(_line_initial_neuron_lifespan, "memory_parameters", "initial_neuron_lifespan")
	_update_control_with_value_from_areas(_line_lifespan_growth_rate, "memory_parameters", "lifespan_growth_rate")
	_update_control_with_value_from_areas(_line_longterm_memory_threshold, "memory_parameters", "longterm_memory_threshold")


#endregion


#region PSP
@export var _section_post_synaptic_potential_parameters: VerticalCollapsibleHiding
@export var _line_Post_Synaptic_Potential: FloatInput
@export var _line_PSP_Max: FloatInput
@export var _line_Degeneracy_Constant: FloatInput
@export var _button_PSP_Uniformity: ToggleButton
@export var _button_MP_Driven_PSP: ToggleButton
@export var _button_pspp_send: Button

func _init_psp() -> void:
	_connect_control_to_update_button(_line_Post_Synaptic_Potential, "neuron_post_synaptic_potential", _button_pspp_send)
	_connect_control_to_update_button(_line_PSP_Max, "neuron_post_synaptic_potential_max", _button_pspp_send)
	_connect_control_to_update_button(_line_Degeneracy_Constant, "neuron_degeneracy_coefficient", _button_pspp_send)
	_connect_control_to_update_button(_button_PSP_Uniformity, "neuron_psp_uniform_distribution", _button_pspp_send)
	_connect_control_to_update_button(_button_MP_Driven_PSP, "neuron_mp_driven_psp", _button_pspp_send)
	
	_button_pspp_send.pressed.connect(_send_update.bind(_button_pspp_send))

func _refresh_from_cache_psp() -> void:
	_update_control_with_value_from_areas(_line_Post_Synaptic_Potential, "post_synaptic_potential_paramamters", "neuron_post_synaptic_potential")
	_update_control_with_value_from_areas(_line_PSP_Max, "post_synaptic_potential_paramamters", "neuron_post_synaptic_potential_max")
	_update_control_with_value_from_areas(_line_Degeneracy_Constant, "post_synaptic_potential_paramamters", "neuron_degeneracy_coefficient")
	_update_control_with_value_from_areas(_button_PSP_Uniformity, "post_synaptic_potential_paramamters", "neuron_psp_uniform_distribution")
	_update_control_with_value_from_areas(_button_MP_Driven_PSP, "post_synaptic_potential_paramamters", "neuron_mp_driven_psp")
	_line_Post_Synaptic_Potential.editable = !_button_MP_Driven_PSP.button_pressed
	_button_MP_Driven_PSP.toggled.connect(func(is_on: bool): _line_Post_Synaptic_Potential.editable = !is_on )

#endregion

# NOTE: This section works differently since the membrane / synaptic monitoring refer to seperate endpoints
#region Monitoring

@export var _section_cortical_area_monitoring: VerticalCollapsibleHiding
@export var membrane_toggle: ToggleButton
@export var post_synaptic_toggle: ToggleButton
@export var render_activity_toggle: ToggleButton
@export var _button_monitoring_send: Button

func _init_monitoring() -> void:
	_button_monitoring_send.pressed.connect(_montoring_update_button_pressed)
	post_synaptic_toggle.disabled = !FeagiCore.feagi_local_cache.influxdb_availability
	membrane_toggle.disabled = !FeagiCore.feagi_local_cache.influxdb_availability
	render_activity_toggle.pressed.connect(_button_monitoring_send.set_disabled.bind(false))
	post_synaptic_toggle.pressed.connect(_button_monitoring_send.set_disabled.bind(false))
	membrane_toggle.pressed.connect(_button_monitoring_send.set_disabled.bind(false))
	
func _refresh_from_cache_monitoring() -> void:
	if FeagiCore.feagi_local_cache.influxdb_availability:
		_update_control_with_value_from_areas(membrane_toggle, "", "is_monitoring_membrane_potential")
		_update_control_with_value_from_areas(post_synaptic_toggle, "", "is_monitoring_synaptic_potential")
	_update_control_with_value_from_areas(render_activity_toggle, "", "cortical_visibility")


func _montoring_update_button_pressed() -> void:
	#TODO this only works for single areas, improve
	FeagiCore.requests.toggle_membrane_monitoring(_cortical_area_refs, membrane_toggle.button_pressed)
	FeagiCore.requests.toggle_synaptic_monitoring(_cortical_area_refs, post_synaptic_toggle.button_pressed)
	FeagiCore.requests.update_cortical_areas(_cortical_area_refs, {"cortical_visibility": render_activity_toggle.button_pressed})
	_button_monitoring_send.disabled = true

#endregion


#region Connections

@export var _section_connections: VerticalCollapsibleHiding
@export var _scroll_afferent: ScrollSectionGeneric
@export var _scroll_efferent: ScrollSectionGeneric
@export var _button_recursive: Button

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




#region DangerZone

@export var _section_dangerzone: VerticalCollapsibleHiding

func _user_pressed_delete_button() -> void:
	var genome_objects: Array[GenomeObject] = []
	genome_objects.assign(_cortical_area_refs)
	BV.WM.spawn_confirm_deletion(genome_objects)
	close_window()


#endregion




