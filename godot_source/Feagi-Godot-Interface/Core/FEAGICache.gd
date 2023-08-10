extends Node
## AUTOLOADED
## Stores cached data from FEAGI

var morphology_cache: MorphologiesCache
var cortical_areas_cache: CorticalAreasCache

func _init():
    morphology_cache = MorphologiesCache.new()
    cortical_areas_cache = CorticalAreasCache.new()