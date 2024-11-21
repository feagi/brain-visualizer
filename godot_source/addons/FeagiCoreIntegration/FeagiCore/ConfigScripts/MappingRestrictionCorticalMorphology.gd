extends Resource
class_name MappingRestrictionCorticalMorphology

@export var cortical_source_type: AbstractCorticalArea.CORTICAL_AREA_TYPE
@export var cortical_destination_type: AbstractCorticalArea.CORTICAL_AREA_TYPE
@export var restricted_to_morphology_of_names: Array[StringName]
@export var disallowed_morphology_names: Array[StringName]
@export var max_number_mappings: int  = -1
@export var allow_changing_scalar: bool = true
@export var allow_changing_PSP: bool = true
@export var allow_changing_inhibitory: bool = true
@export var allow_changing_plasticity: bool = true
@export var allow_changing_plasticity_constant: bool = true
@export var allow_changing_LTP: bool = true
@export var allow_changing_LTD: bool = true

func has_restricted_morphologies() -> bool:
	return len(restricted_to_morphology_of_names) > 0

func has_disallowed_morphologies() -> bool:
	return len(disallowed_morphology_names) > 0

func has_max_number_mappings() -> bool:
	return max_number_mappings != -1

func get_morphologies_restricted_to() -> Array[BaseMorphology]:
	if len(restricted_to_morphology_of_names) == 0:
		return []
	var output: Array[BaseMorphology] = []
	for morphology_name in restricted_to_morphology_of_names:
		if morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies:
			output.append(FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name])
	return output

func get_morphologies_disallowed() -> Array[BaseMorphology]:
	if len(disallowed_morphology_names) == 0:
		return []
	var output: Array[BaseMorphology] = []
	for morphology_name in disallowed_morphology_names:
		if morphology_name in FeagiCore.feagi_local_cache.morphologies.available_morphologies:
			output.append(FeagiCore.feagi_local_cache.morphologies.available_morphologies[morphology_name])
	return output
