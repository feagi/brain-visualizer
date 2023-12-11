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

# OVERRIDDEN
func _user_can_edit_cortical_neuron_per_vox_count() -> bool:
	return false

# OVERRIDDEN
func _user_can_edit_cortical_synaptic_attractivity() -> bool:
	return false

#region Memory Parameters
signal initial_neuron_lifespan_updated(val: bool, this_cortical_area: MemoryCorticalArea)
signal lifespan_growth_rate_updated(val: int, this_cortical_area: MemoryCorticalArea)
signal longterm_memory_threshold_updated(val: int, this_cortical_area: MemoryCorticalArea)

var initial_neuron_lifespan: float:
	get:
		return _initial_neuron_lifespan
	set(v):
		_set_initial_neuron_lifespan(v)

var lifespan_growth_rate: float:
	get:
		return _lifespan_growth_rate
	set(v):
		_set_lifespan_growth_rate(v)

var longterm_memory_threshold: float:
	get:
		return _longterm_memory_threshold
	set(v):
		_set_longterm_memory_threshold(v)

var _initial_neuron_lifespan: float = 0
var _lifespan_growth_rate: float = 0
var _longterm_memory_threshold: float = 0

func _set_initial_neuron_lifespan(new_val: float) -> void:
	if new_val == _initial_neuron_lifespan: 
		return
	_initial_neuron_lifespan = new_val
	initial_neuron_lifespan_updated.emit(new_val, self)

func _set_lifespan_growth_rate(new_val: float) -> void:
	if new_val == _lifespan_growth_rate: 
		return
	_lifespan_growth_rate = new_val
	lifespan_growth_rate_updated.emit(new_val, self)

func _set_longterm_memory_threshold(new_val: float) -> void:
	if new_val == _longterm_memory_threshold: 
		return
	_longterm_memory_threshold = new_val
	longterm_memory_threshold_updated.emit(new_val, self)
#endregion