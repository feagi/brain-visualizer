extends Resource
class_name MappingRestrictions
## Resource for defining restrictions and default mapping settings. Arrays are each in order of preference, from top to down

@export var restrictions: Array[MappingRestrictionCorticalMorphology]
@export var default_mapping_settings: Array[MappingRestrictionDefault]

func get_restrictions_between_2_cortical_areas(source: AbstractCorticalArea, destination: AbstractCorticalArea) -> MappingRestrictionCorticalMorphology:
	var type_source: AbstractCorticalArea.CORTICAL_AREA_TYPE = source.cortical_type
	var type_destination: AbstractCorticalArea.CORTICAL_AREA_TYPE = destination.cortical_type
	for restriction in restrictions:
		if restriction.cortical_source_type == type_source or restriction.cortical_source_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN:
			if restriction.cortical_destination_type == type_destination or restriction.cortical_destination_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN:
				return restriction
	push_error("CORE: Unknown mapping restrictions between cortical %s to cortical %s" % [source.cortical_ID, destination.cortical_ID])
	return null

func get_defaults_between_2_cortical_areas(source: AbstractCorticalArea, destination: AbstractCorticalArea) -> MappingRestrictionDefault:
	var type_source: AbstractCorticalArea.CORTICAL_AREA_TYPE = source.cortical_type
	var type_destination: AbstractCorticalArea.CORTICAL_AREA_TYPE = destination.cortical_type
	for default in default_mapping_settings:
		if default.cortical_source_type == type_source or default.cortical_source_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN:
			if default.cortical_destination_type == type_destination or default.cortical_destination_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN:
				return default
	push_error("CORE: Unknown mapping default between cortical %s to cortical %s" % [source.cortical_ID, destination.cortical_ID])
	return null
