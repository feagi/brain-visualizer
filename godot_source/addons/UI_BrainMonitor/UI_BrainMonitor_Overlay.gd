extends BoxContainer
class_name UI_BrainMonitor_Overlay
## UI overlay for Brain Monitor

var _mouse_context_label: Label
var _fdp_deserializer: Object = null

## Set true to log device_index resolution (coord, per, path, result) to Godot output.
const DEBUG_DEVICE_INDEX: bool = false

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

	if ClassDB.class_exists("FeagiDataDeserializer"):
		_fdp_deserializer = ClassDB.instantiate("FeagiDataDeserializer")

## Clear all text
func clear() -> void:
	_clear_global_context()

## Resolve device index for IOPU. Uses per-device dimensions for channel/device mapping.
## For SignedPercentage/Incremental: per.x columns per joint (pos/neg); device = floor(x / per.x).
## For per.y >= 2: rows are pos/neg; device = x (each column is one joint).
func _resolve_device_index(cortical_area: AbstractCorticalArea, coord: Vector3i) -> int:
	var dc: int = cortical_area.device_count if cortical_area.device_count > 0 else 0
	var total: Vector3i = cortical_area.dimensions_3D
	var per: Vector3i = cortical_area.cortical_dimensions_per_device
	var is_incremental: bool = (str(cortical_area.coding_behavior).to_lower() == "incremental"
		or per.x >= 2
		or (dc > 0 and (total.x == 2 * dc or (total.y == 2 and total.x == dc))))
	var channels_per_joint: int = 2 if is_incremental else 1
	var per_x: int = maxi(1, per.x)
	var per_y: int = maxi(1, per.y)
	if per.x == 1 and dc > 0 and total.x == 2 * dc:
		per_x = 2
	if per.x == 1 and dc > 0 and total.y == 2 and total.x == dc:
		per_y = 2
	var device_index: int = -1
	var path: String = ""
	if _fdp_deserializer != null and (cortical_area is OPUCorticalArea or cortical_area is IPUCorticalArea):
		var id_str: String = String(cortical_area.cortical_ID)
		var encoding_info: Dictionary = _fdp_deserializer.parse_cortical_id_encoding(id_str)
		if encoding_info.get("success", false):
			var fmt: String = str(encoding_info.get("encoding_format", "")).to_lower()
			var ch_dim_x: int = per_x
			if (encoding_info.get("is_signed", false) and fmt == "1d") or (dc > 0 and total.x == 2 * dc):
				ch_dim_x = 2
			var fdp_result: Dictionary = _fdp_deserializer.decode_fdp_value(
				cortical_area.cortical_ID,
				coord.x,
				coord.y,
				coord.z,
				encoding_info.get("encoding_type", ""),
				encoding_info.get("encoding_format", ""),
				ch_dim_x,
				per.y,
				per.z,
				cortical_area.device_count if cortical_area.device_count > 0 else 9999
			)
			if fdp_result.get("success", false):
				var ch: int = fdp_result.get("channel", -1)
				if ch >= 0:
					device_index = ch / channels_per_joint
					path = "fdp ch=%d ch_dim_x=%d" % [ch, ch_dim_x]
	if device_index < 0:
		if is_incremental:
			if per_x >= 2:
				device_index = coord.x / per_x
				path = "inc_per_x"
			elif per_y >= 2:
				device_index = coord.x
				path = "inc_per_y"
			else:
				device_index = coord.x / per_x
				path = "inc_fallback"
		else:
			device_index = _neuron_coord_to_device_index(coord, cortical_area.dimensions_3D, per)
			path = "block"
	if DEBUG_DEVICE_INDEX and _fdp_deserializer != null and (cortical_area is OPUCorticalArea or cortical_area is IPUCorticalArea):
		var enc: Dictionary = _fdp_deserializer.parse_cortical_id_encoding(String(cortical_area.cortical_ID))
		print("[BV device_index] id=%s coord=%s total=%s per=%s dc=%d is_signed=%s fmt=%s is_inc=%s path=%s -> device=%d" % [
			cortical_area.cortical_ID, coord, total, per, dc,
			enc.get("is_signed", false), enc.get("encoding_format", ""), is_incremental, path, device_index])
	return device_index

## For Incremental/SignedPercentage areas: return " (+)" or " (-)" based on direction. Empty otherwise.
func _incremental_direction_suffix(cortical_area: AbstractCorticalArea, coord: Vector3i) -> String:
	var dc: int = cortical_area.device_count if cortical_area.device_count > 0 else 0
	var total: Vector3i = cortical_area.dimensions_3D
	var per_dims: Vector3i = cortical_area.cortical_dimensions_per_device
	var is_inc: bool = (str(cortical_area.coding_behavior).to_lower() == "incremental"
		or per_dims.x >= 2
		or (dc > 0 and (total.x == 2 * dc or (total.y == 2 and total.x == dc))))
	if _fdp_deserializer != null and (cortical_area is OPUCorticalArea or cortical_area is IPUCorticalArea):
		var enc: Dictionary = _fdp_deserializer.parse_cortical_id_encoding(String(cortical_area.cortical_ID))
		if enc.get("success", false) and enc.get("is_signed", false) and str(enc.get("encoding_format", "")).to_lower() == "1d":
			is_inc = true
	if not is_inc:
		return ""
	if per_dims.x >= 2:
		return " (+)" if coord.x % 2 == 0 else " (-)"
	if per_dims.y >= 2:
		return " (+)" if coord.y == 0 else " (-)"
	return " (+)" if coord.x % 2 == 0 else " (-)"

## Map neuron (x,y,z) to device index for IOPU layouts. Uses row-major 3D block layout.
func _neuron_coord_to_device_index(coord: Vector3i, total_dims: Vector3i, per_device: Vector3i) -> int:
	var dx: int = maxi(1, per_device.x)
	var dy: int = maxi(1, per_device.y)
	var dz: int = maxi(1, per_device.z)
	var blocks_x: int = maxi(1, total_dims.x / dx)
	var blocks_y: int = maxi(1, total_dims.y / dy)
	var bx: int = coord.x / dx
	var by: int = coord.y / dy
	var bz: int = coord.z / dz
	return bx + by * blocks_x + bz * blocks_x * blocks_y

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
	if DEBUG_DEVICE_INDEX:
		print("[BV mouse_over ENTRY] %s type=%s coord=%s" % [cortical_area.cortical_ID, cortical_area.cortical_type, neuron_coordinate])
	if _mouse_context_label == null:
		return
	
	if cortical_area.cortical_type not in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]:
		_set_global_context("Area - " + cortical_area.friendly_name + "  " + str(neuron_coordinate))
		return
	var text: String = "Area - " + cortical_area.friendly_name + " " + str(neuron_coordinate) + " "
	var device_index: int = 0
	if cortical_area is IPUCorticalArea or cortical_area is OPUCorticalArea:
		device_index = _resolve_device_index(cortical_area, neuron_coordinate)
		if DEBUG_DEVICE_INDEX:
			print("[BV mouse_over] %s coord=%s -> device=%d" % [cortical_area.cortical_ID, neuron_coordinate, device_index])
	if cortical_area is IPUCorticalArea:
		var dir_suffix: String = _incremental_direction_suffix(cortical_area, neuron_coordinate)
		var dir_word: String = " forward" if dir_suffix == " (+)" else " backward" if dir_suffix == " (-)" else ""
		var appending_definitions: Array[StringName] = cortical_area.get_custom_names(FeagiCore.feagi_local_cache.configuration_jsons, device_index)
		for appending in appending_definitions:
			text += "| " + str(appending) + dir_word
		var ipu_device_props: Dictionary = cortical_area.get_device_properties(FeagiCore.feagi_local_cache.configuration_jsons, device_index)
		if ipu_device_props.has("min_value") and ipu_device_props.has("max_value"):
			text += " [%.0f-%.0f]" % [float(ipu_device_props["min_value"]), float(ipu_device_props["max_value"])]
		if ipu_device_props.has("image_resolution") and ipu_device_props["image_resolution"] is Dictionary:
			var res: Dictionary = ipu_device_props["image_resolution"]
			var w: int = int(res.get("width", 0))
			var h: int = int(res.get("height", 0))
			if w > 0 and h > 0:
				text += " %dx%d" % [w, h]
		elif ipu_device_props.has("resolution") and ipu_device_props["resolution"] is Array:
			var res_arr: Array = ipu_device_props["resolution"]
			if res_arr.size() >= 2:
				text += " res:%s" % str(res_arr)
	elif cortical_area is OPUCorticalArea:
		var dir_suffix: String = _incremental_direction_suffix(cortical_area, neuron_coordinate)
		var dir_word: String = " forward" if dir_suffix == " (+)" else " backward" if dir_suffix == " (-)" else ""
		var appending_definitions: Array[StringName] = cortical_area.get_custom_names(FeagiCore.feagi_local_cache.configuration_jsons, device_index)
		for appending in appending_definitions:
			text += "| " + str(appending) + dir_word
		var device_props: Dictionary = cortical_area.get_device_properties(FeagiCore.feagi_local_cache.configuration_jsons, device_index)
		if device_props.size() > 0:
			if device_props.has("min_value") and device_props.has("max_value"):
				text += " [%.0f-%.0f]" % [float(device_props["min_value"]), float(device_props["max_value"])]
			elif device_props.has("max_power"):
				text += " max:%.0f" % float(device_props["max_power"])
			if device_props.has("image_resolution") and device_props["image_resolution"] is Dictionary:
				var res: Dictionary = device_props["image_resolution"]
				var w: int = int(res.get("width", 0))
				var h: int = int(res.get("height", 0))
				if w > 0 and h > 0:
					text += " %dx%d" % [w, h]
			elif device_props.has("resolution") and device_props["resolution"] is Array:
				var res_arr: Array = device_props["resolution"]
				if res_arr.size() >= 2:
					text += " res:%s" % str(res_arr)
		if _fdp_deserializer != null:
			var id_str_display: String = String(cortical_area.cortical_ID)
			var encoding_info = _fdp_deserializer.parse_cortical_id_encoding(id_str_display)
			if encoding_info.get("success", false):
				var encoding_type_val: String = encoding_info.get("encoding_type", "")
				var encoding_format_val: String = str(encoding_info.get("encoding_format", "")).to_lower()
				var num_channels: int = cortical_area.device_count if cortical_area.device_count > 0 else 9999
				var per_x_display: int = cortical_area.cortical_dimensions_per_device.x
				var total_x: int = cortical_area.dimensions_3D.x
				var dc_display: int = cortical_area.device_count if cortical_area.device_count > 0 else 0
				if (encoding_info.get("is_signed", false) and encoding_format_val == "1d") or (dc_display > 0 and total_x == 2 * dc_display):
					per_x_display = 2
				var ch_dim_x: int = per_x_display
				var fdp_result: Dictionary = _fdp_deserializer.decode_fdp_value(
					cortical_area.cortical_ID,
					neuron_coordinate.x,
					neuron_coordinate.y,
					neuron_coordinate.z,
					encoding_type_val,
					encoding_format_val,
					ch_dim_x,
					cortical_area.cortical_dimensions_per_device.y,
					cortical_area.cortical_dimensions_per_device.z,
					num_channels
				)
				if fdp_result.get("success", false):
					var value: float = fdp_result.get("value", 0.0)
					var signage: String = str(cortical_area.coding_signage).to_lower()
					var is_signed_coding: bool = encoding_info.get("is_signed", false)
					if signage.contains("unsigned"):
						is_signed_coding = false
					elif signage.contains("signed") or signage.contains("both"):
						is_signed_coding = true
					var signed_val: String
					if is_signed_coding and dir_suffix != "":
						signed_val = "+%.1f%%" % value if dir_suffix == " (+)" else "-%.1f%%" % value
					else:
						signed_val = "%.1f%%" % value
					text += " | value: " + signed_val
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
	_set_global_context("Relocating " + cortical_area.friendly_name + " to " + str(position_3d))

## Show manipulation position during 3D relocate (brain region).
func show_manipulation_position_region(brain_region: BrainRegion, position_3d: Vector3i) -> void:
	if brain_region == null:
		return
	_set_global_context("Relocating " + brain_region.friendly_name + " to " + str(position_3d))

func clear_manipulation_position() -> void:
	_clear_global_context()

func show_manipulation_dimensions(cortical_area: AbstractCorticalArea, dimensions_3d: Vector3i) -> void:
	if cortical_area == null:
		return
	_set_global_context("Resize - " + cortical_area.friendly_name + "  " + str(dimensions_3d))

## Show gizmo axis hover (Move in X direction, Resize along Y, etc.)
func show_gizmo_axis_hover(axis: int, is_move: bool) -> void:
	var axis_name: String = ["X", "Y", "Z"][axis] if axis >= 0 and axis <= 2 else "?"
	var action: String = "Move in %s direction" % axis_name if is_move else "Resize along %s" % axis_name
	_set_global_context(action)

## Show gizmo cancel button hover
func show_gizmo_cancel_hover() -> void:
	_set_global_context("Cancel relocation (X)")
