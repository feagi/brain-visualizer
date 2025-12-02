extends BoxContainer
class_name UI_BrainMonitor_Overlay
## UI overlay for Brain Monitor

var _mouse_context_label: Label
var _fdp_deserializer: FeagiDataDeserializer = null

func _ready() -> void:
	_mouse_context_label = $Bottom_Row/MouseContext
	
	# Initialize FDP deserializer for decoding voxel values
	print("=== FDP INIT: Checking for FeagiDataDeserializer class...")
	if ClassDB.class_exists("FeagiDataDeserializer"):
		print("=== FDP INIT: FeagiDataDeserializer class found! Creating instance...")
		_fdp_deserializer = FeagiDataDeserializer.new()
		print("=== FDP INIT: Instance created successfully!")
	else:
		print("=== FDP INIT: WARNING - FeagiDataDeserializer not available!")
		push_warning("FeagiDataDeserializer not available - FDP voxel decoding will be disabled")

## Clear all text
func clear() -> void:
	_mouse_context_label.text = ""

func mouse_over_single_cortical_area(cortical_area: AbstractCorticalArea, neuron_coordinate: Vector3i) -> void:
	print("=== FDP HOVER: Function called! Area: ", cortical_area.cortical_ID, " Type: ", cortical_area.cortical_type)
	
	if cortical_area.cortical_type not in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]:
		_mouse_context_label.text = "Area - " + cortical_area.friendly_name + "  " + str(neuron_coordinate)
		return
	var text: String = "Area - " + cortical_area.friendly_name + " " + str(neuron_coordinate) + " "
	if cortical_area is IPUCorticalArea:
		var device_index: int = floori((neuron_coordinate.x) / cortical_area.cortical_dimensions_per_device.x)
		var appending_definitions: Array[StringName] = cortical_area.get_custom_names(FeagiCore.feagi_local_cache.configuration_jsons, device_index)
		for appending in appending_definitions:
			text += "| " + appending
	elif cortical_area is OPUCorticalArea:
		var device_index: int = floori((neuron_coordinate.x) / cortical_area.cortical_dimensions_per_device.x)
		var appending_definitions: Array[StringName] = cortical_area.get_custom_names(FeagiCore.feagi_local_cache.configuration_jsons, device_index)
		for appending in appending_definitions:
			text += "| " + appending
	if cortical_area.cortical_ID == "o_mctl":
		var device_local_coordinate: Vector3i = Vector3i(neuron_coordinate.x % 4, neuron_coordinate.y % 3, 0)
		var direction: String
		match(device_local_coordinate):
			Vector3i(0,0,0): direction = " - Move Left"
			Vector3i(1,0,0): direction = " - Move Up"
			Vector3i(2,0,0): direction = " - Move Down"
			Vector3i(3,0,0): direction = " - Move Right"
			
			Vector3i(0,1,0): direction = " - Yaw Left"
			Vector3i(1,1,0): direction = " - Move Forward"
			Vector3i(2,1,0): direction = " - Move Backward"
			Vector3i(3,1,0): direction = " - Yaw Right"
			
			Vector3i(0,2,0): direction = " - Roll Left"
			Vector3i(1,2,0): direction = " - Pitch Forward"
			Vector3i(2,2,0): direction = " - Pitch Backward"
			Vector3i(3,2,0): direction = " - Roll Right"
		text += direction
	
	# NEW FEATURE: Add FDP-decoded value information for OPU areas only
	# This shows what value FDP would produce for this voxel using the actual FDP decoding logic
	# NOTE: This is currently implemented for OPU areas only. IPU areas will have a different variation.
	
	print("=== FDP HOVER: Checking conditions - Deserializer null? ", _fdp_deserializer == null, " Is OPU? ", cortical_area is OPUCorticalArea)
	
	if _fdp_deserializer != null and cortical_area is OPUCorticalArea:
		# Parse encoding info directly from binary cortical ID using FDP's format
		var encoding_info = _fdp_deserializer.parse_cortical_id_encoding(cortical_area.cortical_ID)
		print("=== FDP HOVER: Parse result: ", encoding_info)
		
		if encoding_info.get("success", false):
			var encoding_type_val = encoding_info.get("encoding_type", "")
			var encoding_format_val = encoding_info.get("encoding_format", "")
			
			# Use device_count if available, otherwise use a large number to skip validation
			var num_channels = cortical_area.device_count
			if num_channels == 0:
				# Device count not set - use large number to skip channel range check
				num_channels = 9999
			print("=== FDP HOVER: Using num_channels: ", num_channels, " (device_count was: ", cortical_area.device_count, ")")
			
			# Decode the FDP value using the binary-parsed encoding info
			var fdp_result = _fdp_deserializer.decode_fdp_value(
				cortical_area.cortical_ID,
				neuron_coordinate.x,
				neuron_coordinate.y,
				neuron_coordinate.z,
				encoding_type_val,
				encoding_format_val,
				cortical_area.cortical_dimensions_per_device.x,
				cortical_area.cortical_dimensions_per_device.y,
				cortical_area.cortical_dimensions_per_device.z,
				num_channels
			)
			print("=== FDP HOVER: Decode result: ", fdp_result)
			
			if fdp_result.get("success", false):
				var fdp_version = fdp_result.get("fdp_version", "unknown")
				var channel = fdp_result.get("channel", -1)
				var value = fdp_result.get("value", 0.0)
				text += " | FDP:%s CH:%d Value:%.2f%%" % [fdp_version, channel, value]
				print("=== FDP HOVER: SUCCESS! Text should be visible now!")
			else:
				print("=== FDP HOVER: Decode failed: ", fdp_result.get("error", "unknown"))
		else:
			print("=== FDP HOVER: Parse failed: ", encoding_info.get("error", "unknown"))
	
	_mouse_context_label.text = text

## Show plate hover context (region name + plate kind)
func show_plate_hover(region_name: String, plate_kind: String) -> void:
	_mouse_context_label.text = "Circuit - " + region_name + " (" + plate_kind + ")"

## Clear plate hover context (only if no cortical hover text is present)
func clear_plate_hover() -> void:
	# Optional: do not clear if cortical context is showing
	# For now, we clear unconditionally when plate hover ends
	_mouse_context_label.text = ""
