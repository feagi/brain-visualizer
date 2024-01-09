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

	if "neuron_init_lifespan" in data.keys(): 
		initial_neuron_lifespan = data["neuron_init_lifespan"]
	if "neuron_lifespan_growth_rate" in data.keys(): 
		lifespan_growth_rate = data["neuron_lifespan_growth_rate"]
	if "neuron_longterm_mem_threshold" in data.keys(): 
		longterm_memory_threshold = data["neuron_longterm_mem_threshold"]
	return

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
signal initial_neuron_lifespan_updated(val: int, this_cortical_area: MemoryCorticalArea)
signal lifespan_growth_rate_updated(val: int, this_cortical_area: MemoryCorticalArea)
signal longterm_memory_threshold_updated(val: int, this_cortical_area: MemoryCorticalArea)

var initial_neuron_lifespan: int:
	get:
		return _initial_neuron_lifespan
	set(v):
		_set_initial_neuron_lifespan(v)

var lifespan_growth_rate: int:
	get:
		return _lifespan_growth_rate
	set(v):
		_set_lifespan_growth_rate(v)

var longterm_memory_threshold: int:
	get:
		return _longterm_memory_threshold
	set(v):
		_set_longterm_memory_threshold(v)

var _initial_neuron_lifespan: int = 0
var _lifespan_growth_rate: int = 0
var _longterm_memory_threshold: int = 0

func _set_initial_neuron_lifespan(new_val: int) -> void:
	if new_val == _initial_neuron_lifespan: 
		return
	_initial_neuron_lifespan = new_val
	initial_neuron_lifespan_updated.emit(new_val, self)

func _set_lifespan_growth_rate(new_val: int) -> void:
	if new_val == _lifespan_growth_rate: 
		return
	_lifespan_growth_rate = new_val
	lifespan_growth_rate_updated.emit(new_val, self)

func _set_longterm_memory_threshold(new_val: int) -> void:
	if new_val == _longterm_memory_threshold: 
		return
	_longterm_memory_threshold = new_val
	longterm_memory_threshold_updated.emit(new_val, self)
#endregion
