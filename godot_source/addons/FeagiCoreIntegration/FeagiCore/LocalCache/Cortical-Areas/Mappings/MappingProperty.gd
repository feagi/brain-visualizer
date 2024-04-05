extends Object
class_name MappingProperty
## a SINGLE Mapping property between 2 cortical areas (there can be multiple, which is stored in [MappingProperties])
## Whenever [MappingProperties] updates to a new set of MappingPropertys, it completely deletes the old ones and replaces it with the new ones

const INT8_MAX: int = 2147483647 # This is likely the max supported int in vector3i, but you should NOT be getting this close anyways



var morphology_used: BaseMorphology:
	get: return _morphology_used
var scalar: Vector3i:
	get: return _scalar
var is_plastic: bool:
	get: return _plasticity_flag
var post_synaptic_current_multiplier: float:
	get: return _post_synaptic_current_multiplier
var plasticity_constant: float:
	get: return _plasticity_constant
var LTP_multiplier: float:
	get: return _LTP_multiplier
var LTD_multiplier: float:
	get: return _LTD_multiplier
## if the mapping is a null placeholder
var is_null_placeholder: bool:
	get: return _is_null

var _morphology_used: BaseMorphology
var _scalar: Vector3i # must all be non-zero positive
var _post_synaptic_current_multiplier: float
var _plasticity_flag: bool
var _plasticity_constant: float
var _LTP_multiplier: float
var _LTD_multiplier: float
var _is_null: bool = false

func _init(morphology: BaseMorphology, positive_scalar: Vector3i, psp_multilpier: float, plasticity: bool, plasticity_constant_: float = 1.0, ltp_multiplier: float = 1.0, ltd_multiplier: float = 1.0, is_null: bool = false):
	_morphology_used = morphology
	_scalar = Vector3i(FEAGIUtils.bounds_int(positive_scalar.x, 1, INT8_MAX), FEAGIUtils.bounds_int(positive_scalar.y, 1, INT8_MAX), FEAGIUtils.bounds_int(positive_scalar.z, 1, INT8_MAX))
	_post_synaptic_current_multiplier = psp_multilpier
	_plasticity_flag = plasticity
	_plasticity_constant = plasticity_constant_ # not sure how to better segregate this name. Too Bad!
	_LTP_multiplier = ltp_multiplier
	_LTD_multiplier = ltd_multiplier
	_is_null = is_null

## Creates a mapping with default settings (given a morphology)
static func create_default_mapping(morphology: BaseMorphology) -> MappingProperty:
	return MappingProperty.new(morphology, Vector3i(1,1,1), 1.0, false)

## Creates a null placeholder mapping (used just to populate [MappingProperties] with the correct number of mappings before we know their details)
static func create_placeholder_mapping() -> MappingProperty:
	return MappingProperty.new(NullMorphology.new(), Vector3i(1,1,1), 1.0 , false, 1.0, 1.0, 1.0, true)

## Create an array of null placeholder mappings
static func create_placeholder_mapping_array(size: int) -> Array[MappingProperty]:
	var output: Array[MappingProperty] = []
	for i: int in size:
		output.append(MappingProperty.create_placeholder_mapping())
	return output

## Given the dictionary from FEAGI directly creates a MappingProperty object
static func from_dict(mapping_property: Dictionary) -> MappingProperty:
	var morphology_cached: BaseMorphology = FeagiCache.morphology_cache.available_morphologies[mapping_property["morphology_id"]]
	var scalar_used: Vector3i = FEAGIUtils.array_to_vector3i(mapping_property["morphology_scalar"])
	var psp_multiplier: float = mapping_property["postSynapticCurrent_multiplier"]
	var plasticity: bool = mapping_property["plasticity_flag"]
	if !plasticity:
		return MappingProperty.new(morphology_cached, scalar_used, psp_multiplier, plasticity)
	else:
		var plasticity_constant_used: float = mapping_property["plasticity_constant"]
		var LTP_multiplier_used: float = mapping_property["ltp_multiplier"]
		var LTD_multiplier_used: float = mapping_property["ltd_multiplier"]
		return MappingProperty.new(morphology_cached, scalar_used, psp_multiplier, plasticity, plasticity_constant_used, LTP_multiplier_used, LTD_multiplier_used)

## Given an array of Dictionaries from FEAGI, directly output an array of MappingPropertys
static func from_array_of_dict(mapping_dicts: Array[Dictionary]) -> Array[MappingProperty]:
	var output: Array[MappingProperty] = []
	for mapping_dict: Dictionary in mapping_dicts:
		output.append(MappingProperty.from_dict(mapping_dict))
	return output

#TODO move the internal check to a static function in BaseCorticalArea
## Is an array of mappingproperties valid given a source and destination area?
static func is_mapping_property_array_invalid_for_cortical_areas(mapping_propertys: Array[MappingProperty], source_area: BaseCorticalArea, destination_area: BaseCorticalArea) -> bool:
	return MappingHints.is_mapping_property_array_invalid_for_cortical_areas(source_area, destination_area, mapping_propertys)


## Returns a dictionary of this object in the same format FEAGI expects
func to_dictionary() -> Dictionary:
	if !_plasticity_flag:
		return {
			"morphology_id": _morphology_used.name,
			"morphology_scalar": FEAGIUtils.vector3i_to_array(_scalar),
			"postSynapticCurrent_multiplier": _post_synaptic_current_multiplier,
			"plasticity_flag": _plasticity_flag,
		}
	else:
		return {
			"morphology_id": _morphology_used.name,
			"morphology_scalar": FEAGIUtils.vector3i_to_array(_scalar),
			"postSynapticCurrent_multiplier": _post_synaptic_current_multiplier,
			"plasticity_flag": _plasticity_flag,
			"plasticity_constant": _plasticity_constant,
			"ltp_multiplier": _LTP_multiplier,
			"ltd_multiplier": _LTD_multiplier,
		}

func duplicate() -> MappingProperty:
	return MappingProperty.new(_morphology_used, _scalar, _post_synaptic_current_multiplier, _plasticity_flag, _plasticity_constant, _LTP_multiplier, _LTD_multiplier)

