extends VBoxContainer
class_name PartSpawnCorticalAreaIOPU

signal calculated_dimensions_updated(new_size: Vector3i)
signal location_changed_from_dropdown(new_location: Vector3i)
signal group_id_validation_changed(is_valid: bool, message: String)

var location: Vector3iSpinboxField
var device_count: SpinBox
var group_id: SpinBox
var _iopu_image: TextureRect
var _device_name_label: Label
var _group_id_status_label: Label
var _current_dimensions_as_per_device_count: Vector3i = Vector3i(1,1,1)
var _is_IPU_not_OPU: bool
var _selected_template: CorticalTemplate = null

func _ready() -> void:
	location = $HBoxContainer/Fields/Location
	device_count = $HBoxContainer/Fields/ChannelCount
	group_id = $HBoxContainer/Fields/GroupID
	_iopu_image = $HBoxContainer/TextureRect
	_device_name_label = $HBoxContainer2/TopSection/DeviceName
	_group_id_status_label = $GroupIDStatus
	


func cortical_type_selected(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal], host_bm = null) -> void:
	_is_IPU_not_OPU = cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU
	_selected_template = null
	_current_dimensions_as_per_device_count = Vector3i(1, 1, 1)
	if _device_name_label != null:
		_device_name_label.text = ""
	
	var move_signals: Array[Signal] = [location.user_updated_vector, location_changed_from_dropdown]
	var resize_signals: Array[Signal] = [calculated_dimensions_updated]
	if _is_IPU_not_OPU:
		_iopu_image.texture = load(UIManager.KNOWN_ICON_PATHS["i__inf"])
	else:
		_iopu_image.texture = load(UIManager.KNOWN_ICON_PATHS["o__mot"])
	var active_bm = host_bm if host_bm != null else BV.UI.get_active_brain_monitor()
	if active_bm == null:
		push_error("PartSpawnCorticalAreaIOPU: No brain monitor available for preview creation!")
		return
	var preview: UI_BrainMonitor_InteractivePreview = active_bm.create_preview(location.current_vector, _current_dimensions_as_per_device_count, false, cortical_type)
	preview.connect_UI_signals(move_signals, resize_signals, preview_close_signals)



func _drop_down_changed(cortical_template: CorticalTemplate) -> void:
	# Backward-compatibility: if invoked by legacy signal, apply selection
	_apply_template_selection(cortical_template)


func _apply_template_selection(cortical_template: CorticalTemplate) -> void:
	if cortical_template == null:
		push_warning("PartSpawnCorticalAreaIOPU: Received null cortical template")
		return
	_selected_template = cortical_template
	_current_dimensions_as_per_device_count = cortical_template.calculate_IOPU_dimension(int(device_count.value))
	calculated_dimensions_updated.emit(_current_dimensions_as_per_device_count)
	_iopu_image.texture = UIManager.get_icon_texture_by_ID(cortical_template.ID, _is_IPU_not_OPU)
	if _device_name_label != null:
		_device_name_label.text = str(cortical_template.cortical_name)
	
	# Set group_id to first available value
	var first_available_id = _find_first_available_group_id(cortical_template.ID)
	group_id.value = first_available_id
	
	if cortical_template.ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
		location.current_vector = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[cortical_template.ID].coordinates_3D
		location_changed_from_dropdown.emit(location.current_vector)
	

func _proxy_device_count_changes(_new_device_count: int) -> void:
	var selected_template = _selected_template
	if selected_template == null:
		push_warning("PartSpawnCorticalAreaIOPU: No template selected, cannot update device count")
		return
		
	_current_dimensions_as_per_device_count = selected_template.calculate_IOPU_dimension(int(device_count.value))
	calculated_dimensions_updated.emit(_current_dimensions_as_per_device_count)


func get_selected_template() -> CorticalTemplate:
	return _selected_template


func apply_preselected_template(template: CorticalTemplate) -> void:
	_apply_template_selection(template)
	# Validate group ID after template is applied
	_validate_group_id()

func _on_group_id_changed(_value: float) -> void:
	_validate_group_id()

func _find_first_available_group_id(cortical_type_key: String) -> int:
	"""Find the first available (unused) group ID for the given cortical type"""
	var existing_areas: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	var used_group_ids: Array[int] = []
	
	# Collect all used group IDs for this cortical type
	for cortical_id: StringName in existing_areas.keys():
		var cortical_id_str: String = String(cortical_id)
		
		# Decode the base64 cortical ID
		var decoded_bytes: PackedByteArray = Marshalls.base64_to_raw(cortical_id_str)
		if decoded_bytes.size() != 8:
			continue
		
		# Extract cortical_subtype (bytes 0-3)
		var subtype_bytes: PackedByteArray = decoded_bytes.slice(0, 4)
		var cortical_subtype: String = subtype_bytes.get_string_from_ascii()
		
		# If this matches our type, record its group_id
		if cortical_subtype == cortical_type_key:
			var existing_group_id: int = decoded_bytes[7]
			used_group_ids.append(existing_group_id)
	
	# Find the first available ID (0-255)
	for candidate_id in range(256):
		if candidate_id not in used_group_ids:
			return candidate_id
	
	# If all IDs are taken (unlikely), return 0
	return 0

func _validate_group_id() -> void:
	if _selected_template == null:
		_group_id_status_label.text = ""
		group_id_validation_changed.emit(true, "")
		return
	
	var selected_group_id: int = int(group_id.value)
	var cortical_type_key: String = _selected_template.ID
	
	# Check if this cortical type + group ID combination already exists
	var existing_areas: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	
	for cortical_id: StringName in existing_areas.keys():
		var cortical_id_str: String = String(cortical_id)
		
		# Decode the base64 cortical ID to extract cortical_subtype and group_id
		var decoded_bytes: PackedByteArray = Marshalls.base64_to_raw(cortical_id_str)
		if decoded_bytes.size() != 8:
			continue  # Invalid cortical ID, skip
		
		# Extract cortical_subtype (bytes 0-3) and convert to string
		var subtype_bytes: PackedByteArray = decoded_bytes.slice(0, 4)
		var cortical_subtype: String = subtype_bytes.get_string_from_ascii()
		
		# Check if this matches our template ID
		if cortical_subtype == cortical_type_key:
			# Extract group_id (byte 7)
			var existing_group_id: int = decoded_bytes[7]
			
			if existing_group_id == selected_group_id:
				# Found a match - this group ID is already used!
				var area_name: String = existing_areas[cortical_id].friendly_name
				var message: String = "⚠ Group ID %d already exists for %s (%s)" % [selected_group_id, cortical_type_key, area_name]
				_group_id_status_label.text = message
				_group_id_status_label.modulate = Color(1.0, 0.5, 0.5)  # Red tint
				group_id_validation_changed.emit(false, message)
				return
	
	# Group ID is available
	var message: String = "✓ Group ID %d is available for %s" % [selected_group_id, cortical_type_key]
	_group_id_status_label.text = message
	_group_id_status_label.modulate = Color(0.5, 1.0, 0.5)  # Green tint
	group_id_validation_changed.emit(true, "")

func get_selected_group_id() -> int:
	return int(group_id.value)
