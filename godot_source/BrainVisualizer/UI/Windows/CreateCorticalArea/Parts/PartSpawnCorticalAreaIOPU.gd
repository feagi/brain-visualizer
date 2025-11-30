extends VBoxContainer
class_name PartSpawnCorticalAreaIOPU

signal calculated_dimensions_updated(new_size: Vector3i)
signal location_changed_from_dropdown(new_location: Vector3i)
signal group_id_validation_changed(is_valid: bool, message: String)

var location: Vector3iSpinboxField
var device_count: SpinBox
var group_id: SpinBox
var data_type_variant: OptionButton
var frame_handling: OptionButton
var positioning: OptionButton
var _iopu_image: TextureRect
var _device_name_label: Label
var _group_id_status_label: Label
var _current_dimensions_as_per_device_count: Vector3i = Vector3i(1,1,1)
var _is_IPU_not_OPU: bool
var _selected_template: CorticalTemplate = null
var _preview_boxes: Array[UI_BrainMonitor_InteractivePreview] = []  # Multiple preview boxes for multi-unit cortical types
var _active_brain_monitor = null  # Store reference to brain monitor
var _preview_close_signals: Array[Signal] = []  # Store close signals
var _template_metadata: Dictionary = {}  # Fetched from /v1/genome/cortical_template
var _selected_data_type_config: int = 4  # Default: SignedPercentage(Absolute, Linear) for OPU

func _ready() -> void:
	location = $HBoxContainer/Fields/Location
	device_count = $HBoxContainer/Fields/ChannelCount
	group_id = $HBoxContainer/Fields/GroupID
	data_type_variant = $HBoxContainer/Fields/DataTypeVariant
	frame_handling = $HBoxContainer/Fields/FrameHandling
	positioning = $HBoxContainer/Fields/Positioning
	_iopu_image = $HBoxContainer/TextureRect
	_device_name_label = $HBoxContainer2/TopSection/DeviceName
	_group_id_status_label = $GroupIDStatus
	
	# Connect to location changes to update all preview boxes
	location.user_updated_vector.connect(_on_location_changed)
	location_changed_from_dropdown.connect(_on_location_changed)
	
	# Fetch cortical template metadata from FEAGI API
	_fetch_template_metadata()
	


func cortical_type_selected(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, preview_close_signals: Array[Signal], host_bm = null) -> void:
	_is_IPU_not_OPU = cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU
	_selected_template = null
	_current_dimensions_as_per_device_count = Vector3i(1, 1, 1)
	if _device_name_label != null:
		_device_name_label.text = ""
	
	# Store brain monitor and close signals for later use
	_active_brain_monitor = host_bm if host_bm != null else BV.UI.get_active_brain_monitor()
	_preview_close_signals = preview_close_signals
	
	if _active_brain_monitor == null:
		push_error("PartSpawnCorticalAreaIOPU: No brain monitor available for preview creation!")
		return
	
	# Clear any existing previews
	_clear_all_previews()
	
	# Create initial placeholder preview (1x1x1 at current location)
	var move_signals: Array[Signal] = [location.user_updated_vector, location_changed_from_dropdown]
	var resize_signals: Array[Signal] = [calculated_dimensions_updated]
	if _is_IPU_not_OPU:
		_iopu_image.texture = load(UIManager.KNOWN_ICON_PATHS["i__inf"])
	else:
		_iopu_image.texture = load(UIManager.KNOWN_ICON_PATHS["o__mot"])
	
	var preview: UI_BrainMonitor_InteractivePreview = _active_brain_monitor.create_preview(location.current_vector, _current_dimensions_as_per_device_count, false, cortical_type)
	preview.connect_UI_signals(move_signals, resize_signals, preview_close_signals)
	_preview_boxes.append(preview)



func _clear_all_previews() -> void:
	"""Clear all existing preview boxes"""
	for preview in _preview_boxes:
		if preview != null and is_instance_valid(preview):
			preview.queue_free()
	_preview_boxes.clear()

func _create_preview_boxes_from_topology() -> void:
	"""Create multiple preview boxes based on unit topology data"""
	if _selected_template == null or _active_brain_monitor == null:
		return
	
	# Clear existing previews
	_clear_all_previews()
	
	# Get topology data from template
	var topology: Dictionary = _selected_template.unit_default_topology
	if topology.is_empty():
		push_warning("PartSpawnCorticalAreaIOPU: No topology data, creating single preview")
		# Fallback to single preview box
		_create_single_preview_box(location.current_vector, _current_dimensions_as_per_device_count)
		return
	
	# Check for existing cortical areas of the same type to get their dimensions
	var existing_dimensions_map: Dictionary = _get_existing_unit_dimensions(_selected_template.ID)
	
	# Create preview boxes for each unit
	var base_position: Vector3i = location.current_vector
	# Note: We handle location changes in _on_location_changed, so don't pass move signals
	var move_signals: Array[Signal] = []
	var resize_signals: Array[Signal] = []
	
	var sorted_unit_indices: Array = topology.keys()
	sorted_unit_indices.sort()
	
	for unit_idx in sorted_unit_indices:
		var unit_data: Dictionary = topology[unit_idx]
		var rel_pos: Array = unit_data.get("relative_position", [0, 0, 0])
		var default_dims: Array = unit_data.get("dimensions", [1, 1, 1])
		
		# Use existing dimensions if available, otherwise use default
		var dims: Vector3i
		if unit_idx in existing_dimensions_map:
			dims = existing_dimensions_map[unit_idx]
		else:
			dims = Vector3i(default_dims[0], default_dims[1], default_dims[2])
		
		# Calculate absolute position
		var abs_position: Vector3i = base_position + Vector3i(rel_pos[0], rel_pos[1], rel_pos[2])
		
		# Create preview box for this unit
		var cortical_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU if _is_IPU_not_OPU else AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU
		var preview: UI_BrainMonitor_InteractivePreview = _active_brain_monitor.create_preview(abs_position, dims, false, cortical_type)
		preview.connect_UI_signals(move_signals, resize_signals, _preview_close_signals)
		_preview_boxes.append(preview)
	
	print("PartSpawnCorticalAreaIOPU: Created %d preview boxes for %s" % [_preview_boxes.size(), _selected_template.cortical_name])

func _create_single_preview_box(pos: Vector3i, dims: Vector3i) -> void:
	"""Create a single preview box (fallback when no topology data)"""
	# For single preview, we can use the standard signal connections
	var move_signals: Array[Signal] = [location.user_updated_vector, location_changed_from_dropdown]
	var resize_signals: Array[Signal] = [calculated_dimensions_updated]
	var cortical_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU if _is_IPU_not_OPU else AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU
	var preview: UI_BrainMonitor_InteractivePreview = _active_brain_monitor.create_preview(pos, dims, false, cortical_type)
	preview.connect_UI_signals(move_signals, resize_signals, _preview_close_signals)
	_preview_boxes.append(preview)

func _get_existing_unit_dimensions(cortical_type_key: String) -> Dictionary:
	"""Find existing cortical areas of the same type and return dimensions for each unit (from largest group_id)"""
	var existing_areas: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	var unit_dimensions: Dictionary = {}  # {unit_index: Vector3i dimensions}
	var largest_group_id: int = -1
	
	# First pass: find the largest group_id for this cortical type
	for cortical_id: StringName in existing_areas.keys():
		var cortical_id_str: String = String(cortical_id)
		var decoded_bytes: PackedByteArray = Marshalls.base64_to_raw(cortical_id_str)
		if decoded_bytes.size() != 8:
			continue
		
		var subtype_bytes: PackedByteArray = decoded_bytes.slice(0, 4)
		var cortical_subtype: String = subtype_bytes.get_string_from_ascii()
		
		if cortical_subtype == cortical_type_key:
			var group_id_val: int = decoded_bytes[7]
			if group_id_val > largest_group_id:
				largest_group_id = group_id_val
	
	# Second pass: collect dimensions from areas with the largest group_id
	if largest_group_id >= 0:
		for cortical_id: StringName in existing_areas.keys():
			var cortical_id_str: String = String(cortical_id)
			var decoded_bytes: PackedByteArray = Marshalls.base64_to_raw(cortical_id_str)
			if decoded_bytes.size() != 8:
				continue
			
			var subtype_bytes: PackedByteArray = decoded_bytes.slice(0, 4)
			var cortical_subtype: String = subtype_bytes.get_string_from_ascii()
			var group_id_val: int = decoded_bytes[7]
			var unit_index: int = decoded_bytes[6]
			
			if cortical_subtype == cortical_type_key and group_id_val == largest_group_id:
				var area = existing_areas[cortical_id]
				unit_dimensions[unit_index] = area.dimensions_3D
	
	return unit_dimensions

func _get_existing_neurons_per_voxel(cortical_type_key: String) -> int:
	"""Find existing cortical areas of the same type and return neurons_per_voxel from largest group_id"""
	var existing_areas: Dictionary = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	var largest_group_id: int = -1
	var neurons_per_voxel: int = 1  # Default
	
	print("PartSpawnCorticalAreaIOPU: Looking for existing neurons_per_voxel for type: %s" % cortical_type_key)
	
	# Find the largest group_id for this cortical type and get its neurons_per_voxel
	for cortical_id: StringName in existing_areas.keys():
		var cortical_id_str: String = String(cortical_id)
		var decoded_bytes: PackedByteArray = Marshalls.base64_to_raw(cortical_id_str)
		if decoded_bytes.size() != 8:
			continue
		
		var subtype_bytes: PackedByteArray = decoded_bytes.slice(0, 4)
		var cortical_subtype: String = subtype_bytes.get_string_from_ascii()
		
		if cortical_subtype == cortical_type_key:
			var group_id_val: int = decoded_bytes[7]
			var area = existing_areas[cortical_id]
			var area_neurons_per_voxel: int = area.cortical_neuron_per_vox_count
			print("  Found %s group %d with neurons_per_voxel=%d" % [cortical_subtype, group_id_val, area_neurons_per_voxel])
			
			if group_id_val > largest_group_id:
				largest_group_id = group_id_val
				neurons_per_voxel = area_neurons_per_voxel
	
	print("  → Using neurons_per_voxel=%d (from group_id=%d)" % [neurons_per_voxel, largest_group_id])
	return neurons_per_voxel

func _drop_down_changed(cortical_template: CorticalTemplate) -> void:
	# Backward-compatibility: if invoked by legacy signal, apply selection
	_apply_template_selection(cortical_template)


func _apply_template_selection(cortical_template: CorticalTemplate) -> void:
	if cortical_template == null:
		push_warning("PartSpawnCorticalAreaIOPU: Received null cortical template")
		return
	_selected_template = cortical_template
	_current_dimensions_as_per_device_count = cortical_template.calculate_IOPU_dimension(int(device_count.value))
	_iopu_image.texture = UIManager.get_icon_texture_by_ID(cortical_template.ID, _is_IPU_not_OPU)
	if _device_name_label != null:
		_device_name_label.text = str(cortical_template.cortical_name)
	
	# Set group_id to first available value
	var first_available_id = _find_first_available_group_id(cortical_template.ID)
	group_id.value = first_available_id
	
	# Populate data type dropdowns for this template
	_populate_data_type_dropdowns(cortical_template.ID)
	
	# Update location if an existing area exists
	if cortical_template.ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas:
		location.current_vector = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[cortical_template.ID].coordinates_3D
		location_changed_from_dropdown.emit(location.current_vector)
	
	# Create multiple preview boxes based on topology
	_create_preview_boxes_from_topology()
	

func _on_location_changed(new_location: Vector3i) -> void:
	"""Handle location changes to update all preview boxes' positions"""
	if _selected_template == null or _preview_boxes.is_empty():
		return
	
	# Get topology to recalculate positions
	var topology: Dictionary = _selected_template.unit_default_topology
	if topology.is_empty():
		# Single preview box, just update its position
		if _preview_boxes.size() > 0 and _preview_boxes[0] != null:
			_preview_boxes[0].set_new_position(new_location)
		return
	
	# Update each preview box position based on topology
	var sorted_unit_indices: Array = topology.keys()
	sorted_unit_indices.sort()
	
	for i in range(min(sorted_unit_indices.size(), _preview_boxes.size())):
		var unit_idx = sorted_unit_indices[i]
		var unit_data: Dictionary = topology[unit_idx]
		var rel_pos: Array = unit_data.get("relative_position", [0, 0, 0])
		var abs_position: Vector3i = new_location + Vector3i(rel_pos[0], rel_pos[1], rel_pos[2])
		
		if _preview_boxes[i] != null and is_instance_valid(_preview_boxes[i]):
			_preview_boxes[i].set_new_position(abs_position)

func _proxy_device_count_changes(_new_device_count: int) -> void:
	var selected_template = _selected_template
	if selected_template == null:
		push_warning("PartSpawnCorticalAreaIOPU: No template selected, cannot update device count")
		return
		
	_current_dimensions_as_per_device_count = selected_template.calculate_IOPU_dimension(int(device_count.value))
	calculated_dimensions_updated.emit(_current_dimensions_as_per_device_count)
	
	# Regenerate preview boxes with updated dimensions
	_create_preview_boxes_from_topology()


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

func get_neurons_per_voxel() -> int:
	"""Get neurons_per_voxel inherited from existing cortical areas or default to 1"""
	if _selected_template == null:
		return 1
	return _get_existing_neurons_per_voxel(_selected_template.ID)

func _fetch_template_metadata() -> void:
	"""Fetch cortical template metadata from FEAGI API"""
	var response: FeagiRequestOutput = await FeagiCore.requests.get_cortical_template_metadata()
	if response.success:
		_template_metadata = response.decode_response_as_dict()
		print("PartSpawnCorticalAreaIOPU: Fetched template metadata for %d types" % _template_metadata.size())
	else:
		push_error("PartSpawnCorticalAreaIOPU: Failed to fetch template metadata")
		_template_metadata = {}

func _populate_data_type_dropdowns(cortical_type_key: String) -> void:
	"""Populate dropdowns based on selected template's supported data types"""
	# Clear existing options
	data_type_variant.clear()
	frame_handling.clear()
	positioning.clear()
	
	# Check if we have metadata for this template
	if cortical_type_key not in _template_metadata:
		push_warning("PartSpawnCorticalAreaIOPU: No metadata for " + cortical_type_key)
		# Add defaults
		_add_default_dropdown_options()
		return
	
	var template_data: Dictionary = _template_metadata[cortical_type_key]
	var supported_types: Array = template_data.get("supported_data_types", [])
	
	if supported_types.is_empty():
		_add_default_dropdown_options()
		return
	
	# Collect unique values for each dropdown
	var variants: Array[String] = []
	var frames: Array[String] = []
	var positionings: Array[String] = []
	var config_map: Dictionary = {}  # Map (variant, frame, positioning) -> config_value
	
	for data_type in supported_types:
		var variant: String = data_type.get("variant", "")
		var frame: String = data_type.get("frame_change_handling", "")
		var pos = data_type.get("percentage_positioning", null)
		var config_val: int = data_type.get("config_value", 0)
		
		if variant not in variants:
			variants.append(variant)
		if frame not in frames:
			frames.append(frame)
		if pos != null and pos not in positionings:
			positionings.append(pos)
		
		# Store config value for this combination
		var key: String = "%s|%s|%s" % [variant, frame, str(pos)]
		config_map[key] = config_val
	
	# Populate dropdowns
	for v in variants:
		data_type_variant.add_item(v)
	for f in frames:
		frame_handling.add_item(f)
	for p in positionings:
		positioning.add_item(p)
	
	# Store config map for later lookup
	data_type_variant.set_meta("config_map", config_map)
	
	# Select defaults (first option or SignedPercentage if available)
	if "SignedPercentage" in variants:
		data_type_variant.select(variants.find("SignedPercentage"))
	
	_update_selected_config_value()

func _add_default_dropdown_options() -> void:
	"""Add default options when API data not available"""
	# Data Type Variants
	data_type_variant.add_item("SignedPercentage")
	data_type_variant.add_item("Percentage")
	
	# Frame Handling
	frame_handling.add_item("Absolute")
	frame_handling.add_item("Incremental")
	
	# Positioning
	positioning.add_item("Linear")
	positioning.add_item("Fractional")
	
	# Select defaults for OPU
	if not _is_IPU_not_OPU:
		data_type_variant.select(0)  # SignedPercentage
	frame_handling.select(0)  # Absolute
	positioning.select(0)  # Linear

func _on_data_type_variant_changed(_index: int) -> void:
	_update_selected_config_value()

func _on_frame_handling_changed(_index: int) -> void:
	_update_selected_config_value()

func _on_positioning_changed(_index: int) -> void:
	_update_selected_config_value()

func _update_selected_config_value() -> void:
	"""Calculate the data_type_config value from selected dropdowns"""
	var variant_text: String = data_type_variant.get_item_text(data_type_variant.selected) if data_type_variant.selected >= 0 else ""
	var frame_text: String = frame_handling.get_item_text(frame_handling.selected) if frame_handling.selected >= 0 else ""
	var pos_text: String = positioning.get_item_text(positioning.selected) if positioning.selected >= 0 else ""
	
	# Try to lookup from API config map
	if data_type_variant.has_meta("config_map"):
		var config_map: Dictionary = data_type_variant.get_meta("config_map")
		var key: String = "%s|%s|%s" % [variant_text, frame_text, pos_text]
		if key in config_map:
			_selected_data_type_config = config_map[key]
			return
	
	# Fallback: Calculate manually using the same bit-packing as Rust
	var variant_bits: int = _variant_name_to_bits(variant_text)
	var frame_bits: int = 1 if frame_text == "Incremental" else 0
	var positioning_bits: int = 1 if pos_text == "Fractional" else 0
	
	_selected_data_type_config = variant_bits | (frame_bits << 4) | (positioning_bits << 5)

func _variant_name_to_bits(name: String) -> int:
	"""Convert variant name to bits (0-3 for variant type)"""
	match name:
		"Percentage": return 0
		"Percentage2D": return 1
		"Percentage3D": return 2
		"Percentage4D": return 3
		"SignedPercentage": return 4
		"SignedPercentage2D": return 5
		"SignedPercentage3D": return 6
		"SignedPercentage4D": return 7
		"CartesianPlane": return 8
		"Misc": return 9
		_: return 0

func get_selected_data_type_config() -> int:
	"""Get the currently selected data type configuration value"""
	return _selected_data_type_config
