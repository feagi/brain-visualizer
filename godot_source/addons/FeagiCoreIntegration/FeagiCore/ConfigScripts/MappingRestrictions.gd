extends RefCounted
class_name MappingRestrictionsAPI

## Static API for managing mapping restrictions and defaults between cortical areas
## This class handles caching and retrieval of mapping restrictions from FEAGI server

# Cache for mapping restrictions and defaults
static var _restrictions_cache: Dictionary = {}
static var _defaults_cache: Dictionary = {}
static var _cache_loaded: bool = false

## Load mapping restrictions from FEAGI server
static func load_mapping_restrictions() -> bool:
	# TODO: Implement actual HTTP request to load mapping restrictions from server
	# For now, create built-in restrictions for memory cortical areas
	_create_builtin_restrictions()
	_cache_loaded = true
	print("MappingRestrictionsAPI: Loaded built-in mapping restrictions")
	return true

## Clear the mapping restrictions cache
static func clear_cache() -> void:
	_restrictions_cache.clear()
	_defaults_cache.clear()
	_cache_loaded = false

## Get mapping restrictions between two cortical areas
static func get_restrictions_between_cortical_areas(source: GenomeObject, destination: GenomeObject) -> MappingRestrictionCorticalMorphology:
	if not _cache_loaded:
		push_warning("MappingRestrictionsAPI: Cache not loaded, returning null restrictions")
		return null
	
	if not (source is AbstractCorticalArea and destination is AbstractCorticalArea):
		return null
	
	var source_area = source as AbstractCorticalArea
	var destination_area = destination as AbstractCorticalArea
	
	# First try exact match
	var key = _get_cache_key(source_area.cortical_type, destination_area.cortical_type)
	if key in _restrictions_cache:
		return _restrictions_cache[key]
	
	# Special handling for memory areas - check if either source or destination is memory
	if source_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY or destination_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		# Memory areas should always use memory morphology
		var memory_restriction = MappingRestrictionCorticalMorphology.new()
		memory_restriction.cortical_source_type = source_area.cortical_type
		memory_restriction.cortical_destination_type = destination_area.cortical_type
		var memory_names: Array[StringName] = [&"memory"]
		memory_restriction.restricted_to_morphology_of_names = memory_names
		return memory_restriction
	
	# No specific restrictions found
	return null

## Get mapping defaults between two cortical areas
static func get_defaults_between_cortical_areas(source: GenomeObject, destination: GenomeObject) -> MappingRestrictionDefault:
	if not _cache_loaded:
		push_warning("MappingRestrictionsAPI: Cache not loaded, returning null defaults")
		return null
	
	if not (source is AbstractCorticalArea and destination is AbstractCorticalArea):
		return null
	
	var source_area = source as AbstractCorticalArea
	var destination_area = destination as AbstractCorticalArea
	
	# First try exact match
	var key = _get_cache_key(source_area.cortical_type, destination_area.cortical_type)
	if key in _defaults_cache:
		return _defaults_cache[key]
	
	# Special handling for memory areas - default to memory morphology
	if source_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY or destination_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		var memory_default = MappingRestrictionDefault.new()
		memory_default.cortical_source_type = source_area.cortical_type
		memory_default.cortical_destination_type = destination_area.cortical_type
		memory_default.name_of_default_morphology = &"memory"
		return memory_default
	
	# No specific defaults found
	return null

## Generate cache key for cortical area type pair
static func _get_cache_key(source_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, destination_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> String:
	return str(source_type) + "_to_" + str(destination_type)

## Add a restriction to the cache (for future server integration)
static func _add_restriction_to_cache(source_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, destination_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, restriction: MappingRestrictionCorticalMorphology) -> void:
	var key = _get_cache_key(source_type, destination_type)
	_restrictions_cache[key] = restriction

## Add a default to the cache (for future server integration)
static func _add_default_to_cache(source_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, destination_type: AbstractCorticalArea.CORTICAL_AREA_TYPE, default: MappingRestrictionDefault) -> void:
	var key = _get_cache_key(source_type, destination_type)
	_defaults_cache[key] = default

## Create built-in mapping restrictions for memory cortical areas
static func _create_builtin_restrictions() -> void:
	# Memory cortical areas should only use memory morphology
	var memory_restriction = MappingRestrictionCorticalMorphology.new()
	memory_restriction.cortical_source_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	memory_restriction.cortical_destination_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	var memory_names: Array[StringName] = [&"memory"]
	memory_restriction.restricted_to_morphology_of_names = memory_names
	
	# Memory areas connecting to any other type should also use memory morphology
	var memory_to_any_restriction = MappingRestrictionCorticalMorphology.new()
	memory_to_any_restriction.cortical_source_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	memory_to_any_restriction.cortical_destination_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN # Will match any destination
	memory_to_any_restriction.restricted_to_morphology_of_names = memory_names
	
	# Any area connecting to memory should also use memory morphology
	var any_to_memory_restriction = MappingRestrictionCorticalMorphology.new()
	any_to_memory_restriction.cortical_source_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN # Will match any source
	any_to_memory_restriction.cortical_destination_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	any_to_memory_restriction.restricted_to_morphology_of_names = memory_names
	
	# Add restrictions to cache
	_add_restriction_to_cache(AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY, AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY, memory_restriction)
	
	# Create memory morphology default for memory areas
	var memory_default = MappingRestrictionDefault.new()
	memory_default.cortical_source_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	memory_default.cortical_destination_type = AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	memory_default.name_of_default_morphology = &"memory"
	
	_add_default_to_cache(AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY, AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY, memory_default)
