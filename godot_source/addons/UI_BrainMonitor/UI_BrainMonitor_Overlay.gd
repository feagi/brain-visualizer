extends BoxContainer
class_name UI_BrainMonitor_Overlay
## UI overlay for Brain Monitor

var _mouse_context_label: Label
var _fdp_deserializer: Object = null  # FeagiDataDeserializer when extension loaded

func _process(_delta: float) -> void:
	# Keep overlay size synced to viewport size (hover label is now global).
	var viewport := get_parent().get_parent() as SubViewport # Overlay -> UI_Canvas -> SubViewport
	if viewport:
		var viewport_size := Vector2(viewport.size)
		if size != viewport_size:
			size = viewport_size
		if position != Vector2.ZERO:
			position = Vector2.ZERO

func _ready() -> void:
	_mouse_context_label = $Bottom_Row/MouseContext
	
	# Reparent label to overlay root to ensure it stays on top and ignores container layout
	var bottom_row := $Bottom_Row
	if bottom_row and _mouse_context_label.get_parent() == bottom_row:
		bottom_row.remove_child(_mouse_context_label)
		add_child(_mouse_context_label)
	
	_mouse_context_label.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	
	# Force label to be bright white and visible
	_mouse_context_label.add_theme_color_override("font_color", Color.WHITE)
	_mouse_context_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_mouse_context_label.add_theme_constant_override("outline_size", 2)
	_mouse_context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mouse_context_label.visible = false
	
	# Allow mouse events to pass through overlay to 3D scene
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Bottom_Row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mouse_context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Initialize FDP deserializer for decoding voxel values
	if ClassDB.class_exists("FeagiDataDeserializer"):
		_fdp_deserializer = ClassDB.instantiate("FeagiDataDeserializer")
	else:
		push_warning("FeagiDataDeserializer not available - FDP voxel decoding will be disabled")

## Clear all text
func clear() -> void:
	_clear_global_context()

## Returns the owning brain monitor for this overlay.
func _get_owning_bm() -> UI_BrainMonitor_3DScene:
	var viewport := get_parent().get_parent() as SubViewport
	if viewport == null:
		return null
	return viewport.get_parent() as UI_BrainMonitor_3DScene

## Updates the global hover label using this overlay's context.
func _set_global_context(text: String) -> void:
	if BV == null or BV.UI == null:
		return
	var bm := _get_owning_bm()
	if bm == null:
		return
	BV.UI.update_mouse_context(text, bm)

## Clears the global hover label for this overlay.
func _clear_global_context() -> void:
	if BV == null or BV.UI == null:
		return
	var bm := _get_owning_bm()
	if bm == null:
		return
	BV.UI.clear_mouse_context(bm)

func mouse_over_single_cortical_area(cortical_area: AbstractCorticalArea, neuron_coordinate: Vector3i) -> void:
	if _mouse_context_label == null:
		return
	
	if cortical_area.cortical_type not in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]:
		_set_global_context("Area - " + cortical_area.friendly_name + "  " + str(neuron_coordinate))
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
	
	if _fdp_deserializer != null and cortical_area is OPUCorticalArea:
		# Parse encoding info directly from binary cortical ID using FDP's binary format
		var encoding_info = _fdp_deserializer.parse_cortical_id_encoding(cortical_area.cortical_ID)
		
		if encoding_info.get("success", false):
			var encoding_type_val = encoding_info.get("encoding_type", "")
			var encoding_format_val = encoding_info.get("encoding_format", "")
			
			# Use device_count if available, otherwise use large number to skip validation
			var num_channels = cortical_area.device_count if cortical_area.device_count > 0 else 9999
			
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
			
			if fdp_result.get("success", false):
				var fdp_version = fdp_result.get("fdp_version", "unknown")
				var channel = fdp_result.get("channel", -1)
				var value = fdp_result.get("value", 0.0)
				text += " | FDP:%s CH:%d Value:%.2f%%" % [fdp_version, channel, value]
	
	_set_global_context(text)

## Show plate hover context (region name + plate kind)
func show_plate_hover(region_name: String, plate_kind: String) -> void:
	var kind := plate_kind.strip_edges()
	if kind == "":
		_set_global_context("Circuit - " + region_name)
		return
	_set_global_context("Circuit - " + region_name + " (" + kind + ")")

## Clear plate hover context (only if no cortical hover text is present)
func clear_plate_hover() -> void:
	# Optional: do not clear if cortical context is showing
	# For now, we clear unconditionally when plate hover ends
	_clear_global_context()

## Show manipulation position during 3D relocate/resize (cortical area).
func show_manipulation_position(cortical_area: AbstractCorticalArea, position_3d: Vector3i) -> void:
	if cortical_area == null:
		return
	_set_global_context("Move - " + cortical_area.friendly_name + "  " + str(position_3d))

## Show manipulation position during 3D relocate (brain region).
func show_manipulation_position_region(brain_region: BrainRegion, position_3d: Vector3i) -> void:
	if brain_region == null:
		return
	_set_global_context("Move - " + brain_region.friendly_name + "  " + str(position_3d))

func clear_manipulation_position() -> void:
	_clear_global_context()

func show_manipulation_dimensions(cortical_area: AbstractCorticalArea, dimensions_3d: Vector3i) -> void:
	if cortical_area == null:
		return
	_set_global_context("Resize - " + cortical_area.friendly_name + "  " + str(dimensions_3d))
