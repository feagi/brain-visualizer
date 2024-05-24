extends RefCounted
class_name PartialMappingSet
## When a region is imported from an old genome, external connections are severed. This object stores the memory state of that connection and can serve as a template to make new established mappings.
## Since it is a hint, it cannot be edited, only consumed / destroyed


signal mappings_about_to_be_deleted()

var source: GenomeObject: ## Where this starts from (IE the output this mapping originates)
	get: return _source
var destination: GenomeObject: ## Where this ends to (IE the output this mapping arrives)
	get: return _destination
var mappings: Array[SingleMappingDefinition]:
	get: return _mappings
var number_mappings: int:
	get: return len(_mappings)

var _source: GenomeObject
var _destination: GenomeObject
var _mappings: Array[SingleMappingDefinition]

static func from_FEAGI_JSON(json_dict: Dictionary) -> void:
	#TODO
	pass

func _init(starting: GenomeObject, ending: GenomeObject, suggested_mappings: Array[SingleMappingDefinition]):
	_source = starting
	_destination = ending
	_mappings = suggested_mappings

## Returns true if any other internal mappings are plastic
func is_any_mapping_plastic() -> bool:
	for mapping: SingleMappingDefinition in _mappings:
		if mapping.is_plastic:
			return true
	return false

## Returns true if any mapping's PSP multiplier is positive
func is_any_PSP_multiplier_positive() -> bool:
	for mapping: SingleMappingDefinition in _mappings:
		if mapping.post_synaptic_current_multiplier > 0.0:
			return true
	return false
 
## Returns true if any mapping's PSP multiplier is negative
func is_any_PSP_multiplier_negative() -> bool:
	for mapping: SingleMappingDefinition in _mappings:
		if mapping.post_synaptic_current_multiplier < 0.0:
			return true
	return false

func get_PSP_signal_type() -> MappingsCache.SIGNAL_TYPE:
	if is_any_PSP_multiplier_negative():
		if is_any_PSP_multiplier_positive():
			return MappingsCache.SIGNAL_TYPE.MIXED
		else:
			return MappingsCache.SIGNAL_TYPE.INHIBITORY
	return MappingsCache.SIGNAL_TYPE.EXCITATORY

func is_source_cortical_area() -> bool:
	return _source is BaseCorticalArea

func is_destination_cortical_area() -> bool:
	return _destination is BaseCorticalArea
