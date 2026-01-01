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
var _preview: UI_BrainMonitor_InteractivePreview
var _aux_previews: Array[UI_BrainMonitor_InteractivePreview] = []
var _aux_preview_to_bm: Dictionary = {}
var _host_preview_bm: UI_BrainMonitor_3DScene = null

# isvi segmented vision variables
var _is_isvi_segment: bool = false
var _isvi_unit_id: int = -1  # Cortical unit index (which unit of this type)
var _isvi_all_segments: Array[AbstractCorticalArea] = []
var _isvi_segment_previews: Dictionary = {}  # Maps unit_id to preview object
var _isvi_original_z_values: Dictionary = {}  # Maps unit_id to original z coordinate (captured at detection)
var _isvi_would_overflow: bool = false  # True if current resize would exceed NPU capacity


func _ready():
	super()
	BV.UI.selection_system.add_override_usecase(SelectionSystem.OVERRIDE_USECASE.CORTICAL_PROPERTIES)

	

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
	# Only if FeagiCore is ready and network components are initialized
	if FeagiCore and FeagiCore.requests and FeagiCore.can_interact_with_feagi() and FeagiCore.network and FeagiCore.network.http_API and FeagiCore.network.http_API.address_list:
		await FeagiCore.requests.get_cortical_areas(_cortical_area_refs)
	else:
		print("UI: Advanced Cortical Properties - Skipping FEAGI update request as network is not ready")
	
	# refresh all relevant sections again
	_refresh_all_relevant()
	
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
				await FeagiCore.requests.get_cortical_areas(all_vision_segments)
				
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
	if control is IntSpinBox:
		(control as IntSpinBox).value = value
		

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
		send_button.disabled = true
		if len(_cortical_area_refs) > 1:
			var area_names = []
			for area in _cortical_area_refs:
				area_names.append(area.cortical_ID)
			var area_names_str = ", ".join(area_names)  # Join array elements with commas
			var update_data = _growing_cortical_update[send_button.name]
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
				print("UI: Successfully updated cortical areas %s" % area_names_str)
				# Refresh UI from cache to show updated values
				_refresh_all_relevant()
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
				var update_data = _growing_cortical_update[send_button.name]
				print("UI: Attempting to update cortical area '%s' with data: %s" % [cortical_id, update_data])
				
				var result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_area(cortical_id, update_data)
				if result.has_errored:
					# Get detailed error information
					var error_details = result.decode_response_as_generic_error_code()
					var error_message = "Error Code: %s, Description: %s" % [error_details[0], error_details[1]]
					
					# Log detailed error information
					push_error("UI: Failed to update cortical area '%s'. %s" % [cortical_id, error_message])
					print("UI: Update failed for cortical area '%s'" % cortical_id)
					print("UI: - Update data sent: %s" % update_data)
					print("UI: - Error details: %s" % error_message)
					print("UI: - Has timed out: %s" % result.has_timed_out)
					print("UI: - Failed requirement: %s" % result.failed_requirement)
					print("UI: - Failed requirement key: %s" % result.failed_requirement_key)
					
					# Show popup with more detailed error message
					var detailed_popup_message = "FEAGI was unable to update cortical area '%s'.\n\n%s\n\nCheck console for full details." % [cortical_id, error_message]
					BV.WM.spawn_popup(ConfigurablePopupDefinition.create_single_button_close_popup("Update Failed", detailed_popup_message))
					close_window()
				else:
					print("UI: Successfully updated cortical area '%s'" % cortical_id)
					# Refresh UI from cache to show updated values
					_refresh_all_relevant()
		
		# Clear the update dictionary
		_growing_cortical_update.clear()
		

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
	# CRITICAL FIX: Use plate location for I/O areas, not API coordinates
	var preview_position = _get_preview_position_for_cortical_area()
	
	# Determine the cortical area context (if any)
	var existing_area = _cortical_area_refs[0] if _cortical_area_refs.size() == 1 else null
	
	# Host BM: the one that contains this area (child-of); receives both MOVE and RESIZE
	var host_bm: UI_BrainMonitor_3DScene = null
	if existing_area and existing_area.current_parent_region:
		host_bm = BV.UI.get_brain_monitor_for_region(existing_area.current_parent_region)
	if host_bm == null:
		host_bm = BV.UI.get_brain_monitor_for_cortical_area(existing_area)
	if host_bm == null:
		push_error("AdvancedCorticalProperties: No brain monitor available for preview creation!")
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
	
	# Clear any stale aux mirrors before recreating
	for aux in _aux_previews:
		if aux != null:
			aux.queue_free()
	_aux_previews.clear()
	_aux_preview_to_bm.clear()
	
	# Resize-only auxiliary previews: show on all visible 3D scenes as per rule
	var closes_only: Array[Signal] = [close_window_requesed_no_arg, _button_summary_send.pressed]
	var resizes_only: Array[Signal] = [_vector_dimensions_spin.user_updated_vector]
	# Mirror to all visible brain monitors that would display this area (directly or as I/O), excluding host
	var all_visible := BV.UI.get_all_visible_brain_monitors()
	for bm in all_visible:
		if bm == null or bm == host_bm:
			continue
		if existing_area == null or BV.UI._would_brain_monitor_accept_cortical_area(bm, existing_area):
			var per_bm_position: Vector3i
			if bm == BV.UI.temp_root_bm:
				# Root/main: plate-aligned position
				per_bm_position = _get_preview_position_for_cortical_area()
			else:
				# Region tab: actual FEAGI LFF
				per_bm_position = _vector_position.current_vector
			# Don't auto-frame camera for auxiliary previews
			var mirror = bm.create_preview(per_bm_position, _vector_dimensions_spin.current_vector, false, cortical_type, existing_area, false)
			mirror.connect_UI_signals([], resizes_only, closes_only)
			mirror.tree_exiting.connect(func(): _aux_previews.erase(mirror); _aux_preview_to_bm.erase(mirror))
			_aux_previews.append(mirror)
			_aux_preview_to_bm[mirror] = bm
	
	# CRITICAL: Also connect to resize signal to update preview position for I/O areas (keeps center aligned on plates)
	# Skip for isvi segments - they use manual layout calculation
	if not _is_isvi_segment and not _vector_dimensions_spin.user_updated_vector.is_connected(_update_preview_for_io_area_resize):
		_vector_dimensions_spin.user_updated_vector.connect(_update_preview_for_io_area_resize)

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


#region Summary

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

# IPU/OPU-specific decoded ID fields (created programmatically)
var _ipu_opu_info_container: VBoxContainer = null
var _label_cortical_subtype: Label = null
var _label_encoding_type: Label = null
var _label_encoding_format: Label = null
var _label_unit_id: Label = null

func _init_summary() -> void:
	var type: AbstractCorticalArea.CORTICAL_AREA_TYPE =  AbstractCorticalArea.array_oc_cortical_areas_type_identification(_cortical_area_refs)
	if type == AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN:
		_line_cortical_type.text = "Multiple Selected"
	else:
		_line_cortical_type.text = AbstractCorticalArea.cortical_type_to_str(type)
	
	# Create IPU/OPU-specific decoded ID info section (if applicable)
	_init_ipu_opu_decoded_info()
	
	# Detect and setup isvi segment management
	_detect_and_setup_isvi_segment()
	
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
	
	# Create all label rows (removed "Cortical" prefix, swapped Unit/Group order)
	_label_cortical_subtype = create_label_row.call("Subtype:")
	var encoding_label = "Encoding:" if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU else "Decoding:"
	_label_encoding_type = create_label_row.call(encoding_label)
	_label_encoding_format = create_label_row.call("Format:")
	_label_unit_id = create_label_row.call("Unit ID:", true)  # Swapped order, right-justified
	_label_unit_id = create_label_row.call("Unit ID:", true)    # Swapped order, right-justified

func _refresh_from_cache_summary() -> void:
	
	_update_control_with_value_from_areas(_line_voxel_neuron_density, "", "cortical_neuron_per_vox_count")
	_update_control_with_value_from_areas(_line_synaptic_attractivity, "", "cortical_synaptic_attractivity")
	
	# Debug: Check cortical_subtype value after refresh
	if len(_cortical_area_refs) == 1:
		var area = _cortical_area_refs[0]
	
	# Update IPU/OPU decoded ID info if applicable
	_refresh_ipu_opu_decoded_info()
	
	if len(_cortical_area_refs) != 1:
		_line_cortical_name.text = "Multiple Selected"
		_update_control_with_value_from_areas(_vector_dimensions_nonspin, "", "dimensions_3D")
		#TODO connect size vector
	else:
		# single
		_line_cortical_name.text = _cortical_area_refs[0].friendly_name
		_region_button.text = _cortical_area_refs[0].current_parent_region.friendly_name
		_line_cortical_ID.text = _cortical_area_refs[0].cortical_ID
		_vector_position.current_vector = _cortical_area_refs[0].coordinates_3D
		_vector_dimensions_spin.current_vector = _cortical_area_refs[0].dimensions_3D
		if _cortical_area_refs[0].cortical_type in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]:
			_device_count_section.visible = true
			_update_control_with_value_from_areas(_device_count, "", "device_count")
			_update_control_with_value_from_areas(_vector_dimensions_spin, "", "cortical_dimensions_per_device")
		else:
			_update_control_with_value_from_areas(_vector_dimensions_spin, "", "dimensions_3D")
		
		# Set up preview for this cortical area
		_setup_bm_prevew()
		
		# If this is an isvi segment, also set up previews for all other segments
		if _is_isvi_segment:
			_init_isvi_previews()
			

func _user_press_edit_region() -> void:
	var config: SelectGenomeObjectSettings = SelectGenomeObjectSettings.config_for_single_brain_region_selection(FeagiCore.feagi_local_cache.brain_regions.get_root_region(), _cortical_area_refs[0].current_parent_region)
	var window: WindowSelectGenomeObject = BV.WM.spawn_select_genome_object(config)
	window.final_selection.connect(_user_edit_region)

func _user_edit_region(selected_objects: Array[GenomeObject]) -> void:
	_add_to_dict_to_send(selected_objects[0].genome_ID, _button_summary_send, "parent_region_id")

func _refresh_ipu_opu_decoded_info() -> void:
	# Only update if we have the UI elements and a single area
	if _label_cortical_subtype == null or len(_cortical_area_refs) != 1:
		return
	
	var area = _cortical_area_refs[0]
	
	# Check if decoded info is available
	if area.has_decoded_id_info:
		_label_cortical_subtype.text = area.cortical_subtype
		_label_encoding_type.text = area.encoding_type
		_label_encoding_format.text = area.encoding_format
		_label_unit_id.text = str(area.group_id)  # group_id property stores unit index
		_label_unit_id.text = str(area.unit_id)    # Swapped order
		
		# Make container visible
		if _ipu_opu_info_container:
			_ipu_opu_info_container.visible = true
	else:
		# Hide if no decoded info available yet
		if _ipu_opu_info_container:
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
	_isvi_unit_id = area.group_id  # group_id property stores unit index
	_isvi_unit_id = area.unit_id
	
	# Find all 9 segments in this group
	var all_cortical_areas = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.values()
	
	# Search for isvi segments in our group
	var isvi_count = 0
	for cortical_area in all_cortical_areas:
		if cortical_area.cortical_subtype == "isvi":
			isvi_count += 1
			if cortical_area.group_id == _isvi_unit_id:  # group_id property stores unit index
				_isvi_all_segments.append(cortical_area)
				# Capture original z value for this segment
				_isvi_original_z_values[cortical_area.unit_id] = cortical_area.coordinates_3D.z
	
	print("UI: isvi segment detected - Subunit ", _isvi_unit_id, " in Unit ", area.group_id, " (", len(_isvi_all_segments), " total segments)")

## Calculate layout positions (x, y only) for all segments in an isvi group
## Returns Dictionary of unit_id -> Vector2i (x, y position)
## Note: Z coordinates are NOT calculated - caller must preserve original z values
func _calculate_isvi_layout(center_pos: Vector3i, center_dims: Vector3i, peripheral_dims: Vector3i) -> Dictionary:
	var layout = {}
	
	# Gap = max of peripheral width/height
	var gap = maxi(peripheral_dims.x, peripheral_dims.y)
	
	# Center (unit_id=4) stays at its position (x, y only)
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
		if segment.unit_id == 4:
			center_segment = segment
		elif segment.unit_id == 0:
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
		_isvi_segment_previews[segment.unit_id] = new_preview
		
		# Cleanup when it's destroyed
		var unit_id_copy = segment.unit_id  # Capture for closure
		new_preview.tree_exiting.connect(func(): _isvi_segment_previews.erase(unit_id_copy))

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
		if segment.unit_id == 4:
			center_segment = segment
		elif segment.unit_id == 0:
			peripheral_segment = segment
	
	if not center_segment or not peripheral_segment:
		print("UI: Cannot calculate isvi layout - missing segments")
		return
	
	# Get current dimensions from UI or cache
	var center_dims: Vector3i
	var peripheral_dims: Vector3i
	
	if edited_segment.unit_id == 4:
		# Editing center segment
		center_dims = _vector_dimensions_spin.current_vector
		peripheral_dims = peripheral_segment.dimensions_3D
	else:
		# Editing peripheral segment
		center_dims = center_segment.dimensions_3D
		peripheral_dims = _vector_dimensions_spin.current_vector
	
	# Check if dimensions changed (for layout recalculation)
	var dims_changed = false
	if edited_segment.unit_id == 4:
		dims_changed = (center_dims != center_segment.dimensions_3D)
	else:
		dims_changed = (peripheral_dims != peripheral_segment.dimensions_3D)
	
	# Check NPU capacity if dimensions changed
	if dims_changed:
		# Refresh health data before capacity check to ensure accuracy
		await FeagiCore.requests.single_health_check_call(true)
		_isvi_would_overflow = _check_isvi_resize_capacity(center_dims, peripheral_dims, edited_segment.unit_id == 4)
	else:
		_isvi_would_overflow = false  # Movement doesn't change neuron count
	
	var new_layout: Dictionary
	
	if dims_changed:
		# Dimensions changed - recalculate layout based on new center position
		new_layout = _calculate_isvi_layout(new_pos if edited_segment.unit_id == 4 else center_segment.coordinates_3D, center_dims, peripheral_dims)
	else:
		# Only position changed - apply delta to all segments
		new_layout = {}
		for segment in _isvi_all_segments:
			new_layout[segment.unit_id] = segment.coordinates_3D + position_delta
	
	# Update positions for all segments (add to pending updates)
	for segment in _isvi_all_segments:
		if segment.unit_id in new_layout:
			var pos_dict: Dictionary
			
			if dims_changed:
				# Dimensions changed (resizing) - layout returns Vector2i, preserve ORIGINAL z
				var xy_pos: Vector2i = new_layout[segment.unit_id]
				var original_z = _isvi_original_z_values.get(segment.unit_id, segment.coordinates_3D.z)
				pos_dict = {"x": xy_pos.x, "y": xy_pos.y, "z": original_z}
			else:
				# Only position changed (movement) - layout returns Vector3i with delta applied
				var xyz_pos: Vector3i = new_layout[segment.unit_id]
				pos_dict = {"x": xyz_pos.x, "y": xyz_pos.y, "z": xyz_pos.z}
			
			# Add to update dict for this specific cortical area
			if not (segment.cortical_ID in _growing_cortical_update):
				_growing_cortical_update[segment.cortical_ID] = {}
			_growing_cortical_update[segment.cortical_ID]["coordinates_3d"] = pos_dict
	
	# Also update dimension for all peripherals ONLY IF dimensions actually changed
	if _cortical_area_refs[0].unit_id != 4 and dims_changed:
		for segment in _isvi_all_segments:
			if segment.unit_id != 4:  # All peripherals
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
	if _cortical_area_refs[0].unit_id in layout:
		var preview_pos: Vector3i
		
		if is_resize:
			# Resizing - layout returns Vector2i (x, y), add ORIGINAL z
			var xy_pos: Vector2i = layout[_cortical_area_refs[0].unit_id]
			var original_z = _isvi_original_z_values.get(_cortical_area_refs[0].unit_id, _cortical_area_refs[0].coordinates_3D.z)
			preview_pos = Vector3i(xy_pos.x, xy_pos.y, original_z)
		else:
			# Movement - layout returns Vector3i with delta applied
			preview_pos = layout[_cortical_area_refs[0].unit_id]
		
		_preview.set_new_position(preview_pos)
		if _cortical_area_refs[0].unit_id == 4:
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
		
		if segment.unit_id not in layout:
			continue
		
		var segment_pos_final: Vector3i
		
		if is_resize:
			# Resizing - layout returns Vector2i (x, y), add ORIGINAL z
			var xy_pos: Vector2i = layout[segment.unit_id]
			var original_z = _isvi_original_z_values.get(segment.unit_id, segment.coordinates_3D.z)
			segment_pos_final = Vector3i(xy_pos.x, xy_pos.y, original_z)
		else:
			# Movement - layout returns Vector3i with delta applied
			segment_pos_final = layout[segment.unit_id]
		
		var segment_dims = center_dims if segment.unit_id == 4 else peripheral_dims
		
		
		# Check if we already have a preview for this segment
		if segment.unit_id in _isvi_segment_previews:
			var existing_preview = _isvi_segment_previews[segment.unit_id]
			if existing_preview != null:
				existing_preview.set_new_position(segment_pos_final)
				existing_preview.set_new_dimensions(segment_dims)
				existing_preview.set_warning_state(_isvi_would_overflow)
			else:
				# Preview was deleted, remove from dict
				_isvi_segment_previews.erase(segment.unit_id)
		else:
			# Create new preview for this segment
			var cortical_type = segment.cortical_type
			var closes_only: Array[Signal] = [close_window_requesed_no_arg, _button_summary_send.pressed]
			# Don't auto-frame camera when creating isvi segment previews during layout changes
			var new_preview = _host_preview_bm.create_preview(segment_pos_final, segment_dims, false, cortical_type, segment, false)
			new_preview.connect_UI_signals([], [], closes_only)
			new_preview.set_warning_state(_isvi_would_overflow)
			
			# Store this preview
			_isvi_segment_previews[segment.unit_id] = new_preview
			
			# Cleanup when it's destroyed
			var unit_id_copy = segment.unit_id  # Capture for closure
			new_preview.tree_exiting.connect(func(): _isvi_segment_previews.erase(unit_id_copy))

#endregion
