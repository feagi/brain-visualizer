extends RefCounted
class_name CorticalPropertyMemoryParameters

signal initial_neuron_lifespan_updated(val: int, this_cortical_area: MemoryCorticalArea)
signal lifespan_growth_rate_updated(val: int, this_cortical_area: MemoryCorticalArea)
signal longterm_memory_threshold_updated(val: int, this_cortical_area: MemoryCorticalArea)

## Apply Properties from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:

	if "neuron_init_lifespan" in data.keys(): 
		initial_neuron_lifespan = data["neuron_init_lifespan"]
	if "neuron_lifespan_growth_rate" in data.keys(): 
		lifespan_growth_rate = data["neuron_lifespan_growth_rate"]
	if "neuron_longterm_mem_threshold" in data.keys(): 
		longterm_memory_threshold = data["neuron_longterm_mem_threshold"]
	return

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
var _cortical_area: BaseCorticalArea

func _init(cortical_area_ref: BaseCorticalArea) -> void:
	_cortical_area = cortical_area_ref

func _set_initial_neuron_lifespan(new_val: int) -> void:
	if new_val == _initial_neuron_lifespan: 
		return
	_initial_neuron_lifespan = new_val
	initial_neuron_lifespan_updated.emit(new_val, _cortical_area)

func _set_lifespan_growth_rate(new_val: int) -> void:
	if new_val == _lifespan_growth_rate: 
		return
	_lifespan_growth_rate = new_val
	lifespan_growth_rate_updated.emit(new_val, _cortical_area)

func _set_longterm_memory_threshold(new_val: int) -> void:
	if new_val == _longterm_memory_threshold: 
		return
	_longterm_memory_threshold = new_val
	longterm_memory_threshold_updated.emit(new_val, _cortical_area)
