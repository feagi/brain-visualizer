extends RefCounted
class_name FEAGILocalCache

#region main
signal genome_reloaded()

var cortical_areas: CorticalAreasCache
var morphologies: MorphologiesCache

func _init():
	cortical_areas = CorticalAreasCache.new()
	morphologies = MorphologiesCache.new()

func replace_whole_genome(cortical_area_summary: Dictionary, morphologies_summary: Dictionary, mapping_summary: Dictionary) -> void:
	
	print("\nFEAGI CACHE: Replacing the ENTIRE local cached genome!")
	cortical_areas.update_cortical_area_cache_from_summary(cortical_area_summary)
	morphologies.update_morphology_cache_from_summary(morphologies_summary)
	for source_cortical_ID: StringName in mapping_summary.keys():
		if !(source_cortical_ID in cortical_areas.available_cortical_areas.keys()):
			push_error("FEAGI CACHE: Mapping refers to nonexistant cortical area %s! Skipping!" % source_cortical_ID)
			continue
			
		var mapping_targets: Dictionary = mapping_summary[source_cortical_ID]
		for destination_cortical_ID: StringName in mapping_targets.keys():
			if !(destination_cortical_ID in cortical_areas.available_cortical_areas.keys()):
				push_error("FEAGI CACHE: Mapping refers to nonexistant cortical area %s! Skipping!" % destination_cortical_ID)
				continue
			#NOTE: Instead of verifying the morphology exists, we will allow [MappingProperty]'s  system handle it, as it has a fallback should it not be found
			var source_area: BaseCorticalArea = cortical_areas.available_cortical_areas[source_cortical_ID]
			var destination_area: BaseCorticalArea = cortical_areas.available_cortical_areas[destination_cortical_ID]
			var mapping_dictionaries: Array[Dictionary] = [] # Why doesnt godot support type inference for arrays yet?
			mapping_dictionaries.assign(mapping_targets[destination_cortical_ID])
			var mappings: Array[MappingProperty] = MappingProperty.from_array_of_dict(mapping_dictionaries)
			source_area.set_mappings_to_efferent_area(destination_area, mappings)
	
	print("FEAGI CACHE: DONE Replacing the ENTIRE local cached genome!\n")
	genome_reloaded.emit()
#endregion

## Deletes the genome from cache (safely). NOTE: this triggers the genome_reloaded signal too
func clear_whole_genome() -> void:
	print("\nFEAGI CACHE: REMOVING the ENTIRE local cached genome!")
	cortical_areas.update_cortical_area_cache_from_summary({})
	morphologies.update_morphology_cache_from_summary({})
	clear_templates()
	print("FEAGI CACHE: DONE REMOVING the ENTIRE local cached genome!\n")
	genome_reloaded.emit()
	


#region Templates

signal templates_updated()

var IPU_templates: Dictionary:
	get: return _IPU_templates
var OPU_templates: Dictionary:
	get: return _OPU_templates

var _IPU_templates: Dictionary = {}
var _OPU_templates: Dictionary = {}

# TODO corticaltemplates (s) may be deletable

## Retrieved template updats from FEAGI
func update_templates_from_FEAGI(dict: Dictionary) -> void:
	var ipu_devices: Dictionary = dict["IPU"]["supported_devices"]
	for ipu_ID: StringName in ipu_devices.keys():
		var ipu_device: Dictionary = ipu_devices[ipu_ID]
		var resolution: Array[int] = [] # Gotta love godot unable to infer types
		resolution.assign(ipu_device["resolution"])
		_IPU_templates[ipu_ID] = CorticalTemplate.new(
			ipu_ID,
			ipu_device["enabled"],
			ipu_device["cortical_name"],
			ipu_device["structure"],
			resolution,
			BaseCorticalArea.CORTICAL_AREA_TYPE.IPU
		)
	var opu_devices: Dictionary = dict["OPU"]["supported_devices"]
	for opu_ID: StringName in opu_devices.keys():
		var opu_device: Dictionary = opu_devices[opu_ID]
		var resolution: Array[int] = [] # Gotta love godot unable to infer types
		resolution.assign(opu_device["resolution"])
		_OPU_templates[opu_ID] = CorticalTemplate.new(
			opu_ID,
			opu_device["enabled"],
			opu_device["cortical_name"],
			opu_device["structure"],
			resolution,
			BaseCorticalArea.CORTICAL_AREA_TYPE.OPU
		)
	
	templates_updated.emit()

func clear_templates() -> void:
	_IPU_templates = {}
	_OPU_templates = {}
	templates_updated.emit()

#endregion


#region Health

signal burst_engine_changed(new_val: bool)
signal influxdb_availability_changed(new_val: bool)
signal neuron_count_max_changed(new_val: bool)
signal synapse_count_max_changed(new_val: int)
signal neuron_count_current_changed(new_val: bool)
signal synapse_count_current_changed(new_val: int)
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
var neuron_count_current: int:
	get: return _neuron_count_current
	set(v): 
		if v != _neuron_count_current:
			_neuron_count_current = v
			neuron_count_current_changed.emit(v)
var synapse_count_current: int:
	get: return _synapse_count_current
	set(v): 
		if v != _synapse_count_current:
			_synapse_count_current = v
			synapse_count_current_changed.emit(v)
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
var _neuron_count_current: int
var _synapse_count_current: int
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
	if "neuron_count" in health: 
		neuron_count_current = int(health["neuron_count"])
	if "synapse_count" in health: 
		synapse_count_current = int(health["synapse_count"])
	if "genome_availability" in health: 
		genome_availability = health["genome_availability"]
	if "genome_validity" in health: 
		genome_validity = health["genome_validity"]
	if "burst_engine" in health: 
		brain_readiness = health["brain_readiness"]

#endregion




