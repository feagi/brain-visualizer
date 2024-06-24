extends Resource
class_name MappingRestrictionDefault

enum DEFAULT_NAME {
	DEFAULT,
	TOWARDS_MEMORY
}

@export var cortical_source_type: AbstractCorticalArea.CORTICAL_AREA_TYPE
@export var cortical_destination_type: AbstractCorticalArea.CORTICAL_AREA_TYPE
@export var name_of_default_morphology: StringName
@export var default_name: DEFAULT_NAME

func try_get_default_morphology() -> BaseMorphology:
	return FeagiCore.feagi_local_cache.morphologies.try_get_morphology_object(name_of_default_morphology)
