extends BaseDraggableWindow
class_name AdvancedCorticalProperties
## Shows properties of various cortical areas and allows multi-editing

#TODO URGENT: Major missing feature -> per unit connection to cache for live cahce updates

# @cursor:critical-path - UI permission enforcement for CORE cortical areas
# Core areas: everything read-only/disabled except position and connections.

# region Window Global

@export var controls_to_hide_in_simple_mode: Array[Control] = [] #NOTE custom logic for sections, do not include those here

const WINDOW_NAME: StringName = "adv_cortical_properties"
const IO_PRESET_INPUT: StringName = "Input"
const IO_PRESET_OUTPUT: StringName = "Output"
const IO_PRESET_INTERCONNECT: StringName = "Interconnect"
const IO_PRESET_CONFLICT: StringName = "Conflict"
const IO_PRESET_MULTI: StringName = "Multiple Selected"
var _cortical_area_refs: Array[AbstractCorticalArea]
var _growing_cortical_update: Dictionary = {}
var _memory_section_enabled: bool # NOTE: exists so we need to renable it or not given advanced mode changes
var _preview: UI_BrainMonitor_InteractivePreview
var _aux_previews: Array[UI_BrainMonitor_InteractivePreview] = []
var _aux_preview_to_bm: Dictionary = {}
var _host_preview_bm: UI_BrainMonitor_3DScene = null
var _skip_unit_id_confirmation: bool = false

# isvi segmented vision variables
var _is_isvi_segment: bool = false
var _isvi_unit_id: int = -1  # Cortical unit index (which unit of this type)
var _isvi_all_segments: Array[AbstractCorticalArea] = []
var _isvi_segment_previews: Dictionary = {}  # Maps subunit_id to preview object
var _isvi_original_z_values: Dictionary = {}  # Maps subunit_id to original z coordinate (captured at detection)
var _isvi_would_overflow: bool = false  # True if current resize would exceed NPU capacity


func _ready():
	super()
	BV.UI.selection_system.add_override_usecase(SelectionSystem.OVERRIDE_USECASE.CORTICAL_PROPERTIES)

func _are_all_io_areas() -> bool:
	if _cortical_area_refs == null or _cortical_area_refs.is_empty():
		return false
	for area in _cortical_area_refs:
		if area.cortical_type not in [
			AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU,
			AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU
		]:
			return false
	return true

	

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
	if _are_all_io_areas():
		_init_neuron_coding()
		if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_neuron_firing_parameters"):
			_init_firing_parameters()
		else:
			_section_firing_parameters.visible = false
	else:
		if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_neuron_firing_parameters"):
			_init_firing_parameters()
		else:
			_section_firing_parameters.visible = false
		_section_neuron_coding.visible = false
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_memory_parameters"):
		_init_memory()
		_memory_section_enabled = true
	else:
		_section_memory.visible = false
	if true: # currently, all cortical areas have this
		_init_psp()
	
	
	_refresh_all_relevant()
	_apply_type_based_ui_restrictions()
	
	# Request the newest state from feagi, and dont continue until then
	# Only if FeagiCore is ready and network components are initialized
	if FeagiCore and FeagiCore.requests and FeagiCore.can_interact_with_feagi() and FeagiCore.network and FeagiCore.network.http_API and FeagiCore.network.http_API.address_list:
		var previous_suppress_state = FeagiCore.feagi_local_cache.cortical_areas.suppress_update_notifications
		FeagiCore.feagi_local_cache.cortical_areas.suppress_update_notifications = true
		await FeagiCore.requests.get_cortical_areas(_cortical_area_refs)
		FeagiCore.feagi_local_cache.cortical_areas.suppress_update_notifications = previous_suppress_state
	else:
		print("UI: Advanced Cortical Properties - Skipping FEAGI update request as network is not ready")
	
	# refresh all relevant sections again
	_refresh_all_relevant()
	_apply_type_based_ui_restrictions()
	
	# Re-detect isvi segments now that we have fresh data from FEAGI
	if len(_cortical_area_refs) == 1:
		_detect_and_setup_isvi_segment()
		
		# If it's now detected as isvi, we need to fetch details for all other vision segments
		if _is_isvi_segment:
			
			# Collect all vision segment IDs (those starting with "aXN2aQ")
			var all_vision_segments: Array[AbstractCorticalArea] = []
			var all_cortical_areas = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.values()
			for cortical_area in all_cortical_areas:
				if cortical_area.cortical_ID.begins_with("aXN2aQ"):
					all_vision_segments.append(cortical_area)
			
			
			# Fetch details for all vision segments
			if FeagiCore and FeagiCore.requests and FeagiCore.can_interact_with_feagi():
				var previous_suppress_state = FeagiCore.feagi_local_cache.cortical_areas.suppress_update_notifications
				FeagiCore.feagi_local_cache.cortical_areas.suppress_update_notifications = true
				await FeagiCore.requests.get_cortical_areas(all_vision_segments)
				FeagiCore.feagi_local_cache.cortical_areas.suppress_update_notifications = previous_suppress_state
				
				# Now re-detect with all the fresh data
				_detect_and_setup_isvi_segment()
				
			
			# Connect signals and init previews
			if _is_isvi_segment and len(_isvi_all_segments) > 0:
				_vector_position.user_updated_vector.connect(_on_isvi_layout_changed.unbind(1))
				_vector_dimensions_spin.user_updated_vector.connect(_on_isvi_layout_changed.unbind(1))
				_init_isvi_previews()
	
	# Establish connections from core to the UI elements
	#TODO

func close_window() -> void:
	super()
	BV.UI.selection_system.remove_override_usecase(SelectionSystem.OVERRIDE_USECASE.CORTICAL_PROPERTIES)
	# Cleanup auxiliary previews
	for aux in _aux_previews:
		if aux != null:
			aux.queue_free()
	_aux_previews.clear()
	# Cleanup isvi segment previews
	for preview in _isvi_segment_previews.values():
		if preview != null:
			preview.queue_free()
	_isvi_segment_previews.clear()

func _refresh_all_relevant() -> void:
	_refresh_from_cache_summary() # all cortical areas have these
	_refresh_from_cache_monitoring()
	
	if _are_all_io_areas():
		_refresh_from_cache_neuron_coding()
		if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_neuron_firing_parameters"):
			_refresh_from_cache_firing_parameters()
	elif AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_neuron_firing_parameters"):
		_refresh_from_cache_firing_parameters()
	if AbstractCorticalArea.boolean_property_of_all_cortical_areas_are_true(_cortical_area_refs, "has_memory_parameters"):
		_refresh_from_cache_memory()
	if true: # currently, all cortical areas have this
		_refresh_from_cache_psp()
	
	# Ensure per-type UI permissions are re-applied after refresh (some refresh methods
	# adjust editability based on internal toggles, e.g. PSP).
	_apply_type_based_ui_restrictions()


func _is_core_type_context() -> bool:
	# Never hardcode cortical IDs; enforce based on cortical type.
	return AbstractCorticalArea.array_oc_cortical_areas_type_identification(_cortical_area_refs) == AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE


func _apply_type_based_ui_restrictions() -> void:
	# Currently only CORE has strict UI restrictions.
	if _cortical_area_refs == null or _cortical_area_refs.is_empty():
		return
	if !_is_core_type_context():
		return
	_apply_core_type_restrictions()


func _apply_core_type_restrictions() -> void:
	# Rule: on CORE areas, with the exception of the position field and connections,
	# everything else should be readonly and grayed out.
	#
	# NOTE: Connections section is already single-select only; do not disable it.
	# NOTE: Position is editable only for single-select in existing behavior; we preserve that.
	var is_single: bool = _cortical_area_refs.size() == 1
	
	# Summary (allow only position)
	if _line_cortical_name != null:
		_line_cortical_name.editable = false
	if _region_button != null:
		_region_button.disabled = true
	if _device_count != null:
		_device_count.editable = false
	if _line_voxel_neuron_density != null:
		_line_voxel_neuron_density.editable = false
	if _line_synaptic_attractivity != null:
		_line_synaptic_attractivity.editable = false
	if _vector_dimensions_spin != null:
		_vector_dimensions_spin.editable = false
	if _vector_dimensions_nonspin != null:
		_vector_dimensions_nonspin.editable = false
	if _vector_visualization_voxel_granularity != null:
		_vector_visualization_voxel_granularity.editable = false
	
	if _vector_position != null and is_single:
		_vector_position.editable = true
	
	# Apply button: keep available for position updates (it will remain disabled until a change).
	# No action required here.
	
	# Neuron Firing Parameters
	if _button_MP_Accumulation != null:
		_button_MP_Accumulation.disabled = true
	if _line_Fire_Threshold != null:
		_line_Fire_Threshold.editable = false
	if _line_Threshold_Limit != null:
		_line_Threshold_Limit.editable = false
	if _line_neuron_excitability != null:
		_line_neuron_excitability.editable = false
	if _line_Refactory_Period != null:
		_line_Refactory_Period.editable = false
	if _line_Leak_Constant != null:
		_line_Leak_Constant.editable = false
	if _line_Leak_Variability != null:
		_line_Leak_Variability.editable = false
	if _line_Consecutive_Fire_Count != null:
		_line_Consecutive_Fire_Count.editable = false
	if _line_Snooze_Period != null:
		_line_Snooze_Period.editable = false
	if _line_Threshold_Inc != null:
		_line_Threshold_Inc.editable = false
	if _button_firing_send != null:
		_button_firing_send.disabled = true
	
	# Memory
	if _line_initial_neuron_lifespan != null:
		_line_initial_neuron_lifespan.editable = false
	if _line_lifespan_growth_rate != null:
		_line_lifespan_growth_rate.editable = false
	if _line_longterm_memory_threshold != null:
		_line_longterm_memory_threshold.editable = false
	if _line_temporal_depth != null:
		_line_temporal_depth.editable = false
	if _button_memory_send != null:
		_button_memory_send.disabled = true
	
	# Post Synaptic Potential Parameters
	if _line_Post_Synaptic_Potential != null:
		_line_Post_Synaptic_Potential.editable = false
	if _line_PSP_Max != null:
		_line_PSP_Max.editable = false
	if _line_Degeneracy_Constant != null:
		_line_Degeneracy_Constant.editable = false
	if _button_PSP_Uniformity != null:
		_button_PSP_Uniformity.disabled = true
	if _button_MP_Driven_PSP != null:
		_button_MP_Driven_PSP.disabled = true
	if _button_pspp_send != null:
		_button_pspp_send.disabled = true
	
	# Monitoring
	if membrane_toggle != null:
		membrane_toggle.disabled = true
	if post_synaptic_toggle != null:
		post_synaptic_toggle.disabled = true
	if render_activity_toggle != null:
		render_activity_toggle.disabled = true
	if _button_monitoring_send != null:
		_button_monitoring_send.disabled = true
	
	# Danger Zone (delete/reset)
	# Use direct node lookup to avoid expanding the exported node_paths list in the .tscn.
	if _section_dangerzone != null:
		var dz_root: Node = _section_dangerzone
		var delete_btn: Node = dz_root.get_node_or_null("VerticalCollapsible/PanelContainer/PutThingsHere/CorticalPropertiesDangerZone/Delete/DeleteButton")
		if delete_btn is BaseButton:
			(delete_btn as BaseButton).disabled = true
		var reset_btn: Node = dz_root.get_node_or_null("VerticalCollapsible/PanelContainer/PutThingsHere/CorticalPropertiesDangerZone/Reset/ResetButton")
		if reset_btn is BaseButton:
			(reset_btn as BaseButton).disabled = true

#NOTE custom logic for sections
func _toggle_visiblity_based_on_advanced_mode(is_advanced_options_visible: bool) -> void:
	for control in controls_to_hide_in_simple_mode:
		control.visible = is_advanced_options_visible
	if _memory_section_enabled:
		_section_memory.visible = is_advanced_options_visible
	_section_cortical_area_monitoring.visible = is_advanced_options_visible

func _update_control_with_value_from_areas(control: Control, composition_section_name: StringName, property_name: StringName) -> void:
	if control == null:
		push_error("AdvancedCorticalProperties: Attempted to update null control for property '%s'" % property_name)
		return
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
	if control is IntSpinBox:
		(control as IntSpinBox).value = value
		return
	if control is DropDown:
		if value != null:
			(control as DropDown).set_option(StringName(str(value)))
		

func _connect_control_to_update_button(control: Control, FEAGI_key_name: StringName, send_update_button: Button) -> void:
	if control == null:
		push_error("AdvancedCorticalProperties: Attempted to connect null control for key '%s'" % FEAGI_key_name)
		return
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
		return
	if control is DropDown:
		(control as DropDown).option_changed.connect(_add_to_dict_to_send.bindv([send_update_button, FEAGI_key_name]))
		return
	
func _add_to_dict_to_send(value: Variant, send_button: Button, key_name: StringName) -> void:
	if !send_button.name in _growing_cortical_update:
		_growing_cortical_update[send_button.name] = {}
	if key_name == "unit_id" and _cortical_area_refs != null and _cortical_area_refs.size() == 1:
		var current_unit_id: int = _cortical_area_refs[0].unit_id
		var new_unit_id: int = int(value)
		if new_unit_id == current_unit_id:
			if _growing_cortical_update[send_button.name].has(key_name):
				_growing_cortical_update[send_button.name].erase(key_name)
			if _growing_cortical_update[send_button.name].is_empty():
				_growing_cortical_update.erase(send_button.name)
				send_button.disabled = true
			return
	var original_value = value
	if value is Vector3i:
		value = FEAGIUtils.vector3i_to_array(value)
		if key_name == "visualization_voxel_granularity":
			print("🔵 UI: visualization_voxel_granularity changed from Vector3i %s to array %s" % [original_value, value])
	elif value is Vector3:
		value = FEAGIUtils.vector3_to_array(value)
	elif key_name == "neuron_excitability":
		# Convert from 0-100 percentage back to 0-1 range for FEAGI API
		value = float(value) / 100.0
	elif key_name == "neuron_leak_coefficient":
		# Convert from 0-100 percentage back to 0-1 range for FEAGI API
		value = float(value) / 100.0
	elif key_name == "neuron_leak_variability":
		# Convert from 0-100 percentage back to 0-1 range for FEAGI API
		value = float(value) / 100.0
	_growing_cortical_update[send_button.name][key_name] = value
	if key_name == "visualization_voxel_granularity":
		print("🔵 UI: Added %s = %s to update dict for button %s" % [key_name, value, send_button.name])
	send_button.disabled = false

func _send_update(send_button: Button) -> void:
	# Check if FeagiCore and requests are available
	if not FeagiCore or not FeagiCore.requests:
		print("UI: Cannot send update - FeagiCore or requests not available")
		return
	
	# CRITICAL: Block isvi updates if capacity would overflow
	if _is_isvi_segment and _isvi_would_overflow:
		print("🚨 BLOCKED UPDATE - Cannot apply: would exceed NPU capacity!")
		return
	
	if send_button.name in _growing_cortical_update:
		var update_data: Dictionary = _growing_cortical_update[send_button.name]
		if _should_confirm_unit_id_update(update_data):
			_show_unit_id_update_confirmation(update_data, send_button)
			return
		send_button.disabled = true
		if len(_cortical_area_refs) > 1:
			var area_names = []
			for area in _cortical_area_refs:
				area_names.append(area.cortical_ID)
			var area_names_str = ", ".join(area_names)  # Join array elements with commas
			print("UI: Attempting to update %d cortical areas %s with data: %s" % [len(_cortical_area_refs), area_names_str, update_data])
			
			var result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_areas(_cortical_area_refs, update_data)
			if result.has_errored:
				# Get detailed error information
				var error_details = result.decode_response_as_generic_error_code()
				var error_message = "Error Code: %s, Description: %s" % [error_details[0], error_details[1]]
				
				# Log detailed error information
				push_error("UI: Failed to update cortical areas %s. %s" % [area_names_str, error_message])
				print("UI: Update failed for cortical areas %s" % area_names_str)
				print("UI: - Update data sent: %s" % update_data)
				print("UI: - Error details: %s" % error_message)
				print("UI: - Has timed out: %s" % result.has_timed_out)
				print("UI: - Failed requirement: %s" % result.failed_requirement)
				print("UI: - Failed requirement key: %s" % result.failed_requirement_key)
				
				# Show popup with more detailed error message
				var detailed_popup_message = "FEAGI was unable to update cortical areas %s.\n\n%s\n\nCheck console for full details." % [area_names_str, error_message]
				BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup("Update Failed", detailed_popup_message))
				close_window()
			else:
				print("✅ UI: Successfully updated cortical areas %s" % area_names_str)
				print("🔵 UI: Refreshing UI from cache to show updated values...")
				# Refresh UI from cache to show updated values
				_refresh_all_relevant()
				print("🔵 UI: Refresh complete. Current visualization_voxel_granularity value: %s" % _cortical_area_refs[0].visualization_voxel_granularity)
		else:
			# Special handling for isvi segments - need to update all segments in the group
			if _is_isvi_segment and len(_isvi_all_segments) > 1:
				print("UI: Updating %d isvi segments..." % len(_isvi_all_segments))
				
				var success_count = 0
				var failed_areas = []
				
				# Send updates for all segments that have changes
				for segment in _isvi_all_segments:
					if segment.cortical_ID in _growing_cortical_update:
						var segment_update_data = _growing_cortical_update[segment.cortical_ID]
						var result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_area(segment.cortical_ID, segment_update_data)
						if result.has_errored:
							failed_areas.append(segment.cortical_ID)
						else:
							success_count += 1
				
				if len(failed_areas) > 0:
					var error_message = "Failed to update %d/%d isvi segments: %s" % [len(failed_areas), len(_isvi_all_segments), ", ".join(failed_areas)]
					BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup("Partial Update Failure", error_message))
				else:
					print("UI: Successfully updated all %d isvi segments" % success_count)
				# Refresh UI from cache to show updated values
				_refresh_all_relevant()
			else:
				# Normal single area update
				var cortical_id = _cortical_area_refs[0].cortical_ID
				var remaining_update_data = update_data.duplicate(true)
				var group_update_data: Dictionary = {}
				if update_data.has("unit_id"):
					group_update_data["unit_id"] = update_data["unit_id"]
					remaining_update_data.erase("unit_id")
				if not group_update_data.is_empty():
					var group_success = await _send_unit_group_update(send_button, group_update_data)
					if not group_success:
						send_button.disabled = false
						return
				if send_button == _button_coding_send:
					remaining_update_data = _finalize_neuron_coding_update(remaining_update_data, _cortical_area_refs[0])
					if remaining_update_data.is_empty():
						send_button.disabled = false
						return
					var new_id = remaining_update_data.get("new_cortical_id", "")
					if new_id != "":
						print("BV [NEURAL-CODING]: Requesting ID update %s -> %s" % [cortical_id, new_id])
				if remaining_update_data.is_empty():
					_refresh_all_relevant()
					_growing_cortical_update.clear()
					return
				print("UI: Attempting to update cortical area '%s' with data: %s" % [cortical_id, remaining_update_data])
				
				var result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_area(cortical_id, remaining_update_data)
				if result.has_errored:
					# Get detailed error information
					var error_details = result.decode_response_as_generic_error_code()
					var error_message = "Error Code: %s, Description: %s" % [error_details[0], error_details[1]]
					
					# Log detailed error information
					push_error("UI: Failed to update cortical area '%s'. %s" % [cortical_id, error_message])
					print("UI: Update failed for cortical area '%s'" % cortical_id)
					print("UI: - Update data sent: %s" % remaining_update_data)
					print("UI: - Error details: %s" % error_message)
					print("UI: - Has timed out: %s" % result.has_timed_out)
					print("UI: - Failed requirement: %s" % result.failed_requirement)
					print("UI: - Failed requirement key: %s" % result.failed_requirement_key)
					
					# Show popup with more detailed error message
					var detailed_popup_message = "FEAGI was unable to update cortical area '%s'.\n\n%s\n\nCheck console for full details." % [cortical_id, error_message]
					BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup("Update Failed", detailed_popup_message))
					close_window()
				else:
					print("✅ UI: Successfully updated cortical area '%s'" % cortical_id)
					print("🔵 UI: Refreshing UI from cache to show updated values...")
					# Refresh UI from cache to show updated values
					_refresh_all_relevant()
					if len(_cortical_area_refs) > 0:
						print("🔵 UI: Refresh complete. Current visualization_voxel_granularity value: %s" % _cortical_area_refs[0].visualization_voxel_granularity)
		
		# Clear the update dictionary
		_growing_cortical_update.clear()

func _should_confirm_unit_id_update(update_data: Dictionary) -> bool:
	if _skip_unit_id_confirmation:
		return false
	if len(_cortical_area_refs) != 1:
		return false
	if not _are_all_io_areas():
		return false
	if not update_data.has("unit_id"):
		return false
	return true

func _show_unit_id_update_confirmation(update_data: Dictionary, send_button: Button) -> void:
	var area = _cortical_area_refs[0]
	var member_names = _get_unit_group_member_names(area)
	var members_text = ""
	if member_names.is_empty():
		members_text = "- (no members found)"
	else:
		members_text = "- " + "\n- ".join(member_names)
	var unit_name = String(area.friendly_name)
	if unit_name.strip_edges() == "":
		unit_name = String(area.cortical_ID)
	var current_value = str(area.unit_id)
	var new_value = str(int(update_data.get("unit_id", area.unit_id)))
	var message = "You are about to change the Unit Index of %s from %s to %s.\nBe aware that changing the Unit ID of a subunit will require the change of all subunits.\n\nHere is the list of all impacted subunits:\n%s" % [unit_name, current_value, new_value, members_text]
	var confirm_action: Callable = _confirm_unit_id_update.bind(send_button)
	var popup: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_cancel_and_action_popup(
		"Confirm Unit Index Update",
		message,
		confirm_action,
		"Apply"
	)
	BV.WM.spawn_popup(popup)

func _confirm_unit_id_update(send_button: Button) -> void:
	_skip_unit_id_confirmation = true
	_send_update(send_button)
	_skip_unit_id_confirmation = false

func _send_unit_group_update(send_button: Button, update_data: Dictionary) -> bool:
	var area = _cortical_area_refs[0]
	var members = _get_unit_group_members(area)
	if members.is_empty():
		var message = "No unit group members were found for this unit. Unable to apply the Unit Index update."
		BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup("Update Failed", message))
		return false
	print("UI: Attempting to update unit group (%d areas) with data: %s" % [members.size(), update_data])
	var result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_areas(members, update_data)
	if result.has_errored:
		var error_details = result.decode_response_as_generic_error_code()
		var error_message = "Error Code: %s, Description: %s" % [error_details[0], error_details[1]]
		push_error("UI: Failed to update unit group. %s" % error_message)
		print("UI: Unit group update failed")
		print("UI: - Update data sent: %s" % update_data)
		print("UI: - Error details: %s" % error_message)
		print("UI: - Has timed out: %s" % result.has_timed_out)
		print("UI: - Failed requirement: %s" % result.failed_requirement)
		print("UI: - Failed requirement key: %s" % result.failed_requirement_key)
		var detailed_popup_message = "FEAGI was unable to update the unit group.\n\n%s\n\nCheck console for full details." % error_message
		BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup("Update Failed", detailed_popup_message))
		return false
	print("✅ UI: Successfully updated unit group")
	if update_data.has("unit_id"):
		await _refresh_unit_group_after_unit_id_update(area, update_data["unit_id"])
	_refresh_all_relevant()
	return true

func _refresh_unit_group_after_unit_id_update(area: AbstractCorticalArea, new_unit_id_value: Variant) -> void:
	if FeagiCore == null or FeagiCore.requests == null or FeagiCore.feagi_local_cache == null:
		return
	var new_unit_id = int(new_unit_id_value)
	var members = _get_unit_group_members(area)
	if members.is_empty():
		return
	var updated_areas: Array[AbstractCorticalArea] = []
	var selected_subunit_id = area.subunit_id
	for member in members:
		var new_id = _compute_unit_index_cortical_id(member.cortical_ID, new_unit_id)
		if new_id == "":
			continue
		FeagiCore.feagi_local_cache.FEAGI_remap_cortical_id(member.cortical_ID, new_id)
		var updated = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(new_id, null)
		if updated != null:
			updated_areas.append(updated)
	if not updated_areas.is_empty():
		var previous_suppress_state = FeagiCore.feagi_local_cache.cortical_areas.suppress_update_notifications
		FeagiCore.feagi_local_cache.cortical_areas.suppress_update_notifications = true
		await FeagiCore.requests.get_cortical_areas(updated_areas)
		FeagiCore.feagi_local_cache.cortical_areas.suppress_update_notifications = previous_suppress_state
		var selected_area = null
		for updated in updated_areas:
			if updated.subunit_id == selected_subunit_id:
				selected_area = updated
				break
		if selected_area != null:
			_cortical_area_refs = [selected_area]

func _compute_unit_index_cortical_id(cortical_id: StringName, new_unit_id: int) -> StringName:
	if not ClassDB.class_exists("FeagiDataDeserializer"):
		push_error("AdvancedCorticalProperties: FeagiDataDeserializer not available for unit ID computation")
		return ""
	var resolver: Object = ClassDB.instantiate("FeagiDataDeserializer")
	if resolver == null or not resolver.has_method("compute_io_cortical_id_with_unit_index"):
		push_error("AdvancedCorticalProperties: compute_io_cortical_id_with_unit_index not available")
		return ""
	var result: Dictionary = resolver.call("compute_io_cortical_id_with_unit_index", cortical_id, new_unit_id)
	if not result.get("success", false):
		push_error("AdvancedCorticalProperties: Failed to compute unit index cortical ID: %s" % result.get("error", "unknown"))
		return ""
	return StringName(result.get("cortical_id", ""))

func _get_unit_group_member_names(area: AbstractCorticalArea) -> Array[String]:
	var members = _get_unit_group_members(area)
	var names: Array[String] = []
	for cortical_area in members:
		var display_name = String(cortical_area.friendly_name)
		if display_name.strip_edges() == "":
			display_name = String(cortical_area.cortical_ID)
		names.append("%s (subunit %d)" % [display_name, cortical_area.subunit_id])
	names.sort()
	return names

func _get_unit_group_members(area: AbstractCorticalArea) -> Array[AbstractCorticalArea]:
	if FeagiCore == null or FeagiCore.feagi_local_cache == null:
		return []
	var all_areas = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.values()
	var members: Array[AbstractCorticalArea] = []
	for cortical_area in all_areas:
		if cortical_area.cortical_type != area.cortical_type:
			continue
		if cortical_area.unit_id != area.unit_id:
			continue
		members.append(cortical_area)
	return members
		

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

func _setup_bm_prevew() -> void:
	# Determine the cortical area context (if any)
	var existing_area = _cortical_area_refs[0] if _cortical_area_refs.size() == 1 else null
	
	# Host BM: ONLY the brain monitor representing the cortical area's direct parent region.
	# This intentionally ignores any additional scenes that may display the area as region I/O.
	var host_bm: UI_BrainMonitor_3DScene = null
	if existing_area and existing_area.current_parent_region:
		host_bm = BV.UI.get_brain_monitor_for_region(existing_area.current_parent_region)
	if host_bm == null:
		push_error("AdvancedCorticalProperties: No brain monitor found for cortical area's parent region; cannot create preview.")
		return
	
	var cortical_type = _cortical_area_refs[0].cortical_type if _cortical_area_refs.size() > 0 else AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN
	if _preview == null:
		# For isvi segments, don't connect move/resize signals - we handle updates manually via _on_isvi_layout_changed
		var moves: Array[Signal] = []
		var resizes: Array[Signal] = []
		if not _is_isvi_segment:
			moves.append(_vector_position.user_updated_vector)
			resizes.append(_vector_dimensions_spin.user_updated_vector)
		var closes: Array[Signal] = [close_window_requesed_no_arg, _button_summary_send.pressed]
		# Host uses area's actual FEAGI LFF
		# Don't auto-frame camera when opening properties of existing cortical area
		_preview = host_bm.create_preview(_vector_position.current_vector, _vector_dimensions_spin.current_vector, false, cortical_type, existing_area, false)
		_preview.connect_UI_signals(moves, resizes, closes)
		# Ensure main preview is cleared when window closes
		_preview.tree_exiting.connect(func(): _preview = null)
		_host_preview_bm = host_bm
		
		# For isvi segments, initialize previews for other segments only after the main preview exists.
		if _is_isvi_segment:
			# Cleanup any stale previews before recreating
			for preview in _isvi_segment_previews.values():
				if preview != null:
					preview.queue_free()
			_isvi_segment_previews.clear()
			_init_isvi_previews()
	else:
		# If host changed (tab switch), relocate main preview
		if _preview.get_parent() != host_bm._node_3D_root:
			_preview.queue_free()
			# For isvi segments, don't connect move/resize signals - we handle updates manually via _on_isvi_layout_changed
			var moves: Array[Signal] = []
			var resizes: Array[Signal] = []
			if not _is_isvi_segment:
				moves.append(_vector_position.user_updated_vector)
				resizes.append(_vector_dimensions_spin.user_updated_vector)
			# Don't auto-frame camera when reopening properties
			_preview = host_bm.create_preview(_vector_position.current_vector, _vector_dimensions_spin.current_vector, false, cortical_type, existing_area, false)
			_preview.connect_UI_signals(moves, resizes, [close_window_requesed_no_arg, _button_summary_send.pressed])
			_preview.tree_exiting.connect(func(): _preview = null)
			_host_preview_bm = host_bm
			
			# If host changed and this is an isvi segment, re-create segment previews in the new host BM.
			if _is_isvi_segment:
				for preview in _isvi_segment_previews.values():
					if preview != null:
						preview.queue_free()
				_isvi_segment_previews.clear()
				_init_isvi_previews()

## Gets the correct preview position - plate location for I/O areas, API coordinates for regular areas
func _get_preview_position_for_cortical_area() -> Vector3i:
	# Only works with single cortical area
	if _cortical_area_refs.size() != 1:
		return _vector_position.current_vector
	
	var cortical_area = _cortical_area_refs[0]
	
	# Check if this cortical area is I/O of any brain region with plates
	var root_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	if root_region == null:
		return _vector_position.current_vector
	
	# Check all child regions to see if this area is their I/O
	for child_region in root_region.contained_regions:
		# Check if cortical area is in this region's partial mappings (I/O)
		for partial_mapping in child_region.partial_mappings:
			if partial_mapping.internal_target_cortical_area == cortical_area:
				print("🔮 Cortical area %s is I/O of region %s - using plate position" % [cortical_area.cortical_ID, child_region.friendly_name])
				
				# Find the brain region 3D visualization to get plate coordinates
				var brain_monitor = BV.UI.temp_root_bm
				if brain_monitor == null:
					push_warning("AdvancedCorticalProperties: No brain monitor available for I/O area plate position calculation")
					return _vector_position.current_vector
				
				# Get the brain region 3D object (with robust ID matching)
				var brain_region_3d = brain_monitor._brain_region_visualizations_by_ID.get(child_region.region_ID)
				if brain_region_3d == null:
					for existing_id in brain_monitor._brain_region_visualizations_by_ID.keys():
						if str(existing_id) == str(child_region.region_ID):
							brain_region_3d = brain_monitor._brain_region_visualizations_by_ID[existing_id]
							break
				if brain_region_3d == null:
					print("🔮 Brain region 3D not found for %s - using API coordinates" % child_region.friendly_name)
					return _vector_position.current_vector
				
				# Generate I/O coordinates to get the plate position
				var io_coords = brain_region_3d.generate_io_coordinates_for_brain_region(child_region)
				# Search inputs, then outputs, then conflicts to handle conflict-plate areas
				var search_sets = [io_coords.inputs, io_coords.outputs, io_coords.conflicts]
				for set_arr in search_sets:
					for area_data in set_arr:
						if area_data.area_id == cortical_area.cortical_ID:
							print("🔮 Found plate coordinates (CENTER FEAGI) for %s: %s" % [cortical_area.cortical_ID, area_data.new_coordinates])
							# Convert center FEAGI coords to lower-left-front FEAGI (renderer expects LFF)
							var dims: Vector3i = _vector_dimensions_spin.current_vector
							var center: Vector3i = Vector3i(area_data.new_coordinates)
							var lff: Vector3i = Vector3i(center.x - dims.x / 2, center.y - dims.y / 2, center.z - dims.z / 2)
							return lff
	
	# Not an I/O area, use regular API coordinates
	return _vector_position.current_vector

# Helper: compute plate LFF coords for a given BM and area (unused path)
func _compute_plate_lff_for_bm(bm: UI_BrainMonitor_3DScene, area: AbstractCorticalArea) -> Vector3i:
	if bm == null or area == null:
		return _vector_position.current_vector
	var root_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	if root_region == null:
		return _vector_position.current_vector
	for child_region in root_region.contained_regions:
		for partial_mapping in child_region.partial_mappings:
			if partial_mapping.internal_target_cortical_area == area:
				var brain_region_3d = bm._brain_region_visualizations_by_ID.get(child_region.region_ID)
				if brain_region_3d == null:
					for existing_id in bm._brain_region_visualizations_by_ID.keys():
						if str(existing_id) == str(child_region.region_ID):
							brain_region_3d = bm._brain_region_visualizations_by_ID[existing_id]
							break
				if brain_region_3d == null:
					return _vector_position.current_vector
				var io_coords = brain_region_3d.generate_io_coordinates_for_brain_region(child_region)
				var search_sets = [io_coords.inputs, io_coords.outputs, io_coords.conflicts]
				for set_arr in search_sets:
					for area_data in set_arr:
						if area_data.area_id == area.cortical_ID:
							var dims: Vector3i = _vector_dimensions_spin.current_vector
							var center: Vector3i = Vector3i(area_data.new_coordinates)
							return Vector3i(center.x - dims.x / 2, center.y - dims.y / 2, center.z - dims.z / 2)
	return _vector_position.current_vector

## Handles dimension changes for I/O area previews - recalculates plate position since dimensions affect positioning
func _update_preview_for_io_area_resize(new_dimensions: Vector3i) -> void:
	if _preview == null:
		return
	
	# Skip for isvi segments - they use manual layout calculation via _on_isvi_layout_changed
	if _is_isvi_segment:
		return
	
	# For I/O areas, when dimensions change, the plate position might change too
	# Recalculate the preview position to ensure it stays on the plate
	var updated_plate_pos = _get_preview_position_for_cortical_area()
	# Host/tab preview must stay at the area's actual FEAGI LFF position
	_preview.set_new_position(_vector_position.current_vector)
	# Apply per-BM updated positions to auxiliary previews
	for aux in _aux_previews:
		if aux != null:
			var bm_for_aux: UI_BrainMonitor_3DScene = _aux_preview_to_bm.get(aux)
			if bm_for_aux == BV.UI.temp_root_bm:
				# Root/main: plate position
				aux.set_new_position(updated_plate_pos)
			else:
				# Region tab: area’s actual FEAGI LFF coordinate (no plate alignment)
				aux.set_new_position(_vector_position.current_vector)



#endregion


#region Neuron Coding

func _init_neuron_coding() -> void:
	if _section_neuron_coding == null:
		return
	if len(_cortical_area_refs) != 1:
		_section_neuron_coding.visible = false
		return
	_section_neuron_coding.visible = true
	_refresh_from_cache_neuron_coding()
	
	# Connect dropdowns
	if _dropdown_coding_signage != null:
		_dropdown_coding_signage.option_changed.connect(_on_coding_option_changed.unbind(1))
	if _dropdown_coding_behavior != null:
		_dropdown_coding_behavior.option_changed.connect(_on_coding_option_changed.unbind(1))
	if _dropdown_coding_type != null:
		_dropdown_coding_type.option_changed.connect(_on_coding_option_changed.unbind(1))
	
	if _button_coding_send != null:
		_button_coding_send.pressed.connect(_send_update.bind(_button_coding_send))

func _refresh_from_cache_neuron_coding() -> void:
	if len(_cortical_area_refs) != 1:
		return
	var area = _cortical_area_refs[0]
	if area.coding_signage_options.is_empty() or area.coding_behavior_options.is_empty() or area.coding_type_options.is_empty():
		_section_neuron_coding.visible = false
		return
	_section_neuron_coding.visible = true
	
	if _dropdown_coding_signage != null:
		_dropdown_coding_signage.options = area.coding_signage_options
		_dropdown_coding_signage.set_option(StringName(area.coding_signage))
	if _dropdown_coding_behavior != null:
		_dropdown_coding_behavior.options = area.coding_behavior_options
		_dropdown_coding_behavior.set_option(StringName(area.coding_behavior))
	if _dropdown_coding_type != null:
		_dropdown_coding_type.options = area.coding_type_options
		_dropdown_coding_type.set_option(StringName(area.coding_type))

func _on_coding_option_changed(_index: int) -> void:
	if _button_coding_send == null:
		return
	var update_data = _build_neuron_coding_update()
	if update_data.is_empty():
		return
	_growing_cortical_update[_button_coding_send.name] = update_data
	_button_coding_send.disabled = false

func _build_neuron_coding_update() -> Dictionary:
	if len(_cortical_area_refs) != 1:
		return {}
	var area = _cortical_area_refs[0]
	if area.cortical_type not in [
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU,
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU
	]:
		return {}
	
	if _dropdown_coding_signage == null or _dropdown_coding_behavior == null or _dropdown_coding_type == null:
		return {}
	
	var signage = String(_dropdown_coding_signage.selected_item)
	var behavior = String(_dropdown_coding_behavior.selected_item)
	var coding_type = String(_dropdown_coding_type.selected_item)
	
	return {
		"coding_signage": signage,
		"coding_behavior": behavior,
		"coding_type": coding_type
	}

func _finalize_neuron_coding_update(update_data: Dictionary, area: AbstractCorticalArea) -> Dictionary:
	var signage = update_data.get("coding_signage", "")
	var behavior = update_data.get("coding_behavior", "")
	var coding_type = update_data.get("coding_type", "")
	if signage == "" or behavior == "" or coding_type == "":
		return {}
	var resolver: Object = null
	if ClassDB.class_exists("FeagiDataDeserializer"):
		resolver = ClassDB.instantiate("FeagiDataDeserializer")
	if resolver == null or not resolver.has_method("compute_io_cortical_id"):
		push_error("AdvancedCorticalProperties: FeagiDataDeserializer not available for cortical ID computation")
		return {}
	var result: Dictionary = resolver.call("compute_io_cortical_id", area.cortical_ID, signage, behavior, coding_type)
	if !result.get("success", false):
		push_error("AdvancedCorticalProperties: Failed to compute cortical ID: %s" % result.get("error", "unknown"))
		return {}
	var new_id = result.get("cortical_id", "")
	if new_id == "":
		return {}
	update_data["new_cortical_id"] = new_id
	return update_data

#endregion
#region Summary

@export var _section_summary: VerticalCollapsibleHiding
@export var _line_cortical_name: TextInput
@export var _region_button: Button
@export var _line_cortical_ID: TextInput
@export var _line_unit_code: TextInput
@export var _line_unit_id: IntSpinBox
@export var _line_subunit_id: TextInput
@export var _line_cortical_type: TextInput
@export var _device_count_section: HBoxContainer
@export var _device_count: IntSpinBox
@export var _line_voxel_neuron_density: IntInput
@export var _line_synaptic_attractivity: IntInput
@export var _line_neuron_count: IntInput
@export var _line_incoming_synapse_count: IntInput
@export var _line_outgoing_synapse_count: IntInput
@export var _dropdown_io_preset: OptionButton
@export var _dimensions_label: Label
@export var _vector_dimensions_spin: Vector3iSpinboxField
@export var _vector_dimensions_nonspin: Vector3iField
@export var _vector_position: Vector3iSpinboxField
@export var _vector_visualization_voxel_granularity: Vector3iSpinboxField
@export var _button_summary_send: Button

# IPU/OPU-specific decoded ID fields (created programmatically)
var _ipu_opu_info_container: VBoxContainer = null

func _init_summary() -> void:
	var type: AbstractCorticalArea.CORTICAL_AREA_TYPE =  AbstractCorticalArea.array_oc_cortical_areas_type_identification(_cortical_area_refs)
	if type == AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN:
		_line_cortical_type.text = "Multiple Selected"
	else:
		_line_cortical_type.text = AbstractCorticalArea.cortical_type_to_str(type)
	
	# Create IPU/OPU-specific decoded ID info section (if applicable)
	_init_ipu_opu_decoded_info()
	_init_io_preset_dropdown()
	
	# Detect and setup isvi segment management
	_detect_and_setup_isvi_segment()
	var is_all_io = _are_all_io_areas()
	if _line_voxel_neuron_density != null:
		var voxel_row = _line_voxel_neuron_density.get_parent()
		if voxel_row != null:
			voxel_row.visible = not is_all_io
	if not is_all_io:
		_connect_control_to_update_button(_line_voxel_neuron_density, "cortical_neuron_per_vox_count", _button_summary_send)
	_connect_control_to_update_button(_line_synaptic_attractivity, "cortical_synaptic_attractivity", _button_summary_send)
	if _line_neuron_count != null:
		_line_neuron_count.editable = false
	if _line_incoming_synapse_count != null:
		_line_incoming_synapse_count.editable = false
	if _line_outgoing_synapse_count != null:
		_line_outgoing_synapse_count.editable = false
	
	# TODO renable region button, but check to make sure all types can be moved
	
	
	if len(_cortical_area_refs) != 1:
		_line_cortical_name.text = "Multiple Selected"
		_line_cortical_name.editable = false
		_region_button.text = "Multiple Selected"
		_line_cortical_ID.text = "Multiple Selected"
		if _line_unit_id != null:
			_line_unit_id.editable = false
			_line_unit_id.value = 0
		if _line_subunit_id != null:
			_line_subunit_id.text = "Multiple Selected"
		_vector_position.editable = false # TODO show multiple values
		if _vector_visualization_voxel_granularity != null:
			_vector_visualization_voxel_granularity.editable = false # TODO show multiple values
		_vector_dimensions_spin.visible = false
		_vector_dimensions_nonspin.visible = true
		_connect_control_to_update_button(_vector_dimensions_nonspin, "cortical_dimensions", _button_summary_send)
		# Note: visualization_voxel_granularity not connected for multi-select (read-only)

		
	else:
		# Single
		_connect_control_to_update_button(_line_cortical_name, "cortical_name", _button_summary_send)
		_connect_control_to_update_button(_vector_position, "coordinates_3d", _button_summary_send)
		if _vector_visualization_voxel_granularity != null:
			_connect_control_to_update_button(_vector_visualization_voxel_granularity, "visualization_voxel_granularity", _button_summary_send)
	if is_all_io and _line_unit_id != null:
		_line_unit_id.editable = true
		_connect_control_to_update_button(_line_unit_id, "unit_id", _button_summary_send)
		_vector_position.user_updated_vector.connect(_setup_bm_prevew.unbind(1))
		_vector_dimensions_spin.user_updated_vector.connect(_setup_bm_prevew.unbind(1))
		
		# Connect isvi layout handler for real-time updates
		if _is_isvi_segment:
			_vector_position.user_updated_vector.connect(_on_isvi_layout_changed.unbind(1))
			_vector_dimensions_spin.user_updated_vector.connect(_on_isvi_layout_changed.unbind(1))
		
		if _cortical_area_refs[0].cortical_type in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]:
			_connect_control_to_update_button(_device_count, "dev_count", _button_summary_send)
			_connect_control_to_update_button(_vector_dimensions_spin, "cortical_dimensions_per_device", _button_summary_send)
			_dimensions_label.text = "Dimensions Per Device"
		else:
			_connect_control_to_update_button(_vector_dimensions_spin, "cortical_dimensions", _button_summary_send)
		
	
	_button_summary_send.pressed.connect(_send_update.bind(_button_summary_send))

func _init_ipu_opu_decoded_info() -> void:
	# Only show decoded ID info for single IPU/OPU areas
	if len(_cortical_area_refs) != 1:
		return
	
	var area = _cortical_area_refs[0]
	if area.cortical_type not in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]:
		return
	# No decoded fields are shown in summary (subtype/unit removed)
	return
	
	# Find the parent container to insert our new section (after cortical type row)
	var cortical_type_row = _line_cortical_type.get_parent()
	var parent_container = cortical_type_row.get_parent()
	var insert_index = cortical_type_row.get_index() + 1
	
	# Create container for decoded ID info
	_ipu_opu_info_container = VBoxContainer.new()
	_ipu_opu_info_container.name = "IPU_OPU_Decoded_Info"
	parent_container.add_child(_ipu_opu_info_container)
	parent_container.move_child(_ipu_opu_info_container, insert_index)
	
	# Create label row helper
	var create_label_row = func(label_text: String, right_justify: bool = false) -> Label:
		var hbox = HBoxContainer.new()
		_ipu_opu_info_container.add_child(hbox)
		
		var title = Label.new()
		title.text = label_text
		title.custom_minimum_size.x = 120
		hbox.add_child(title)
		
		var value_label = Label.new()
		value_label.custom_minimum_size.x = 120
		if right_justify:
			value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(value_label)
		
		return value_label
	
	# Create all label rows (avoid duplicating coding info shown in Neuron Coding)

func _refresh_from_cache_summary() -> void:
	var is_all_io = _are_all_io_areas()
	if _line_voxel_neuron_density != null:
		var voxel_row = _line_voxel_neuron_density.get_parent()
		if voxel_row != null:
			voxel_row.visible = not is_all_io
	if not is_all_io:
		_update_control_with_value_from_areas(_line_voxel_neuron_density, "", "cortical_neuron_per_vox_count")
	_update_control_with_value_from_areas(_line_synaptic_attractivity, "", "cortical_synaptic_attractivity")
	_update_control_with_value_from_areas(_line_neuron_count, "", "reported_neuron_count")
	_update_control_with_value_from_areas(_line_incoming_synapse_count, "", "incoming_synapse_count")
	_update_control_with_value_from_areas(_line_outgoing_synapse_count, "", "outgoing_synapse_count")
	if _line_unit_id != null:
		var unit_row = _line_unit_id.get_parent()
		if unit_row != null:
			unit_row.visible = is_all_io
	if _line_subunit_id != null:
		var subunit_row = _line_subunit_id.get_parent()
		if subunit_row != null:
			subunit_row.visible = is_all_io
	
	# Debug: Check cortical_subtype value after refresh
	if len(_cortical_area_refs) == 1:
		var area = _cortical_area_refs[0]
	
	# Update IPU/OPU decoded ID info if applicable
	_refresh_ipu_opu_decoded_info()
	_refresh_io_preset()
	
	if len(_cortical_area_refs) != 1:
		_line_cortical_name.text = "Multiple Selected"
		_update_control_with_value_from_areas(_vector_dimensions_nonspin, "", "dimensions_3D")
		_update_control_with_value_from_areas(_vector_visualization_voxel_granularity, "", "visualization_voxel_granularity")
		if _line_unit_code != null:
			_line_unit_code.text = "Multiple Selected"
		if is_all_io and _line_unit_id != null:
			_line_unit_id.value = 0
		if is_all_io and _line_subunit_id != null:
			_line_subunit_id.text = "Multiple Selected"
		#TODO connect size vector
	else:
		# single
		_line_cortical_name.text = _cortical_area_refs[0].friendly_name
		_region_button.text = _cortical_area_refs[0].current_parent_region.friendly_name
		_line_cortical_ID.text = _cortical_area_refs[0].cortical_ID
		if _line_unit_code != null:
			if is_all_io:
				_line_unit_code.text = _cortical_area_refs[0].cortical_subtype
			else:
				_line_unit_code.text = "-"
		if _line_unit_id != null:
			if is_all_io:
				_line_unit_id.value = _cortical_area_refs[0].unit_id
		if _line_subunit_id != null:
			if is_all_io:
				_line_subunit_id.text = str(_cortical_area_refs[0].subunit_id)
		_vector_position.current_vector = _cortical_area_refs[0].coordinates_3D
		_vector_dimensions_spin.current_vector = _cortical_area_refs[0].dimensions_3D
		# Set visualization_voxel_granularity directly like position and dimensions
		if _vector_visualization_voxel_granularity != null:
			var granularity_value = _cortical_area_refs[0].visualization_voxel_granularity
			print("🔵 UI: Setting visualization_voxel_granularity in UI to: %s (from cache)" % granularity_value)
			_vector_visualization_voxel_granularity.current_vector = granularity_value
		if _cortical_area_refs[0].cortical_type in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]:
			_device_count_section.visible = true
			_update_control_with_value_from_areas(_device_count, "", "device_count")
			_update_control_with_value_from_areas(_vector_dimensions_spin, "", "cortical_dimensions_per_device")
		else:
			_update_control_with_value_from_areas(_vector_dimensions_spin, "", "dimensions_3D")
		# NOTE: 3D preview is intentionally NOT created on window open.
		# It will appear when the user starts editing position/dimensions.


func _init_io_preset_dropdown() -> void:
	if _dropdown_io_preset == null:
		print("IO PRESET DEBUG: dropdown node missing in init")
		return
	_reset_io_preset_items()
	_dropdown_io_preset.disabled = true
	# Force a valid selection so the dropdown renders text.
	_select_io_preset(IO_PRESET_INTERCONNECT)
	print("IO PRESET DEBUG: init items=%d selected=%d text='%s'" % [
		_dropdown_io_preset.item_count,
		_dropdown_io_preset.selected,
		_dropdown_io_preset.text
	])


func _reset_io_preset_items() -> void:
	if _dropdown_io_preset == null:
		return
	var preset_items: Array[StringName] = [
		IO_PRESET_INPUT,
		IO_PRESET_OUTPUT,
		IO_PRESET_INTERCONNECT,
		IO_PRESET_CONFLICT,
	]
	if _dropdown_io_preset is DropDown:
		var dropdown: DropDown = _dropdown_io_preset
		dropdown.options = preset_items
		var conflict_index = dropdown.options.find(IO_PRESET_CONFLICT)
		if conflict_index != -1:
			dropdown.set_item_disabled(conflict_index, true)
	else:
		_dropdown_io_preset.clear()
		for preset in preset_items:
			_dropdown_io_preset.add_item(preset)
		_dropdown_io_preset.set_item_disabled(_dropdown_io_preset.item_count - 1, true)


func _select_io_preset(label: StringName) -> void:
	if _dropdown_io_preset == null:
		return
	if _dropdown_io_preset is DropDown:
		var dropdown: DropDown = _dropdown_io_preset
		var index = dropdown.options.find(label)
		if index == -1:
			dropdown.options = [label]
			index = 0
		dropdown.select(index)
		dropdown.text = String(dropdown.get_item_text(index))
		return
	for i in range(_dropdown_io_preset.item_count):
		if _dropdown_io_preset.get_item_text(i) == label:
			_dropdown_io_preset.select(i)
			_dropdown_io_preset.text = String(label)
			return


func _refresh_io_preset() -> void:
	if _dropdown_io_preset == null:
		print("IO PRESET DEBUG: dropdown node missing on refresh")
		return
	if len(_cortical_area_refs) != 1:
		if _dropdown_io_preset is DropDown:
			var dropdown: DropDown = _dropdown_io_preset
			dropdown.options = [IO_PRESET_MULTI]
			dropdown.set_item_disabled(0, true)
			dropdown.select(0)
			dropdown.text = String(dropdown.get_item_text(0))
		else:
			_dropdown_io_preset.clear()
			_dropdown_io_preset.add_item(IO_PRESET_MULTI)
			_dropdown_io_preset.set_item_disabled(0, true)
			_dropdown_io_preset.select(0)
			_dropdown_io_preset.text = String(IO_PRESET_MULTI)
		_dropdown_io_preset.disabled = true
		print("IO PRESET DEBUG: multi-select items=%d selected=%d text='%s'" % [
			_dropdown_io_preset.item_count,
			_dropdown_io_preset.selected,
			_dropdown_io_preset.text
		])
		return

	_reset_io_preset_items()
	var area = _cortical_area_refs[0]
	var preset_data = _derive_io_preset_for_area(area)
	_select_io_preset(preset_data["preset"])
	_dropdown_io_preset.disabled = preset_data["locked"]
	if _dropdown_io_preset is DropDown:
		var dropdown: DropDown = _dropdown_io_preset
		print("IO PRESET DEBUG: items=%d selected=%d text='%s' options=%s" % [
			dropdown.item_count,
			dropdown.selected,
			dropdown.text,
			str(dropdown.options)
		])
	else:
		print("IO PRESET DEBUG: items=%d selected=%d text='%s'" % [
			_dropdown_io_preset.item_count,
			_dropdown_io_preset.selected,
			_dropdown_io_preset.text
		])


func _derive_io_preset_for_area(area: AbstractCorticalArea) -> Dictionary:
	var result := {
		"preset": IO_PRESET_INTERCONNECT,
		"locked": true,
	}

	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
		result["preset"] = IO_PRESET_INPUT
		return result
	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
		result["preset"] = IO_PRESET_OUTPUT
		return result

	if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE:
		var core_preset = _core_preset_from_id(area.cortical_ID)
		if core_preset != "":
			result["preset"] = core_preset
		return result

	var parent_region = area.current_parent_region
	if parent_region == null:
		return result

	var is_input = _is_region_input_area(parent_region, area)
	var is_output = _is_region_output_area(parent_region, area)
	if is_input and is_output:
		result["preset"] = IO_PRESET_CONFLICT
	elif is_input:
		result["preset"] = IO_PRESET_INPUT
	elif is_output:
		result["preset"] = IO_PRESET_OUTPUT
	else:
		result["preset"] = IO_PRESET_INTERCONNECT
	return result


func _core_preset_from_id(cortical_id: StringName) -> StringName:
	var id_str := String(cortical_id)
	var decoded := ""
	var raw = Marshalls.base64_to_raw(id_str)
	if raw.size() > 0:
		decoded = raw.get_string_from_utf8()
	var core_id = decoded if decoded != "" else id_str
	if core_id == "___power":
		return IO_PRESET_INPUT
	if core_id == "___death" or core_id == "___fatig":
		return IO_PRESET_OUTPUT
	return ""


func _is_region_input_area(region: BrainRegion, area: AbstractCorticalArea) -> bool:
	for link in region.input_open_chain_links:
		if link.destination == area and area in region.contained_cortical_areas:
			return true
	for mapping in region.partial_mappings:
		if mapping.is_region_input and mapping.internal_target_cortical_area == area:
			return true
	return false


func _is_region_output_area(region: BrainRegion, area: AbstractCorticalArea) -> bool:
	for link in region.output_open_chain_links:
		if link.source == area and area in region.contained_cortical_areas:
			return true
	for mapping in region.partial_mappings:
		if not mapping.is_region_input and mapping.internal_target_cortical_area == area:
			return true
	return false
			

func _user_press_edit_region() -> void:
	var config: SelectGenomeObjectSettings = SelectGenomeObjectSettings.config_for_single_brain_region_selection(FeagiCore.feagi_local_cache.brain_regions.get_root_region(), _cortical_area_refs[0].current_parent_region)
	var window: WindowSelectGenomeObject = BV.WM.spawn_select_genome_object(config)
	window.final_selection.connect(_user_edit_region)

func _user_edit_region(selected_objects: Array[GenomeObject]) -> void:
	_add_to_dict_to_send(selected_objects[0].genome_ID, _button_summary_send, "parent_region_id")

func _refresh_ipu_opu_decoded_info() -> void:
	# Only update if we have the UI elements and a single area
	if _ipu_opu_info_container == null or len(_cortical_area_refs) != 1:
		return
	
	# No decoded fields are shown in summary (subtype/unit removed)
	_ipu_opu_info_container.visible = false


func _enable_3D_preview(): #NOTE only currently works with single
		var move_signals: Array[Signal] = [_vector_position.user_updated_vector]
		var resize_signals: Array[Signal] = [_vector_dimensions_spin.user_updated_vector,  _vector_dimensions_nonspin.user_updated_vector]
		var preview_close_signals: Array[Signal] = [_button_summary_send.pressed, tree_exiting]
		# Use the brain monitor that is currently visualizing this cortical area (important for tabs!)
		var existing_area = _cortical_area_refs[0] if _cortical_area_refs.size() == 1 else null
		var active_bm = BV.UI.get_brain_monitor_for_cortical_area(existing_area)
		if active_bm == null:
			push_error("AdvancedCorticalProperties: No brain monitor available for 3D preview!")
			return
		var cortical_type = _cortical_area_refs[0].cortical_type if _cortical_area_refs.size() > 0 else AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN
		# Don't auto-frame camera when opening multi-select cortical properties
		var preview: UI_BrainMonitor_InteractivePreview = active_bm.create_preview(_vector_position.current_vector, _vector_dimensions_nonspin.current_vector, false, cortical_type, existing_area, false)
		preview.connect_UI_signals(move_signals, resize_signals, preview_close_signals)
		

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

@export var _section_neuron_coding: VerticalCollapsibleHiding
@export var _dropdown_coding_signage: DropDown
@export var _dropdown_coding_behavior: DropDown
@export var _dropdown_coding_type: DropDown
@export var _button_coding_send: Button


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
@export var _line_temporal_depth: IntInput
@export var _button_memory_send: Button

func _init_memory() -> void:
	_connect_control_to_update_button(_line_initial_neuron_lifespan, "neuron_init_lifespan", _button_memory_send)
	_connect_control_to_update_button(_line_lifespan_growth_rate, "neuron_lifespan_growth_rate", _button_memory_send)
	_connect_control_to_update_button(_line_longterm_memory_threshold, "neuron_longterm_mem_threshold", _button_memory_send)
	_connect_control_to_update_button(_line_temporal_depth, "temporal_depth", _button_memory_send)
	
	_button_memory_send.pressed.connect(_send_update.bind(_button_memory_send))

func _refresh_from_cache_memory() -> void:
	_update_control_with_value_from_areas(_line_initial_neuron_lifespan, "memory_parameters", "initial_neuron_lifespan")
	_update_control_with_value_from_areas(_line_lifespan_growth_rate, "memory_parameters", "lifespan_growth_rate")
	_update_control_with_value_from_areas(_line_longterm_memory_threshold, "memory_parameters", "longterm_memory_threshold")
	_update_control_with_value_from_areas(_line_temporal_depth, "memory_parameters", "temporal_depth")

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
	# Check if FeagiCore and requests are available
	if not FeagiCore or not FeagiCore.requests:
		print("UI: Cannot send monitoring update - FeagiCore or requests not available")
		return
	
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
	var delete_request: Callable = _safe_delete_afferent_mapping.bind(area, _cortical_area_refs[0])
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
	var delete_request: Callable = _safe_delete_efferent_mapping.bind(_cortical_area_refs[0], area)
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

func _user_pressed_reset_button() -> void:
	# Check if FeagiCore and requests are available
	if not FeagiCore or not FeagiCore.requests:
		print("UI: Cannot reset cortical areas - FeagiCore or requests not available")
		return
	
	FeagiCore.requests.mass_reset_cortical_areas(_cortical_area_refs)
	BV.NOTIF.add_notification("Reseting cortical areas...")
	close_window()

#endregion

#region Safe FEAGI Request Wrappers

func _safe_delete_afferent_mapping(source_area: AbstractCorticalArea, dest_area: AbstractCorticalArea) -> void:
	if not FeagiCore or not FeagiCore.requests:
		print("UI: Cannot delete afferent mapping - FeagiCore or requests not available")
		return
	var result: FeagiRequestOutput = await FeagiCore.requests.delete_mappings_between_corticals(source_area, dest_area)
	if result.has_errored:
		push_error("UI: Failed to delete afferent mapping %s -> %s" % [source_area.cortical_ID, dest_area.cortical_ID])
		return

func _safe_delete_efferent_mapping(source_area: AbstractCorticalArea, dest_area: AbstractCorticalArea) -> void:
	if not FeagiCore or not FeagiCore.requests:
		print("UI: Cannot delete efferent mapping - FeagiCore or requests not available")
		return
	var result: FeagiRequestOutput = await FeagiCore.requests.delete_mappings_between_corticals(source_area, dest_area)
	if result.has_errored:
		push_error("UI: Failed to delete efferent mapping %s -> %s" % [source_area.cortical_ID, dest_area.cortical_ID])
		return

#endregion

#region Segmented Vision (isvi) Layout Management

## Detect if this is an isvi segment and gather all segments in the group
func _detect_and_setup_isvi_segment() -> void:
	_is_isvi_segment = false
	_isvi_all_segments.clear()
	_isvi_original_z_values.clear()
	
	if len(_cortical_area_refs) != 1:
		return
	
	var area = _cortical_area_refs[0]
	
	# Check if this is an isvi segment
	if area.cortical_subtype != "isvi":
		return
	
	_is_isvi_segment = true
	_isvi_unit_id = area.unit_id
	
	# Find all 9 segments in this group
	var all_cortical_areas = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.values()
	
	# Search for isvi segments in our group
	var isvi_count = 0
	for cortical_area in all_cortical_areas:
		if cortical_area.cortical_subtype == "isvi":
			isvi_count += 1
			if cortical_area.unit_id == _isvi_unit_id:
				_isvi_all_segments.append(cortical_area)
				# Capture original z value for this segment
				_isvi_original_z_values[cortical_area.subunit_id] = cortical_area.coordinates_3D.z
	
	print("UI: isvi segment detected - Subunit ", area.subunit_id, " in Unit ", area.unit_id, " (", len(_isvi_all_segments), " total segments)")

## Calculate layout positions (x, y only) for all segments in an isvi group
## Returns Dictionary of subunit_id -> Vector2i (x, y position)
## Note: Z coordinates are NOT calculated - caller must preserve original z values
func _calculate_isvi_layout(center_pos: Vector3i, center_dims: Vector3i, peripheral_dims: Vector3i) -> Dictionary:
	var layout = {}
	
	# Gap = max of peripheral width/height
	var gap = maxi(peripheral_dims.x, peripheral_dims.y)
	
	# Center (subunit_id=4) stays at its position (x, y only)
	layout[4] = Vector2i(center_pos.x, center_pos.y)
	
	# Unit ID layout:
	# [6:TL] [7:TC] [8:TR]
	# [3:ML] [4:CC] [5:MR]
	# [0:BL] [1:BC] [2:BR]
	
	var center_x = center_pos.x
	var center_y = center_pos.y
	
	# Bottom row (y = center_y - peripheral_dims.y - gap)
	var bottom_y = center_y - peripheral_dims.y - gap
	layout[0] = Vector2i(center_x - peripheral_dims.x - gap, bottom_y)  # Bottom-Left
	layout[1] = Vector2i(center_x + (center_dims.x - peripheral_dims.x) / 2, bottom_y)  # Bottom-Center
	layout[2] = Vector2i(center_x + center_dims.x + gap, bottom_y)  # Bottom-Right
	
	# Middle row (y = vertically centered with center segment)
	var middle_y = center_y + (center_dims.y - peripheral_dims.y) / 2
	layout[3] = Vector2i(center_x - peripheral_dims.x - gap, middle_y)  # Middle-Left
	layout[5] = Vector2i(center_x + center_dims.x + gap, middle_y)  # Middle-Right
	
	# Top row (y = center_y + center_dims.y + gap)
	var top_y = center_y + center_dims.y + gap
	layout[6] = Vector2i(center_x - peripheral_dims.x - gap, top_y)  # Top-Left
	layout[7] = Vector2i(center_x + (center_dims.x - peripheral_dims.x) / 2, top_y)  # Top-Center
	layout[8] = Vector2i(center_x + center_dims.x + gap, top_y)  # Top-Right
	
	return layout

## Check if resizing isvi segments would exceed NPU capacity
## Returns true if would overflow, false if safe
func _check_isvi_resize_capacity(center_dims: Vector3i, peripheral_dims: Vector3i, editing_center: bool) -> bool:
	# Get health check data from cache properties
	var neuron_max: int = FeagiCore.feagi_local_cache.neuron_count_max
	var neuron_current: int = FeagiCore.feagi_local_cache.neuron_count_current
	
	if neuron_max <= 0 or neuron_current < 0:
		return false  # Allow if capacity data unavailable
	
	# Calculate neuron delta
	var old_neuron_count: int = 0
	var new_neuron_count: int = 0
	
	# Find center and a peripheral segment
	var center_segment: AbstractCorticalArea = null
	var peripheral_segment: AbstractCorticalArea = null
	for segment in _isvi_all_segments:
		if segment.subunit_id == 4:
			center_segment = segment
		elif segment.subunit_id == 0:
			peripheral_segment = segment
	
	if not center_segment or not peripheral_segment:
		return false  # Can't check without segments
	
	if editing_center:
		# Editing center - only center neurons change
		var old_center_dims = center_segment.dimensions_3D
		old_neuron_count = old_center_dims.x * old_center_dims.y * old_center_dims.z
		new_neuron_count = center_dims.x * center_dims.y * center_dims.z
	else:
		# Editing peripheral - all 8 peripherals change
		var old_peripheral_dims = peripheral_segment.dimensions_3D
		old_neuron_count = old_peripheral_dims.x * old_peripheral_dims.y * old_peripheral_dims.z * 8
		new_neuron_count = peripheral_dims.x * peripheral_dims.y * peripheral_dims.z * 8
	
	var neuron_delta = new_neuron_count - old_neuron_count
	var projected_total = neuron_current + neuron_delta
	
	# Check against backend-reported max (no frontend safety margin)
	# Backend is responsible for enforcing its own capacity limits and overhead
	if projected_total > neuron_max:
		print("🚨 NPU CAPACITY OVERFLOW - Projected: %d/%d neurons (%.1f%% capacity)" % [projected_total, neuron_max, (float(projected_total) / neuron_max) * 100.0])
		return true  # Would overflow
	
	return false  # Safe to proceed

## Initialize previews for all isvi segments (called on first load)
func _init_isvi_previews() -> void:
	if not _is_isvi_segment or len(_isvi_all_segments) == 0:
		return
	
	if not _preview or not _host_preview_bm:
		return
	
	# Create previews for all OTHER segments (not the one being edited) at their CURRENT positions
	for segment in _isvi_all_segments:
		# Skip the segment being edited (it's already shown via the main preview)
		if segment.cortical_ID == _cortical_area_refs[0].cortical_ID:
			continue
		
		# Create preview at segment's CURRENT position and dimensions
		var segment_pos = segment.coordinates_3D
		var segment_dims = segment.dimensions_3D
		var cortical_type = segment.cortical_type
		var closes_only: Array[Signal] = [close_window_requesed_no_arg, _button_summary_send.pressed]
		
		# Don't auto-frame camera when creating isvi segment previews
		var new_preview = _host_preview_bm.create_preview(segment_pos, segment_dims, false, cortical_type, segment, false)
		new_preview.connect_UI_signals([], [], closes_only)
		
		# Store this preview
		_isvi_segment_previews[segment.subunit_id] = new_preview
		
		# Cleanup when it's destroyed
		var subunit_id_copy = segment.subunit_id  # Capture for closure
		new_preview.tree_exiting.connect(func(): _isvi_segment_previews.erase(subunit_id_copy))

## Triggered when dimensions or position change for an isvi segment
func _on_isvi_layout_changed() -> void:
	if not _is_isvi_segment or len(_isvi_all_segments) == 0:
		return
	
	# Get the segment being edited
	var edited_segment = _cortical_area_refs[0]
	
	# Calculate position delta (for synchronized movement)
	var old_pos = edited_segment.coordinates_3D
	var new_pos = _vector_position.current_vector
	var position_delta = new_pos - old_pos
	
	
	# Get center segment and a peripheral segment for dimension calculations
	var center_segment: AbstractCorticalArea = null
	var peripheral_segment: AbstractCorticalArea = null
	
	for segment in _isvi_all_segments:
		if segment.subunit_id == 4:
			center_segment = segment
		elif segment.subunit_id == 0:
			peripheral_segment = segment
	
	if not center_segment or not peripheral_segment:
		print("UI: Cannot calculate isvi layout - missing segments")
		return
	
	# Get current dimensions from UI or cache
	var center_dims: Vector3i
	var peripheral_dims: Vector3i
	
	if edited_segment.subunit_id == 4:
		# Editing center segment
		center_dims = _vector_dimensions_spin.current_vector
		peripheral_dims = peripheral_segment.dimensions_3D
	else:
		# Editing peripheral segment
		center_dims = center_segment.dimensions_3D
		peripheral_dims = _vector_dimensions_spin.current_vector
	
	# Check if dimensions changed (for layout recalculation)
	var dims_changed = false
	if edited_segment.subunit_id == 4:
		dims_changed = (center_dims != center_segment.dimensions_3D)
	else:
		dims_changed = (peripheral_dims != peripheral_segment.dimensions_3D)
	
	# Check NPU capacity if dimensions changed
	if dims_changed:
		# Refresh health data before capacity check to ensure accuracy
		await FeagiCore.requests.single_health_check_call(true)
		_isvi_would_overflow = _check_isvi_resize_capacity(center_dims, peripheral_dims, edited_segment.subunit_id == 4)
	else:
		_isvi_would_overflow = false  # Movement doesn't change neuron count
	
	var new_layout: Dictionary
	
	if dims_changed:
		# Dimensions changed - recalculate layout based on new center position
		new_layout = _calculate_isvi_layout(new_pos if edited_segment.subunit_id == 4 else center_segment.coordinates_3D, center_dims, peripheral_dims)
	else:
		# Only position changed - apply delta to all segments
		new_layout = {}
		for segment in _isvi_all_segments:
			new_layout[segment.subunit_id] = segment.coordinates_3D + position_delta
	
	# Update positions for all segments (add to pending updates)
	for segment in _isvi_all_segments:
		if segment.subunit_id in new_layout:
			var pos_dict: Dictionary
			
			if dims_changed:
				# Dimensions changed (resizing) - layout returns Vector2i, preserve ORIGINAL z
				var xy_pos: Vector2i = new_layout[segment.subunit_id]
				var original_z = _isvi_original_z_values.get(segment.subunit_id, segment.coordinates_3D.z)
				pos_dict = {"x": xy_pos.x, "y": xy_pos.y, "z": original_z}
			else:
				# Only position changed (movement) - layout returns Vector3i with delta applied
				var xyz_pos: Vector3i = new_layout[segment.subunit_id]
				pos_dict = {"x": xyz_pos.x, "y": xyz_pos.y, "z": xyz_pos.z}
			
			# Add to update dict for this specific cortical area
			if not (segment.cortical_ID in _growing_cortical_update):
				_growing_cortical_update[segment.cortical_ID] = {}
			_growing_cortical_update[segment.cortical_ID]["coordinates_3d"] = pos_dict
	
	# Also update dimension for all peripherals ONLY IF dimensions actually changed
	if _cortical_area_refs[0].subunit_id != 4 and dims_changed:
		for segment in _isvi_all_segments:
			if segment.subunit_id != 4:  # All peripherals
				if not (segment.cortical_ID in _growing_cortical_update):
					_growing_cortical_update[segment.cortical_ID] = {}
				_growing_cortical_update[segment.cortical_ID]["cortical_dimensions"] = {
					"x": peripheral_dims.x,
					"y": peripheral_dims.y,
					"z": peripheral_dims.z
				}
	
	# Enable/disable the update button based on overflow state
	_button_summary_send.disabled = _isvi_would_overflow
	
	# Update button tooltip to show warning
	if _isvi_would_overflow:
		_button_summary_send.tooltip_text = "⚠️ Cannot apply: Resize would exceed NPU capacity!\nReduce dimensions or free up neurons elsewhere."
	else:
		_button_summary_send.tooltip_text = "Apply changes to FEAGI"
	
	# Update previews visually
	_update_isvi_visual_previews(new_layout, center_dims, peripheral_dims, dims_changed)
	
	if _isvi_would_overflow:
		print("UI: ⚠️ WARNING - isvi layout would exceed NPU capacity! Apply button disabled.")
	else:
		print("UI: isvi layout updated - ", len(new_layout), " segments repositioned")

## Update visual previews for all isvi segments
func _update_isvi_visual_previews(layout: Dictionary, center_dims: Vector3i, peripheral_dims: Vector3i, is_resize: bool) -> void:
	if not _preview or not _host_preview_bm:
		return
	
	# Update main preview for the segment being edited
	if _cortical_area_refs[0].subunit_id in layout:
		var preview_pos: Vector3i
		
		if is_resize:
			# Resizing - layout returns Vector2i (x, y), add ORIGINAL z
			var xy_pos: Vector2i = layout[_cortical_area_refs[0].subunit_id]
			var original_z = _isvi_original_z_values.get(_cortical_area_refs[0].subunit_id, _cortical_area_refs[0].coordinates_3D.z)
			preview_pos = Vector3i(xy_pos.x, xy_pos.y, original_z)
		else:
			# Movement - layout returns Vector3i with delta applied
			preview_pos = layout[_cortical_area_refs[0].subunit_id]
		
		_preview.set_new_position(preview_pos)
		if _cortical_area_refs[0].subunit_id == 4:
			_preview.set_new_dimensions(center_dims)
		else:
			_preview.set_new_dimensions(peripheral_dims)
		
		# Set warning color if would overflow
		_preview.set_warning_state(_isvi_would_overflow)
	
	# Create or update previews for ALL segments in the group
	# Note: The main preview handles the segment being edited, so we create previews for the other 8
	for segment in _isvi_all_segments:
		
		# Skip the segment being edited - it's already shown via the main preview
		if segment.cortical_ID == _cortical_area_refs[0].cortical_ID:
			continue
		
		if segment.subunit_id not in layout:
			continue
		
		var segment_pos_final: Vector3i
		
		if is_resize:
			# Resizing - layout returns Vector2i (x, y), add ORIGINAL z
			var xy_pos: Vector2i = layout[segment.subunit_id]
			var original_z = _isvi_original_z_values.get(segment.subunit_id, segment.coordinates_3D.z)
			segment_pos_final = Vector3i(xy_pos.x, xy_pos.y, original_z)
		else:
			# Movement - layout returns Vector3i with delta applied
			segment_pos_final = layout[segment.subunit_id]
		
		var segment_dims = center_dims if segment.subunit_id == 4 else peripheral_dims
		
		
		# Check if we already have a preview for this segment
		if segment.subunit_id in _isvi_segment_previews:
			var existing_preview = _isvi_segment_previews[segment.subunit_id]
			if existing_preview != null:
				existing_preview.set_new_position(segment_pos_final)
				existing_preview.set_new_dimensions(segment_dims)
				existing_preview.set_warning_state(_isvi_would_overflow)
			else:
				# Preview was deleted, remove from dict
				_isvi_segment_previews.erase(segment.subunit_id)
		else:
			# Create new preview for this segment
			var cortical_type = segment.cortical_type
			var closes_only: Array[Signal] = [close_window_requesed_no_arg, _button_summary_send.pressed]
			# Don't auto-frame camera when creating isvi segment previews during layout changes
			var new_preview = _host_preview_bm.create_preview(segment_pos_final, segment_dims, false, cortical_type, segment, false)
			new_preview.connect_UI_signals([], [], closes_only)
			new_preview.set_warning_state(_isvi_would_overflow)
			
			# Store this preview
			_isvi_segment_previews[segment.subunit_id] = new_preview
			
			# Cleanup when it's destroyed
			var subunit_id_copy = segment.subunit_id  # Capture for closure
			new_preview.tree_exiting.connect(func(): _isvi_segment_previews.erase(subunit_id_copy))

#endregion
