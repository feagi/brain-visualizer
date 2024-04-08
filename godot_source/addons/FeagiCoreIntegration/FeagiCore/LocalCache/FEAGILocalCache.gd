extends RefCounted
class_name FEAGILocalCache

#region main
signal genome_reloaded()

var cortical_areas_cache: CorticalAreasCache
var morphology_cache: MorphologiesCache

func _init():
	cortical_areas_cache = CorticalAreasCache.new()
	morphology_cache = MorphologiesCache.new()

func replace_whole_genome(cortical_area_summary: Dictionary, morphologies_summary: Dictionary, mapping_summary: Dictionary) -> void:
	
	print("\nFEAGI CACHE: Replacing the ENTIRE local cached genome!")
	cortical_areas_cache.update_cortical_area_cache_from_summary(cortical_area_summary)
	morphology_cache.update_morphology_cache_from_summary(morphologies_summary)
	for source_cortical_ID: StringName in mapping_summary.keys():
		if !(source_cortical_ID in cortical_areas_cache.cortical_areas.keys()):
			push_error("FEAGI CACHE: Mapping refers to nonexistant cortical area %s! Skipping!" % source_cortical_ID)
			continue
			
		var mapping_targets: Dictionary = mapping_summary[source_cortical_ID]
		for destination_cortical_ID: StringName in mapping_targets.keys():
			if !(destination_cortical_ID in cortical_areas_cache.cortical_areas.keys()):
				push_error("FEAGI CACHE: Mapping refers to nonexistant cortical area %s! Skipping!" % destination_cortical_ID)
				continue
			#NOTE: Instead of verifying the morphology exists, we will allow [MappingProperty]'s  system handle it, as it has a fallback should it not be found
			var source_area: BaseCorticalArea = cortical_areas_cache.cortical_areas[source_cortical_ID]
			var destination_area: BaseCorticalArea = cortical_areas_cache.cortical_areas[destination_cortical_ID]
			var mapping_dictionaries: Array[Dictionary] = [] # Why doesnt godot support type inference for arrays yet?
			mapping_dictionaries.assign(mapping_targets[destination_cortical_ID])
			var mappings: Array[MappingProperty] = MappingProperty.from_array_of_dict(mapping_dictionaries)
			source_area.set_mappings_to_efferent_area(destination_area, mappings)
	
	print("FEAGI CACHE: DONE Replacing the ENTIRE local cached genome!\n")
	genome_reloaded.emit()
#endregion

#region Health

signal burst_engine_changed(new_val: bool)
signal influxdb_availability_changed(new_val: bool)
signal neuron_count_max_changed(new_val: bool)
signal synapse_count_max_changed(new_val: int)
signal genome_availability_changed(new_val: int)
signal genome_validity_changed(new_val: bool)
signal brain_readiness_changed(new_val: bool)

var burst_engine: bool:
	get: return _burst_engine
	set(v): 
		if v != _burst_engine:
			_burst_engine = v
			burst_engine_changed.emit(v)
var influxdb_availability: bool:
	get: return _influxdb_availability
	set(v): 
		if v != _influxdb_availability:
			_influxdb_availability = v
			influxdb_availability_changed.emit(v)
var neuron_count_max: int:
	get: return _neuron_count_max
	set(v): 
		if v != _neuron_count_max:
			_neuron_count_max = v
			neuron_count_max_changed.emit(v)
var synapse_count_max: int:
	get: return _synapse_count_max
	set(v): 
		if v != _synapse_count_max:
			_synapse_count_max = v
			synapse_count_max_changed.emit(v)
var genome_availability: bool:
	get: return _genome_availability
	set(v): 
		if v != _genome_availability:
			_genome_availability = v
			genome_availability_changed.emit(v)
var genome_validity: bool:
	get: return _genome_validity
	set(v): 
		if v != _genome_validity:
			_genome_validity = v
			genome_validity_changed.emit(v)
var brain_readiness: bool:
	get: return _brain_readiness
	set(v): 
		if v != _brain_readiness:
			_brain_readiness = v
			brain_readiness_changed.emit(v)

var _burst_engine: bool
var _influxdb_availability: bool
var _neuron_count_max: int
var _synapse_count_max: int
var _genome_availability: bool
var _genome_validity: bool
var _brain_readiness: bool

func update_health_from_FEAGI_dict(health: Dictionary) -> void:
	if "burst_engine" in health: 
		burst_engine = health["burst_engine"]
	if "influxdb_availability" in health: 
		influxdb_availability = health["influxdb_availability"]
	if "neuron_count_max" in health: 
		neuron_count_max = int(health["neuron_count_max"])
	if "synapse_count_max" in health: 
		synapse_count_max = int(health["synapse_count_max"])
	if "genome_availability" in health: 
		genome_availability = health["genome_availability"]
	if "genome_validity" in health: 
		genome_validity = health["genome_validity"]
	if "burst_engine" in health: 
		brain_readiness = health["brain_readiness"]

#endregion




