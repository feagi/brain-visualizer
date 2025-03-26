extends BoxContainer
class_name UI_BrainMonitor_Overlay
## UI overlay for Brain Monitor

var _mouse_context_label: Label

func _ready() -> void:
	_mouse_context_label = $Bottom_Row/MouseContext

## Clear all text
func clear() -> void:
	_mouse_context_label.text = ""

func mouse_over_single_cortical_area(cortical_area: AbstractCorticalArea, neuron_coordinate: Vector3i) -> void:
	if cortical_area.cortical_type not in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]:
		_mouse_context_label.text = cortical_area.friendly_name + "  " + str(neuron_coordinate)
		return
	var text: String = cortical_area.friendly_name + " " + str(neuron_coordinate) + " "
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
	_mouse_context_label.text = text
