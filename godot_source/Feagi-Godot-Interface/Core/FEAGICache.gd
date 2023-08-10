extends Node
## AUTOLOADED
## Stores cached data from FEAGI

var morphology_cache: MorphologiesCache

func _init():
    morphology_cache = MorphologiesCache.new()