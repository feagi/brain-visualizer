extends BaseCorticalArea
class_name MemoryCorticalArea
## Also know as "Interconnect" Cortical Area

func _init(ID: StringName, cortical_name: StringName, cortical_dimensions: Vector3i, visiblity: bool = true):
	_cortical_ID = ID
	_name = cortical_name
	_dimensions = cortical_dimensions
	_cortical_visiblity = visiblity

## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	if data == {}:
		return
	super(data)

	memory_parameters.FEAGI_apply_detail_dictionary(data)

func _get_group() -> BaseCorticalArea.CORTICAL_AREA_TYPE:
	return BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY

# OVERRIDDEN
func _user_can_edit_cortical_neuron_per_vox_count() -> bool:
	return false

# OVERRIDDEN
func _user_can_edit_cortical_synaptic_attractivity() -> bool:
	return false

#OVERRIDDEN
func _user_can_clone_this_area() -> bool:
	return true

func _has_memory_parameters() -> bool:
	return true

#region Memory Parameters

## Holds all memory parameters
var memory_parameters: CorticalPropertyMemoryParameters = CorticalPropertyMemoryParameters.new(self)
#endregion
