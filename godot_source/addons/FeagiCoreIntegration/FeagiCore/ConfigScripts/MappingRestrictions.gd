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
	# For now, return true to avoid blocking the cache loading process
	_cache_loaded = true
	push_warning("MappingRestrictionsAPI: load_mapping_restrictions() not yet implemented - using empty cache")
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
	
	var key = _get_cache_key(source_area.cortical_area_type, destination_area.cortical_area_type)
	
	if key in _restrictions_cache:
		return _restrictions_cache[key]
	
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
	
	var key = _get_cache_key(source_area.cortical_area_type, destination_area.cortical_area_type)
	
	if key in _defaults_cache:
		return _defaults_cache[key]
	
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
