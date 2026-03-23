extends BoxContainer
class_name UI_BrainMonitor_Overlay
## UI overlay for Brain Monitor

var _mouse_context_label: Label
var _fdp_deserializer: Object = null

## Set true to log device_index resolution (coord, per, path, result) to Godot output.
const DEBUG_DEVICE_INDEX: bool = false

## Set true to log full hover text and decode inputs when hovering over IPU/OPU.
const DEBUG_HOVER_TEXT: bool = false

## Set true to log joint/device details (device_index, custom_names, device_props) when hovering over IPU/OPU.
const DEBUG_JOINT_DETAILS: bool = false

## Set true to print hover mapping diagnostics (index resolution + config index coverage).
## Temporary troubleshooting switch for IOPU channel mapping mismatches.
const DEBUG_HOVER_MAPPING: bool = false

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
	if per.z <= 1 and total.z > 1:
		per = Vector3i(per.x, per.y, total.z)
	var is_incremental: bool = (str(cortical_area.coding_behavior).to_lower() == "incremental"
		or per.x >= 2
		or (dc > 0 and (total.x == 2 * dc or (total.y == 2 and total.x == dc))))
	# If runtime area metadata reports 1x1x1 (or otherwise incomplete per-device dims),
	# infer channel count/width from capability indices used by hover name resolution.
	var matched_indices: Array[int] = _collect_matching_config_indices(cortical_area)
	if matched_indices.size() > 0:
		var inferred_channels: int = matched_indices[matched_indices.size() - 1] + 1
		if inferred_channels > 0 and (dc <= 0 or inferred_channels < dc):
			dc = inferred_channels
	var per_x: int = maxi(1, per.x)
	var per_y: int = maxi(1, per.y)
	var per_z: int = maxi(1, per.z)
	if is_incremental and dc > 0:
		if per_x == 1 and total.y == 1 and total.x % dc == 0:
			var inferred_lane_width_x: int = total.x / dc
			if inferred_lane_width_x > 1:
				per_x = inferred_lane_width_x
		if per_y == 1 and total.x == dc and total.y % dc == 0:
			var inferred_lane_width_y: int = total.y / dc
			if inferred_lane_width_y > 1:
				per_y = inferred_lane_width_y
	if per.x == 1 and dc > 0 and total.x == 2 * dc:
		per_x = 2
	if per.x == 1 and dc > 0 and total.y == 2 and total.x == dc:
		per_y = 2
	var num_channels: int = dc
	if num_channels <= 0:
		var per_vol: int = per_x * per_y * per_z
		num_channels = maxi(1, (total.x * total.y * total.z) / maxi(1, per_vol))
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
				encoding_info.get("is_signed", false),
				ch_dim_x,
				per_y,
				per_z,
				num_channels
			)
			if fdp_result.get("success", false):
				var ch: int = fdp_result.get("channel", -1)
				if ch >= 0:
					device_index = ch
					path = "fdp ch=%d ch_dim_x=%d" % [ch, ch_dim_x]
	if device_index < 0:
		if is_incremental:
			# Incremental/signed areas can encode forward/backward lanes across X or Y,
			# but channel ownership still follows full per-device 3D block mapping.
			# This keeps 2x1xZ (or 1x2xZ) lanes tied to one joint/channel across depth.
			device_index = _neuron_coord_to_device_index(coord, total, Vector3i(per_x, per_y, per_z))
			path = "inc_block"
		else:
			device_index = _neuron_coord_to_device_index(coord, cortical_area.dimensions_3D, per)
			path = "block"
	if DEBUG_DEVICE_INDEX and _fdp_deserializer != null and (cortical_area is OPUCorticalArea or cortical_area is IPUCorticalArea):
		var enc: Dictionary = _fdp_deserializer.parse_cortical_id_encoding(String(cortical_area.cortical_ID))
		print("[BV device_index] id=%s coord=%s total=%s per=%s dc=%d is_signed=%s fmt=%s is_inc=%s path=%s -> device=%d" % [
			cortical_area.cortical_ID, coord, total, per, dc,
			enc.get("is_signed", false), enc.get("encoding_format", ""), is_incremental, path, device_index])
	return device_index

func _get_effective_incremental_lane_dims(cortical_area: AbstractCorticalArea) -> Vector3i:
	var total: Vector3i = cortical_area.dimensions_3D
	var per_dims: Vector3i = cortical_area.cortical_dimensions_per_device
	var dc: int = cortical_area.device_count if cortical_area.device_count > 0 else 0
	var matched_indices: Array[int] = _collect_matching_config_indices(cortical_area)
	if matched_indices.size() > 0:
		var inferred_channels: int = matched_indices[matched_indices.size() - 1] + 1
		if inferred_channels > 0 and (dc <= 0 or inferred_channels < dc):
			dc = inferred_channels
	var lane_x: int = maxi(1, per_dims.x)
	var lane_y: int = maxi(1, per_dims.y)
	var lane_z: int = maxi(1, per_dims.z)
	if lane_z <= 1 and total.z > 1:
		lane_z = total.z
	if dc > 0:
		if lane_x == 1 and total.y == 1 and total.x % dc == 0:
			var inferred_lane_width_x: int = total.x / dc
			if inferred_lane_width_x > 1:
				lane_x = inferred_lane_width_x
		if lane_y == 1 and total.x == dc and total.y % dc == 0:
			var inferred_lane_width_y: int = total.y / dc
			if inferred_lane_width_y > 1:
				lane_y = inferred_lane_width_y
	return Vector3i(lane_x, lane_y, lane_z)

## For Incremental/SignedPercentage areas: return " (+)" or " (-)" based on direction. Empty otherwise.
func _incremental_direction_suffix(cortical_area: AbstractCorticalArea, coord: Vector3i) -> String:
	var dc: int = cortical_area.device_count if cortical_area.device_count > 0 else 0
	var total: Vector3i = cortical_area.dimensions_3D
	var per_dims: Vector3i = _get_effective_incremental_lane_dims(cortical_area)
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
		var lane_x_pos: int = coord.x % per_dims.x
		return " (+)" if lane_x_pos < maxi(1, per_dims.x / 2) else " (-)"
	if per_dims.y >= 2:
		var lane_y_pos: int = coord.y % per_dims.y
		return " (+)" if lane_y_pos < maxi(1, per_dims.y / 2) else " (-)"
	return " (+)" if coord.x % 2 == 0 else " (-)"

## Returns decoded value suffix for footnote using feagi-sensorimotor (matches robot processing).
## API returns encoding_format=Linear/Fractional (positioning), encoding_type=Absolute/Incremental (frame).
## Decode expects encoding_type=linear/exponential (positioning), encoding_format=1d/2d/3d/4d (ndim).
func _get_decoded_value_suffix(cortical_area: AbstractCorticalArea, neuron_coordinate: Vector3i) -> String:
	if _fdp_deserializer == null:
		return ""
	var per: Vector3i = cortical_area.cortical_dimensions_per_device
	var total: Vector3i = cortical_area.dimensions_3D
	if per.z <= 1 and total.z > 1:
		per = Vector3i(per.x, per.y, total.z)
	var num_channels: int = cortical_area.device_count
	if num_channels <= 0:
		var per_vol: int = maxi(1, per.x) * maxi(1, per.y) * maxi(1, per.z)
		num_channels = maxi(1, (total.x * total.y * total.z) / per_vol)
	var api_enc_type: String = str(cortical_area.encoding_type)
	if api_enc_type.is_empty():
		api_enc_type = str(cortical_area.coding_behavior)
	var api_enc_fmt: String = str(cortical_area.encoding_format)
	if api_enc_fmt.is_empty():
		api_enc_fmt = str(cortical_area.coding_type)
	var enc_type: String
	var enc_fmt: String
	if api_enc_fmt.to_lower() in ["linear", "fractional", "exponential"]:
		enc_type = api_enc_fmt
		enc_fmt = "1d" if per.x <= 2 and per.y <= 1 else "2d"
	else:
		enc_type = api_enc_type if api_enc_type.to_lower() in ["linear", "fractional", "exponential"] else "linear"
		enc_fmt = api_enc_fmt if api_enc_fmt.to_lower() in ["1d", "2d", "3d", "4d"] else "1d"
	var is_signed: bool = "signed" in str(cortical_area.coding_signage).to_lower()
	var fdp_result: Dictionary = _fdp_deserializer.decode_fdp_value(
		cortical_area.cortical_ID,
		neuron_coordinate.x,
		neuron_coordinate.y,
		neuron_coordinate.z,
		enc_type,
		enc_fmt,
		is_signed,
		per.x,
		per.y,
		per.z,
		num_channels
	)
	if DEBUG_HOVER_TEXT:
		print("[BV HOVER] decode id=%s coord=%s enc_type=%s enc_fmt=%s per=%s num_ch=%d success=%s value=%s error=%s" % [
			cortical_area.cortical_ID, neuron_coordinate, enc_type, enc_fmt, per, num_channels,
			fdp_result.get("success", false), fdp_result.get("value", 0.0), fdp_result.get("error", "")])
	if not fdp_result.get("success", false):
		return ""
	var value: float = fdp_result.get("value", 0.0)
	var data_type: String = fdp_result.get("data_type", "")
	var suffix: String = " | value: %.1f%%" % value
	if data_type != "":
		suffix += " - " + data_type.replace("_", " ").to_lower()
	return suffix

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

func _collect_matching_config_indices(cortical_area: AbstractCorticalArea) -> Array[int]:
	var output: Array[int] = []
	if cortical_area == null:
		return output
	if not (cortical_area is IPUCorticalArea or cortical_area is OPUCorticalArea):
		return output
	var section_key: String = "input" if cortical_area is IPUCorticalArea else "output"
	var unit_key: String = section_key + "_unit_indices"
	var ctrl_id: String = ""
	if cortical_area is IPUCorticalArea:
		var ipu_area: IPUCorticalArea = cortical_area
		if ipu_area.has_controller_ID:
			ctrl_id = str(ipu_area.controller_ID)
	elif cortical_area is OPUCorticalArea:
		var opu_area: OPUCorticalArea = cortical_area
		if opu_area.has_controller_ID:
			ctrl_id = str(opu_area.controller_ID)
	if ctrl_id == "":
		return output
	var config_jsons: Array[Dictionary] = FeagiCore.feagi_local_cache.configuration_jsons
	for cfg in config_jsons:
		var unit_indices: Variant = cfg.get(unit_key)
		if unit_indices is Dictionary and cortical_area.unit_id >= 0 and (unit_indices as Dictionary).has(ctrl_id):
			if int((unit_indices as Dictionary)[ctrl_id]) != cortical_area.unit_id:
				continue
		var section: Variant = cfg.get(section_key)
		if section is not Dictionary:
			continue
		var typed_section: Dictionary = section
		if not typed_section.has(ctrl_id):
			continue
		var devices: Variant = typed_section[ctrl_id]
		if devices is not Dictionary:
			continue
		for device in (devices as Dictionary).values():
			if device is not Dictionary:
				continue
			var dev: Dictionary = device
			if not dev.has("feagi_index"):
				continue
			var idx: int = int(dev["feagi_index"])
			if idx not in output:
				output.append(idx)
	output.sort()
	return output

func _log_hover_mapping_diagnostics(
	cortical_area: AbstractCorticalArea,
	neuron_coordinate: Vector3i,
	device_index: int,
	label_matches: Array[StringName]
) -> void:
	if not DEBUG_HOVER_MAPPING:
		return
	if cortical_area == null:
		return
	var per: Vector3i = Vector3i.ONE
	if cortical_area is IPUCorticalArea:
		per = (cortical_area as IPUCorticalArea).cortical_dimensions_per_device
	elif cortical_area is OPUCorticalArea:
		per = (cortical_area as OPUCorticalArea).cortical_dimensions_per_device
	var total: Vector3i = cortical_area.dimensions_3D
	var ctrl_id: String = ""
	if cortical_area is IPUCorticalArea:
		var ipu_area: IPUCorticalArea = cortical_area
		if ipu_area.has_controller_ID:
			ctrl_id = str(ipu_area.controller_ID)
	elif cortical_area is OPUCorticalArea:
		var opu_area: OPUCorticalArea = cortical_area
		if opu_area.has_controller_ID:
			ctrl_id = str(opu_area.controller_ID)
	var matched_indices: Array[int] = _collect_matching_config_indices(cortical_area)
	var index_hit: bool = device_index in matched_indices
	print("[BV hover-map] area=%s type=%s ctrl=%s unit=%d coord=%s total=%s per=%s idx=%d idx_hit=%s match_count=%d labels=%s matching_indices=%s" % [
		cortical_area.cortical_ID,
		cortical_area.cortical_type,
		ctrl_id,
		cortical_area.unit_id,
		neuron_coordinate,
		total,
		per,
		device_index,
		index_hit,
		label_matches.size(),
		label_matches,
		matched_indices
	])

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

func _get_area_action_mode_text(cortical_area: AbstractCorticalArea) -> String:
	var behavior := str(cortical_area.coding_behavior).strip_edges().to_lower()
	if behavior == "absolute":
		return "absolute positioning"
	if behavior == "incremental":
		return "incremental"
	var encoding_type := str(cortical_area.encoding_type).strip_edges().to_lower()
	if encoding_type == "absolute":
		return "absolute positioning"
	if encoding_type == "incremental":
		return "incremental"
	# Fallback: derive frame mode from cortical ID bytes.
	# ID layout: [unit_ref(4), cfg_lo, cfg_hi, sub_unit, unit_index]
	# cfg bit 8 encodes frame handling (0=absolute, 1=incremental).
	var cid := str(cortical_area.cortical_ID).strip_edges()
	if cid != "":
		var raw: PackedByteArray = Marshalls.base64_to_raw(cid)
		if raw.size() >= 7:
			var cfg: int = int(raw[4]) | (int(raw[5]) << 8)
			var frame_flag: int = (cfg >> 8) & 0x01
			if frame_flag == 1:
				return "incremental"
			if frame_flag == 0:
				return "absolute positioning"
			var sub_unit: int = int(raw[6])
			if sub_unit == 1:
				return "incremental"
			if sub_unit == 0:
				return "absolute positioning"
	return ""

func _get_area_frame_mode_token(cortical_area: AbstractCorticalArea) -> String:
	var mode_text := _get_area_action_mode_text(cortical_area)
	if mode_text == "absolute positioning":
		return "absolute"
	return mode_text

func _get_area_percentage_token(cortical_area: AbstractCorticalArea) -> String:
	var signage := str(cortical_area.coding_signage).strip_edges().to_lower()
	if signage.find("percentage") >= 0:
		if signage.find("signed") >= 0:
			return "percentage signed"
		if signage.find("unsigned") >= 0:
			return "percentage unsigned"
		return "percentage"
	# Fallback: derive from cortical ID variant when signage metadata is absent.
	var cid := str(cortical_area.cortical_ID).strip_edges()
	if cid != "":
		var raw: PackedByteArray = Marshalls.base64_to_raw(cid)
		if raw.size() >= 6:
			var cfg: int = int(raw[4]) | (int(raw[5]) << 8)
			var variant: int = cfg & 0xFF
			if variant == 5:
				return "percentage signed"
			if variant == 1:
				return "percentage unsigned"
	return ""

func _get_area_encoding_summary_text(cortical_area: AbstractCorticalArea) -> String:
	var parts: Array[String] = []
	var positioning := str(cortical_area.coding_type).strip_edges().to_lower()
	if positioning == "":
		var enc_format := str(cortical_area.encoding_format).strip_edges().to_lower()
		if enc_format in ["linear", "fractional", "exponential"]:
			positioning = enc_format
	if positioning != "":
		parts.append(positioning)
	var frame_mode := _get_area_frame_mode_token(cortical_area)
	if frame_mode != "":
		parts.append(frame_mode)
	var percentage := _get_area_percentage_token(cortical_area)
	if percentage != "":
		parts.append(percentage)
	return " - ".join(parts)

func mouse_over_single_cortical_area(cortical_area: AbstractCorticalArea, neuron_coordinate: Vector3i) -> void:
	if DEBUG_DEVICE_INDEX:
		print("[BV mouse_over ENTRY] %s type=%s coord=%s" % [cortical_area.cortical_ID, cortical_area.cortical_type, neuron_coordinate])
	if _mouse_context_label == null:
		return
	
	if cortical_area.cortical_type not in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]:
		_set_global_context("Area - " + cortical_area.friendly_name + "  " + str(neuron_coordinate))
		return
	var text: String = "Area - " + cortical_area.friendly_name + " " + str(neuron_coordinate) + " "
	var encoding_summary := _get_area_encoding_summary_text(cortical_area)
	var device_index: int = 0
	if cortical_area is IPUCorticalArea or cortical_area is OPUCorticalArea:
		device_index = _resolve_device_index(cortical_area, neuron_coordinate)
		if DEBUG_DEVICE_INDEX:
			print("[BV mouse_over] %s coord=%s -> device=%d" % [cortical_area.cortical_ID, neuron_coordinate, device_index])
	if cortical_area is IPUCorticalArea:
		var dir_suffix: String = _incremental_direction_suffix(cortical_area, neuron_coordinate)
		var dir_word: String = " (Forward)" if dir_suffix == " (+)" else " (Backward)" if dir_suffix == " (-)" else ""
		var ipu_ctrl_id: String = str(cortical_area.controller_ID) if cortical_area.has_controller_ID else ""
		var ipu_is_motor_ctrl: bool = (ipu_ctrl_id == "positional_servo" or ipu_ctrl_id == "rotary_motor")
		var appending_definitions: Array[StringName] = cortical_area.get_custom_names(FeagiCore.feagi_local_cache.configuration_jsons, device_index)
		if DEBUG_JOINT_DETAILS and ipu_is_motor_ctrl:
			var ctrl_id: String = ipu_ctrl_id if ipu_ctrl_id != "" else "(none)"
			var input_keys_per_config: Array[String] = []
			for cfg in FeagiCore.feagi_local_cache.configuration_jsons:
				var inp: Variant = cfg.get("input")
				if inp is Dictionary:
					input_keys_per_config.append(str((inp as Dictionary).keys()))
				else:
					input_keys_per_config.append("(no input dict)")
			print("[BV joint] IPU id=%s coord=%s device_index=%d has_ctrl=%s ctrl_id=%s custom_names=%s config_count=%d input_keys=%s" % [
				cortical_area.cortical_ID, neuron_coordinate, device_index, cortical_area.has_controller_ID, ctrl_id, appending_definitions,
				FeagiCore.feagi_local_cache.configuration_jsons.size(), input_keys_per_config])
		for appending in appending_definitions:
			text += "| " + str(appending) + dir_word
		_log_hover_mapping_diagnostics(cortical_area, neuron_coordinate, device_index, appending_definitions)
		var ipu_device_props: Dictionary = cortical_area.get_device_properties(FeagiCore.feagi_local_cache.configuration_jsons, device_index)
		if DEBUG_JOINT_DETAILS:
			print("[BV joint] IPU id=%s device_index=%d device_props=%s" % [cortical_area.cortical_ID, device_index, ipu_device_props])
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
		var decoded_suffix: String = _get_decoded_value_suffix(cortical_area, neuron_coordinate)
		if decoded_suffix != "":
			text += decoded_suffix
	elif cortical_area is OPUCorticalArea:
		var dir_suffix: String = _incremental_direction_suffix(cortical_area, neuron_coordinate)
		var dir_word: String = " (Forward)" if dir_suffix == " (+)" else " (Backward)" if dir_suffix == " (-)" else ""
		var opu_ctrl_id: String = str(cortical_area.controller_ID) if cortical_area.has_controller_ID else ""
		var opu_is_motor_ctrl: bool = (opu_ctrl_id == "positional_servo" or opu_ctrl_id == "rotary_motor")
		var appending_definitions: Array[StringName] = cortical_area.get_custom_names(FeagiCore.feagi_local_cache.configuration_jsons, device_index)
		if DEBUG_JOINT_DETAILS and opu_is_motor_ctrl:
			var ctrl_id: String = opu_ctrl_id if opu_ctrl_id != "" else "(none)"
			var feagi_indices_in_config: Array[String] = []
			for cfg in FeagiCore.feagi_local_cache.configuration_jsons:
				var out: Variant = cfg.get("output")
				if out is Dictionary:
					var devs: Variant = (out as Dictionary).get(ctrl_id, {})
					if devs is Dictionary:
						var indices: Array[int] = []
						for dev in (devs as Dictionary).values():
							if dev is Dictionary and (dev as Dictionary).has("feagi_index"):
								indices.append(int((dev as Dictionary)["feagi_index"]))
						feagi_indices_in_config.append(str(indices))
					else:
						feagi_indices_in_config.append("(no devices)")
				else:
					feagi_indices_in_config.append("(no output)")
			print("[BV joint] OPU id=%s coord=%s device_index=%d ctrl_id=%s custom_names=%s feagi_indices_in_config=%s" % [
				cortical_area.cortical_ID, neuron_coordinate, device_index, ctrl_id, appending_definitions, feagi_indices_in_config])
		for appending in appending_definitions:
			text += "| " + str(appending) + dir_word
		_log_hover_mapping_diagnostics(cortical_area, neuron_coordinate, device_index, appending_definitions)
		var device_props: Dictionary = cortical_area.get_device_properties(FeagiCore.feagi_local_cache.configuration_jsons, device_index)
		if DEBUG_JOINT_DETAILS:
			print("[BV joint] OPU id=%s device_index=%d device_props=%s" % [cortical_area.cortical_ID, device_index, device_props])
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
		var decoded_suffix: String = _get_decoded_value_suffix(cortical_area, neuron_coordinate)
		if decoded_suffix != "":
			text += decoded_suffix
	if encoding_summary != "":
		text += " | " + encoding_summary
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
	
	if DEBUG_HOVER_TEXT:
		print("[BV HOVER] full_text=\"%s\"" % text)
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
