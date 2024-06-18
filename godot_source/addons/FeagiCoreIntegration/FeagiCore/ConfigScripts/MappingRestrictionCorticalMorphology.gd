extends Resource
class_name MappingRestrictionCorticalMorphology

enum RESTRICTION_NAME {
	DEFAULT,
	TOWARD_MEMORY
}

@export var cortical_source_type: AbstractCorticalArea.CORTICAL_AREA_TYPE
@export var cortical_destination_type: AbstractCorticalArea.CORTICAL_AREA_TYPE
@export var restricted_to_morphology_of_names: Array[StringName]
@export var max_number_mappings: int  = -1
@export var restriction_name: RESTRICTION_NAME

func has_restricted_morphologies() -> bool:
	return len(restricted_to_morphology_of_names) > 0

func get_morphologies_restricted_to() -> Array[BaseMorphology]:
	if len(restricted_to_morphology_of_names) == 0:
		return []
	var output: Array[BaseMorphology] = []
	for morphology_name in restricted_to_morphology_of_names:
		if morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies:
			output.append(FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name])
	return output
