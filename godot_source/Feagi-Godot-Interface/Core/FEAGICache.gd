extends Node
## AUTOLOADED
## Stores cached data from FEAGI

var morphology_cache: MorphologiesCache
var cortical_areas_cache: CorticalAreasCache
var connections_cache: ConnectionsCache

var screen_size: Vector2

func _init():
    morphology_cache = MorphologiesCache.new()
    cortical_areas_cache = CorticalAreasCache.new()
    connections_cache = ConnectionsCache.new()
