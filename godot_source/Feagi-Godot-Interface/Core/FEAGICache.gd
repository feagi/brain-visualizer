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


var _delay_between_bursts: float
var _available_circuits: PackedStringArray = []

func _init():
	morphology_cache = MorphologiesCache.new()
	cortical_areas_cache = CorticalAreasCache.new()
