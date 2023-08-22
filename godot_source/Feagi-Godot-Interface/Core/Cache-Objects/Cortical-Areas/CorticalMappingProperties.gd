extends Object
class_name CorticalMappingProperties
## Holds conneciton details from "Cortical Destinations" to a specific other cortical area
## Used to fine tune morphologies for specific use cases

var morphology_name: StringName
var morphology_scalar: Vector3i # always positive non-zero ints
var post_synaptic_current_multiplier: float
var plasticity_flag: bool

func _init(dict_from_FEAGI: Dictionary):
	morphology_name = dict_from_FEAGI["morphology_id"]
	morphology_scalar = FEAGIUtils.array_to_vector3i(dict_from_FEAGI["morphology_scalar"])
	post_synaptic_current_multiplier = dict_from_FEAGI["postSynapticCurrent_multiplier"]
	plasticity_flag = dict_from_FEAGI["plasticity_flag"]

func to_dictionary():
	var output := {}
	output["morphology_id"] = morphology_name
	output["morphology_scalar"] = [morphology_scalar.x, morphology_scalar.y, morphology_scalar.z]
	output["postSynapticCurrent_multiplier"] = post_synaptic_current_multiplier
	output["plasticity_flag"] = plasticity_flag
	return output
