extends Object
class_name MappingProperty
## a SINGLE Mapping property between 2 cortical areas (there can be multiple, which is stored in [MappingProperties])
## This object is never actually stored in a cache, its created as needed to represent a connections details

const INT8_MAX: int = 2147483647 # This is likely the max supported int in vector3i, but you should NOT be getting this close anyways

var morphology_used: Morphology:
	get: return _morphology_used
var scalar: Vector3i:
	get: return _scalar
var is_plastic: bool:
	get: return _plasticity_flag
var post_synaptic_current_multiplier: float:
	get: return post_synaptic_current_multiplier
var plasticity_multiplier: float:
	get: return _plasticity_multiplier
var LTP_multiplier: float:
	get: return _LTP_multiplier
var LTD_multiplier: float:
	get: return _LTD_multiplier


var _morphology_used: Morphology
var _scalar: Vector3i # must all be non-zero positive
var _post_synaptic_current_multiplier: float
var _plasticity_flag: bool
var _plasticity_multiplier: float
var _LTP_multiplier: float
var _LTD_multiplier: float


func _init(morphology: Morphology, positive_scalar: Vector3i, psp_multilpier: float, plasticity: bool, plasticity_multiplier_: float = 1.0, ltp_multiplier: float = 1.0, ltd_multiplier: float = 1.0):
	_morphology_used = morphology
	_scalar = Vector3i(FEAGIUtils.bounds_int(positive_scalar.x, 1, INT8_MAX), FEAGIUtils.bounds_int(positive_scalar.y, 1, INT8_MAX), FEAGIUtils.bounds_int(positive_scalar.z, 1, INT8_MAX))
	_post_synaptic_current_multiplier = psp_multilpier
	_plasticity_flag = plasticity
	_plasticity_multiplier = plasticity_multiplier_ # not sure how to better segregate this name. Too Bad!
	_LTP_multiplier = ltp_multiplier
	_LTD_multiplier = ltd_multiplier

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
			"plasticity_multiplier": _plasticity_multiplier,
			"ltp_multiplier": _LTP_multiplier,
			"ltd_multiplier": _LTD_multiplier,
		}

func duplicate() -> MappingProperty:
	return MappingProperty.new(_morphology_used, _scalar, _post_synaptic_current_multiplier, _plasticity_flag, _plasticity_multiplier, _LTP_multiplier, _LTD_multiplier)

## Given the dictionary from FEAGI directly creates a MappingProperty object
static func from_dict(mapping_property: Dictionary) -> MappingProperty:
	var morphology_cached: Morphology = FeagiCache.morphology_cache.available_morphologies[mapping_property["morphology_id"]]
	var scalar_used: Vector3i = FEAGIUtils.array_to_vector3i(mapping_property["morphology_scalar"])
	var psp_multiplier: float = mapping_property["postSynapticCurrent_multiplier"]
	var plasticity: bool = mapping_property["plasticity_flag"]
	if !plasticity:
		return MappingProperty.new(morphology_cached, scalar_used, psp_multiplier, plasticity)
	else:
		var plasticity_multiplier_used: float = mapping_property["plasticity_constant"]
		var LTP_multiplier_used: float = mapping_property["ltp_multiplier"]
		var LTD_multiplier_used: float = mapping_property["ltd_multiplier"]
		return MappingProperty.new(morphology_cached, scalar_used, psp_multiplier, plasticity, plasticity_multiplier_used, LTP_multiplier_used, LTD_multiplier_used)

static func create_default_mapping(morphology: Morphology) -> MappingProperty:
	return MappingProperty.new(morphology, Vector3i(1,1,1), 1.0, false)
