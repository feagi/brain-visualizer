extends Resource
class_name MappingRestrictionCorticalMorphology

@export var cortical_source_type: AbstractCorticalArea.CORTICAL_AREA_TYPE
@export var cortical_destination_type: AbstractCorticalArea.CORTICAL_AREA_TYPE
@export var restricted_to_morphology_of_names: Array[StringName]
@export var max_number_mappings: int  = -1
