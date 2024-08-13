extends AbstractCorticalArea
class_name MemoryCorticalArea
## A Memory cortical area object. In FEAGI this is a subtype of the custom cortical area object, but here we have it as a completely independent object from the custom cortical area

func _init(ID: StringName, cortical_name: StringName, cortical_dimensions: Vector3i, parent_region: BrainRegion, visiblity: bool = true):
	super(ID, cortical_name, cortical_dimensions, parent_region, visiblity) # This abstraction is useless right now! Too Bad!

## Updates all cortical details in here from a dict from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	if data == {}:
		return
	super(data)

	memory_parameters.FEAGI_apply_detail_dictionary(data)

func _get_group() -> AbstractCorticalArea.CORTICAL_AREA_TYPE:
	return AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY

# OVERRIDDEN
func _user_can_edit_cortical_neuron_per_vox_count() -> bool:
	return false

# OVERRIDDEN
func _user_can_edit_cortical_synaptic_attractivity() -> bool:
	return false

#OVERRIDDEN
func _user_can_clone_this_area() -> bool:
	return true

#OVERRIDDEN
func _user_can_edit_dimensions_directly() -> bool:
	return false

func _has_memory_parameters() -> bool:
	return true

#region Memory Parameters

## Holds all memory parameters
var memory_parameters: CorticalPropertyMemoryParameters = CorticalPropertyMemoryParameters.new(self)
#endregion
