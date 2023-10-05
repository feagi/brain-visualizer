extends Node
## AUTOLOADED
## Stores cached data from FEAGI


var delay_between_bursts: float:
	get: return _delay_between_bursts
	set(v):
		_delay_between_bursts = v
		FeagiCacheEvents.delay_between_bursts_updated.emit(v)

var genome_name: StringName:
	get: return _genome_name
	set(v):
		_genome_name = v
		FeagiCacheEvents.feagi_genome_name_changed.emit(v)

var morphology_cache: MorphologiesCache
var cortical_areas_cache: CorticalAreasCache
var cortical_templates: Dictionary:
	get: return _cortical_templates


var _delay_between_bursts: float
var _cortical_templates: Dictionary = {}
var _genome_name: StringName = ""


func _init():
	morphology_cache = MorphologiesCache.new()
	cortical_areas_cache = CorticalAreasCache.new()

## Wipes all data from cache
func hard_wipe():
	for key in Godot_list.godot_list["data"]["direct_stimulation"]:
		Godot_list.godot_list["data"]["direct_stimulation"][key] = []
	cortical_areas_cache.hard_wipe_cortical_areas()
	morphology_cache.hard_wipe_cached_morphologies()

func feagi_set_cortical_templates(raw_templates: Dictionary) -> void:
	_cortical_templates = CorticalTemplates.cortical_templates_factory(raw_templates)