extends Node
## AUTOLOADED
## Stores cached data from FEAGI


var delay_between_bursts: float:
	get: return _delay_between_bursts
	set(v):
		_delay_between_bursts = v
		FeagiCacheEvents.delay_between_bursts_updated.emit(v)

## The names of all circuits available for FEAGI to load
var available_circuits: PackedStringArray:
	get: return _available_circuits
	set(v):
		_available_circuits = v
		FeagiCacheEvents.available_circuit_listing_updated.emit(v)

var morphology_cache: MorphologiesCache
var cortical_areas_cache: CorticalAreasCache
var cortical_templates: Dictionary:
	get: return _cortical_templates


var _delay_between_bursts: float
var _available_circuits: PackedStringArray = []
var _cortical_templates: Dictionary = {}


func _init():
	morphology_cache = MorphologiesCache.new()
	cortical_areas_cache = CorticalAreasCache.new()

## Wipes all data from cache
func hard_wipe():
	cortical_areas_cache.hard_wipe_cortical_areas()
	morphology_cache.hard_wipe_cached_morphologies()
	available_circuits = []

func feagi_set_cortical_templates(raw_templates: Dictionary) -> void:
	_cortical_templates = CorticalTemplates.cortical_templates_factory(raw_templates)