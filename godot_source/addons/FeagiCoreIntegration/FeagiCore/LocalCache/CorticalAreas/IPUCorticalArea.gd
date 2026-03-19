extends AbstractCorticalArea
class_name IPUCorticalArea
## Cortical area for processing inputs

signal cortical_device_count_updated(new_count: int, this_cortical_area: AbstractCorticalArea)
signal cortical_dimensions_per_device_updated(new_dims: Vector3i, this_cortical_area: AbstractCorticalArea)


var device_count: int:
	get: return _device_count

var cortical_dimensions_per_device: Vector3i:
	get: return _cortical_dimensions_per_device

var has_controller_ID: bool:
	get: return _genome_ID in FeagiCore.feagi_local_cache.IPU_cortical_ID_to_capability_key

var controller_ID: StringName:
	get: 
		if _genome_ID in FeagiCore.feagi_local_cache.IPU_cortical_ID_to_capability_key:
			return FeagiCore.feagi_local_cache.IPU_cortical_ID_to_capability_key[_genome_ID]
		else:
			return &""

func _init(ID: StringName, cortical_name: StringName, cortical_dimensions: Vector3i, visiblity: bool = true):
	var parent_region: BrainRegion = null
	if !FeagiCore.feagi_local_cache.brain_regions.is_root_available():
		push_error("FEAGI CORE CACHE: Unable to define root region for IPU %s as the root region isnt loaded!" % ID)
	else:
		parent_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	super(ID, cortical_name, cortical_dimensions, parent_region, visiblity) 

static func create_from_template(ID: StringName, template: CorticalTemplate, new_device_count: int, visiblity: bool = true) -> IPUCorticalArea:
	return IPUCorticalArea.new(ID, template.cortical_name, template.calculate_IOPU_dimension(new_device_count), visiblity)

## Helper function to safely convert dimensions data that might be Array or Dictionary
func _safe_convert_to_vector3i(data: Variant, field_name: String = "") -> Vector3i:
	if data is Array:
		return FEAGIUtils.array_to_vector3i(data)
	elif data is Dictionary:
		var dict_data: Dictionary = data as Dictionary
		# Handle common dictionary formats for 3D coordinates
		if dict_data.has("x") and dict_data.has("y") and dict_data.has("z"):
			return Vector3i(int(dict_data["x"]), int(dict_data["y"]), int(dict_data["z"]))
		elif dict_data.has("width") and dict_data.has("height") and dict_data.has("depth"):
			return Vector3i(int(dict_data["width"]), int(dict_data["height"]), int(dict_data["depth"]))
		else:
			push_error("IPU CORTICAL AREA: Unsupported dictionary format for %s: %s" % [field_name, str(dict_data)])
			return Vector3i(1, 1, 1)  # Default fallback
	else:
		push_error("IPU CORTICAL AREA: Unsupported data type for %s: %s" % [field_name, str(type_string(typeof(data)))])
		return Vector3i(1, 1, 1)  # Default fallback

## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	if data == {}:
		return
	super(data)

	if "dev_count" in data.keys():
		FEAGI_set_device_count(data["dev_count"])
	
	var total: Vector3i = _safe_convert_to_vector3i(data.get("cortical_dimensions", dimensions_3D), "cortical_dimensions")
	var per: Vector3i
	if "cortical_dimensions_per_device" in data.keys():
		per = _safe_convert_to_vector3i(data["cortical_dimensions_per_device"], "cortical_dimensions_per_device")
		if total.x > 0 and total.y > 0 and total.z > 0 and _device_count > 0:
			var dx: int = maxi(1, per.x)
			var dy: int = maxi(1, per.y)
			var dz: int = maxi(1, per.z)
			var blocks: int = (total.x / dx) * (total.y / dy) * (total.z / dz)
			if blocks != _device_count:
				per = _infer_per_device_from_total(total)
	elif total.x > 0 and total.y > 0 and total.z > 0 and _device_count > 0:
		per = _infer_per_device_from_total(total)
	else:
		per = _cortical_dimensions_per_device
	FEAGI_set_cortical_dimensions_per_device(per)

	neuron_firing_parameters.FEAGI_apply_detail_dictionary(data)
	return

## Infer per-device dimensions from total so blocks == device_count. Handles devices along x, y, or z.
func _infer_per_device_from_total(total: Vector3i) -> Vector3i:
	var px: int = (total.x / _device_count) if _device_count > 0 and total.x % _device_count == 0 else total.x
	var py: int = (total.y / _device_count) if _device_count > 0 and total.y % _device_count == 0 else total.y
	var pz: int = (total.z / _device_count) if _device_count > 0 and total.z % _device_count == 0 else total.z
	return Vector3i(maxi(1, px), maxi(1, py), maxi(1, pz))

func FEAGI_set_device_count(new_count: int) -> void:
	_device_count = new_count
	cortical_device_count_updated.emit(new_count, self)

func FEAGI_set_cortical_dimensions_per_device(new_dimensions: Vector3i) -> void:
	_cortical_dimensions_per_device = new_dimensions
	cortical_dimensions_per_device_updated.emit(new_dimensions, self)

## Given an array of configurator input capability dictionaries (recieved from agent properties), get all custom names of this cortical area
func _matches_input_unit_index(configurator_capability: Dictionary) -> bool:
	if unit_id < 0:
		return true
	var unit_indices: Variant = configurator_capability.get("input_unit_indices")
	if unit_indices is not Dictionary:
		return true
	if !unit_indices.has(str(controller_ID)):
		return true
	return int(unit_indices[str(controller_ID)]) == unit_id

func get_custom_names(configurator_capabilities: Array[Dictionary], feagi_index: int) -> Array[StringName]:
	if !has_controller_ID:
		return []
	var output: Array[StringName] = []
	for configurator_capability in configurator_capabilities:
		if !configurator_capability.has("input"):
			continue
		if !_matches_input_unit_index(configurator_capability):
			continue
		var configurator_input: Dictionary = configurator_capability["input"]
		if !configurator_input.has(str(controller_ID)):
			continue
		var devices: Dictionary = configurator_input[controller_ID]
		for device: Dictionary in devices.values():
			if !device.has("feagi_index"):
				continue
			if str(device["feagi_index"]).to_int() != feagi_index:
				continue
			var display_name: String = FEAGIUtils.resolve_agent_display_name(
				configurator_capability.get("agent_name", ""),
				configurator_capability.get("agent_ID", "")
			)
			var limb_desc: String = str(device.get("display_name", device.get("custom_name", ""))).strip_edges()
			if limb_desc.is_empty():
				continue
			output.append((display_name + ": " + limb_desc))
	return output

## Returns device properties (max_value, min_value, resolution, image_resolution) for the sensor at feagi_index.
func get_device_properties(configurator_capabilities: Array[Dictionary], feagi_index: int) -> Dictionary:
	if !has_controller_ID:
		return {}
	for configurator_capability in configurator_capabilities:
		if !configurator_capability.has("input") or configurator_capability["input"] is not Dictionary:
			continue
		if !_matches_input_unit_index(configurator_capability):
			continue
		var configurator_input: Dictionary = configurator_capability["input"]
		if !configurator_input.has(str(controller_ID)):
			continue
		var devices: Dictionary = configurator_input[controller_ID]
		for device in devices.values():
			if !(device is Dictionary):
				continue
			var dev: Dictionary = device
			if !dev.has("feagi_index") or str(dev["feagi_index"]).to_int() != feagi_index:
				continue
			var out: Dictionary = {}
			if dev.has("max_value"):
				out["max_value"] = dev["max_value"]
			if dev.has("min_value"):
				out["min_value"] = dev["min_value"]
			if dev.has("resolution"):
				out["resolution"] = dev["resolution"]
			if dev.has("image_resolution"):
				out["image_resolution"] = dev["image_resolution"]
			return out
	return {}

func _get_group() -> AbstractCorticalArea.CORTICAL_AREA_TYPE:
	return AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU

#OVERRIDDEN
func _user_can_edit_dimensions_directly() -> bool:
	return true

func _has_neuron_firing_parameters() -> bool:
	return true

var _device_count: int = 0
var _cortical_dimensions_per_device: Vector3i = Vector3i(1,1,1)

#end region

#region Neuron Firing Parameters

# Holds all Neuron Firing Parameters
var neuron_firing_parameters: CorticalPropertyNeuronFiringParameters = CorticalPropertyNeuronFiringParameters.new(self)
#endregion
