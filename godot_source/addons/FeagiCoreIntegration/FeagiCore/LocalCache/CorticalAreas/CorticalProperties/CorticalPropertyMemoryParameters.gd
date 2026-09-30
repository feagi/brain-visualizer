extends RefCounted
class_name CorticalPropertyMemoryParameters

signal initial_neuron_lifespan_updated(val: int, this_cortical_area: MemoryCorticalArea)
signal lifespan_growth_rate_updated(val: int, this_cortical_area: MemoryCorticalArea)
signal longterm_memory_threshold_updated(val: int, this_cortical_area: MemoryCorticalArea)
signal temporal_depth_updated(val: int, this_costical_area: MemoryCorticalArea)
signal mp_learning_enabled_updated(val: bool, this_cortical_area: MemoryCorticalArea)
signal mp_change_mode_updated(val: StringName, this_cortical_area: MemoryCorticalArea)
signal mp_delta_quantization_updated(val: float, this_cortical_area: MemoryCorticalArea)
signal mp_ratio_quantization_updated(val: float, this_cortical_area: MemoryCorticalArea)

## FEAGI `mp_change_mode` values.
const MP_CHANGE_NONE: StringName = &"none"
const MP_CHANGE_DIFFERENTIAL: StringName = &"mp_differential"
const MP_CHANGE_RATIO: StringName = &"mp_ratio"
## Mirror FEAGI's MemoryAreaProperties defaults; shown until FEAGI reports genome values.
const DEFAULT_MP_DELTA_QUANTIZATION: float = 1.0
const DEFAULT_MP_RATIO_QUANTIZATION: float = 20.0

## Single user-facing MP encoding choice. FEAGI stores it as two mutually exclusive
## keys (`mp_learning_enabled`, `mp_change_mode`); these labels are the dropdown items.
const MP_ENCODING_NONE: StringName = &"None"
const MP_ENCODING_LEARNING: StringName = &"MP Learning"
const MP_ENCODING_DIFFERENTIAL: StringName = &"MP Differential"
const MP_ENCODING_RATIO: StringName = &"MP Ratio"
const MP_ENCODING_OPTIONS: Array[StringName] = [
	MP_ENCODING_NONE, MP_ENCODING_LEARNING, MP_ENCODING_DIFFERENTIAL, MP_ENCODING_RATIO
]

## Dropdown label for the FEAGI key pair.
static func mp_encoding_from_keys(learning_enabled: bool, change_mode: StringName) -> StringName:
	if change_mode == MP_CHANGE_DIFFERENTIAL:
		return MP_ENCODING_DIFFERENTIAL
	if change_mode == MP_CHANGE_RATIO:
		return MP_ENCODING_RATIO
	if learning_enabled:
		return MP_ENCODING_LEARNING
	return MP_ENCODING_NONE

## FEAGI key pair for a dropdown label; always sets both keys so they never conflict.
static func mp_encoding_to_keys(encoding: StringName) -> Dictionary:
	var change_mode: StringName = MP_CHANGE_NONE
	if encoding == MP_ENCODING_DIFFERENTIAL:
		change_mode = MP_CHANGE_DIFFERENTIAL
	elif encoding == MP_ENCODING_RATIO:
		change_mode = MP_CHANGE_RATIO
	return {
		"mp_learning_enabled": encoding == MP_ENCODING_LEARNING,
		"mp_change_mode": String(change_mode),
	}

## Apply Properties from FEAGI
func FEAGI_apply_detail_dictionary(data: Dictionary) -> void:
	# Initial Lifespan - check both formats
	if "neuron_init_lifespan" in data.keys(): 
		var value = data["neuron_init_lifespan"]
		if value != null:
			initial_neuron_lifespan = value
	elif "init_lifespan" in data.keys():
		var value = data["init_lifespan"]
		if value != null:
			initial_neuron_lifespan = value
	
	# Lifespan Growth Rate - check both formats
	if "neuron_lifespan_growth_rate" in data.keys(): 
		var value = data["neuron_lifespan_growth_rate"]
		if value != null:
			lifespan_growth_rate = value
	elif "lifespan_growth_rate" in data.keys():
		var value = data["lifespan_growth_rate"]
		if value != null:
			lifespan_growth_rate = value
	
	# Longterm Memory Threshold - check both formats
	if "neuron_longterm_mem_threshold" in data.keys(): 
		var value = data["neuron_longterm_mem_threshold"]
		if value != null:
			longterm_memory_threshold = value
	elif "longterm_mem_threshold" in data.keys():
		var value = data["longterm_mem_threshold"]
		if value != null:
			longterm_memory_threshold = value
	
	# Temporal Depth - already doesn't have neuron_ prefix
	if "temporal_depth" in data.keys():
		var value = data["temporal_depth"]
		if value != null:
			temporal_depth = value

	# MP Learning Enabled
	if "mp_learning_enabled" in data.keys():
		var value = data["mp_learning_enabled"]
		if value != null:
			mp_learning_enabled = value

	if "mp_change_mode" in data.keys():
		var value = data["mp_change_mode"]
		if value != null:
			mp_change_mode = StringName(str(value))

	if "mp_delta_quantization" in data.keys():
		var value = data["mp_delta_quantization"]
		if value != null:
			mp_delta_quantization = float(value)

	if "mp_ratio_quantization" in data.keys():
		var value = data["mp_ratio_quantization"]
		if value != null:
			mp_ratio_quantization = float(value)
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

var temporal_depth: int:
	get:
		return _temporal_depth
	set(v):
		_set_temporal_depth(v)

var mp_learning_enabled: bool:
	get:
		return _mp_learning_enabled
	set(v):
		_set_mp_learning_enabled(v)

var mp_change_mode: StringName:
	get:
		return _mp_change_mode
	set(v):
		_set_mp_change_mode(v)

var mp_delta_quantization: float:
	get:
		return _mp_delta_quantization
	set(v):
		_set_mp_delta_quantization(v)

var mp_ratio_quantization: float:
	get:
		return _mp_ratio_quantization
	set(v):
		_set_mp_ratio_quantization(v)

## Read-only dropdown label derived from `mp_learning_enabled` + `mp_change_mode`.
var mp_encoding: StringName:
	get:
		return mp_encoding_from_keys(_mp_learning_enabled, _mp_change_mode)

var _initial_neuron_lifespan: int = 0
var _lifespan_growth_rate: int = 0
var _longterm_memory_threshold: int = 0
var _temporal_depth: int = 1
var _mp_learning_enabled: bool = false
var _mp_change_mode: StringName = MP_CHANGE_NONE
var _mp_delta_quantization: float = DEFAULT_MP_DELTA_QUANTIZATION
var _mp_ratio_quantization: float = DEFAULT_MP_RATIO_QUANTIZATION
var _cortical_area: AbstractCorticalArea

func _init(cortical_area_ref: AbstractCorticalArea) -> void:
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

func _set_temporal_depth(new_val: int) -> void:
	# temporal_depth=0 is invalid (pattern detector requires at least one timestep)
	if new_val < 1:
		new_val = 1
	if new_val == _temporal_depth:
		return
	_temporal_depth = new_val
	temporal_depth_updated.emit(new_val, _cortical_area)

func _set_mp_learning_enabled(new_val: bool) -> void:
	if new_val == _mp_learning_enabled:
		return
	_mp_learning_enabled = new_val
	mp_learning_enabled_updated.emit(new_val, _cortical_area)

func _set_mp_change_mode(new_val: StringName) -> void:
	if new_val == _mp_change_mode:
		return
	_mp_change_mode = new_val
	mp_change_mode_updated.emit(new_val, _cortical_area)

func _set_mp_delta_quantization(new_val: float) -> void:
	if is_equal_approx(new_val, _mp_delta_quantization):
		return
	_mp_delta_quantization = new_val
	mp_delta_quantization_updated.emit(new_val, _cortical_area)

func _set_mp_ratio_quantization(new_val: float) -> void:
	if is_equal_approx(new_val, _mp_ratio_quantization):
		return
	_mp_ratio_quantization = new_val
	mp_ratio_quantization_updated.emit(new_val, _cortical_area)
