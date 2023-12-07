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

	if "initial_neuron_lifespan" in data.keys(): 
		initial_neuron_lifespan = data["initial_neuron_lifespan"]
	if "lifespan_growth_rate" in data.keys(): 
		lifespan_growth_rate = data["lifespan_growth_rate"]
	if "longterm_memory_threshold" in data.keys(): 
		longterm_memory_threshold = data["longterm_memory_threshold"]
	return

func _get_group() -> BaseCorticalArea.CORTICAL_AREA_TYPE:
	return BaseCorticalArea.CORTICAL_AREA_TYPE.MEMORY

#region Memory Parameters
var initial_neuron_lifespan: float = 0
var lifespan_growth_rate: float = 0
var longterm_memory_threshold: float = 0
#endregion