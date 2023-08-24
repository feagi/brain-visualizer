extends Node
## AUTOLOADED
## Stores cached data from FEAGI


var delay_between_bursts: float:
    get: return _delay_between_bursts
    set(v):
        _delay_between_bursts = v
        FeagiCacheEvents.delay_between_bursts_updated.emit(v)


var morphology_cache: MorphologiesCache
var cortical_areas_cache: CorticalAreasCache
var connections_cache: ConnectionsCache


var _delay_between_bursts: float
#var screen_size: Vector2

func _init():
    morphology_cache = MorphologiesCache.new()
    cortical_areas_cache = CorticalAreasCache.new()
    connections_cache = ConnectionsCache.new()
