extends RefCounted
class_name MappingsCache

signal mapping_created(mapping: InterCorticalMappingSet)
signal mapping_updated(mapping: InterCorticalMappingSet)

## Ways to describe the set of [MappingProperty]s
enum SIGNAL_TYPE{
	EXCITATORY,
	INHIBITORY,
	MIXED
}

var established_mappings: Dictionary: # Mappings Established in the FEAGI Connectom, key'd by source_cortical_ID -> destination_cortical_ID -> [MappingProperties]
	get: return _established_mappings

var _established_mappings: Dictionary



## Retrieved the mapping data between 2 cortical areas from FEAGI, use this to update the cache
func FEAGI_set_mapping_JSON(source: BaseCorticalArea, destination: BaseCorticalArea, mappings_JSON: Array[Dictionary]):
	if !source.cortical_ID in _established_mappings.keys():
		_established_mappings[source.cortical_ID] = {}
	if destination.cortical_ID in _established_mappings[source.cortical_ID].keys():
		## Mapping exists, update it!
		(_established_mappings[source.cortical_ID][destination.cortical_ID] as InterCorticalMappingSet).FEAGI_updated_mappings_JSON(mappings_JSON)
		mapping_updated.emit(_established_mappings[source.cortical_ID][destination.cortical_ID])
	else:
		## Mapping doesn't exist, create it!	
		_established_mappings[source.cortical_ID][destination.cortical_ID] = InterCorticalMappingSet.from_FEAGI_JSON(mappings_JSON, source, destination)
		mapping_created.emit(_established_mappings[source.cortical_ID][destination.cortical_ID])

## Retrieved the mapping data between 2 cortical areas from FEAGI, use this to update the cache
func FEAGI_set_mapping(source: BaseCorticalArea, destination: BaseCorticalArea, new_mappings: Array[SingleMappingDefinition]):
	if !source.cortical_ID in _established_mappings.keys():
		_established_mappings[source.cortical_ID] = {}
	if destination.cortical_ID in _established_mappings[source.cortical_ID].keys():
		## Mapping exists, update it!
		(_established_mappings[source.cortical_ID][destination.cortical_ID] as InterCorticalMappingSet).FEAGI_updated_mappings(new_mappings)
		mapping_updated.emit(_established_mappings[source.cortical_ID][destination.cortical_ID])
	else:
		## Mapping doesn't exist, create it!	
		_established_mappings[source.cortical_ID][destination.cortical_ID] = InterCorticalMappingSet.new(source, destination, new_mappings)
		mapping_created.emit(_established_mappings[source.cortical_ID][destination.cortical_ID])

## Load in all mappings from summary data. Called from [FEAGILocalCache] when loading genome
func FEAGI_load_all_mappings(mapping_summary: Dictionary)-> void:
	for source_cortical_ID: StringName in mapping_summary.keys():
		if !(source_cortical_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys()):
			push_error("FEAGI CACHE: Mapping refers to nonexistant cortical area %s! Skipping!" % source_cortical_ID)
			continue
			
		var mapping_targets: Dictionary = mapping_summary[source_cortical_ID]
		for destination_cortical_ID: StringName in mapping_targets.keys():
			if !(destination_cortical_ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys()):
				push_error("FEAGI CACHE: Mapping refers to nonexistant cortical area %s! Skipping!" % destination_cortical_ID)
				continue
			#NOTE: Instead of verifying the morphology exists, we will allow [MappingProperty]'s  system handle it, as it has a fallback should it not be found
			var source_area: BaseCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[source_cortical_ID]
			var destination_area: BaseCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[destination_cortical_ID]
			var mapping_dictionaries: Array[Dictionary] = [] # Why doesnt godot support type inference for arrays yet?
			mapping_dictionaries.assign(mapping_targets[destination_cortical_ID])
			FEAGI_set_mapping_JSON(source_area, destination_area, mapping_dictionaries)
			
## Returns true if the given cortical areas have a mapping defined in cache between them, else false
func does_mappings_exist_between_areas(source: BaseCorticalArea, destination: BaseCorticalArea) -> bool:
	if !(source.cortical_ID in _established_mappings):
		return false
	if !(destination.cortical_ID in _established_mappings[destination.cortical_ID]):
		return false
	return true

func get_mappings_from_source_cortical_area(source: BaseCorticalArea):
	pass

func get_mappings_toward_destination_cortical_area(destination: BaseCorticalArea):
	pass














