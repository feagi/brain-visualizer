extends RefCounted
class_name FEAGILocalCache

#region main
signal cache_about_to_reload()
signal cache_reloaded()
signal amalgamation_pending(amalgamation_id: StringName, genome_title: StringName, dimensions: Vector3i) # is called any time a new amalgamation is pending
signal amalgamation_no_longer_pending(amalgamation_id: StringName) # may occur following confirmation OR deletion

var brain_regions: BrainRegionsCache
var cortical_areas: CorticalAreasCache
var morphologies: MorphologiesCache
var mapping_data: MappingsCache
var mapping_restrictions: MappingRestrictions

func _init():
	cortical_areas = CorticalAreasCache.new()
	morphologies = MorphologiesCache.new()
	brain_regions = BrainRegionsCache.new()
	mapping_data = MappingsCache.new()
	mapping_restrictions = load("res://addons/FeagiCoreIntegration/FeagiCore/MappingRestrictions.tres")

## Given several summary datas from FEAGI, we can build the entire cache at once
func replace_whole_genome(cortical_area_summary: Dictionary, morphologies_summary: Dictionary, mapping_summary: Dictionary, regions_summary: Dictionary) -> void:
	
	print("\nFEAGI CACHE: Replacing the ENTIRE local cached genome!")
	cache_about_to_reload.emit()
	clear_whole_genome()
	
	# Methdology:
	# Add Regions first, followed by establishing relations with child regions to parent regions
	# 	Given input data structure, we calculate a dict of corticalIDs mapped to a target region ID
	# Create cortical area objects, using the above dict to retrieve the parent region in an efficient manner
	# Create morphology objects
	# Create mapping objects
	# Create connection hint objects
	
	var cortical_area_IDs_mapped_to_parent_regions_IDs = brain_regions.FEAGI_load_all_regions_and_establish_relations_and_calculate_area_region_mapping(regions_summary) 
	cortical_areas.FEAGI_load_all_cortical_areas(cortical_area_summary, cortical_area_IDs_mapped_to_parent_regions_IDs)
	morphologies.update_morphology_cache_from_summary(morphologies_summary)
	mapping_data.FEAGI_load_all_mappings(mapping_summary)
	brain_regions.FEAGI_load_all_partial_mapping_sets(regions_summary)
	
	print("FEAGI CACHE: DONE Replacing the ENTIRE local cached genome!\n")
	cache_reloaded.emit()
#endregion

## Deletes the genome from cache (safely). NOTE: this triggers the cache_reloaded signal too
func clear_whole_genome() -> void:
	print("\nFEAGI CACHE: REMOVING the ENTIRE local cached genome!")
	mapping_data.FEAGI_delete_all_mappings()
	cortical_areas.FEAGI_hard_wipe_available_cortical_areas()
	morphologies.update_morphology_cache_from_summary({})
	clear_templates()
	print("FEAGI CACHE: DONE REMOVING the ENTIRE local cached genome!\n")
	cache_reloaded.emit()
	return
	

## Applies mass update of 2d locations to cortical areas. Only call from FEAGI
func FEAGI_mass_update_2D_positions(genome_objects_to_locations: Dictionary) -> void:
	var corticals: Dictionary = {}
	var regions: Dictionary = {}
	for genome_object: GenomeObject in genome_objects_to_locations.keys():
		if genome_object is AbstractCorticalArea:
			corticals[genome_object as AbstractCorticalArea] = genome_objects_to_locations[genome_object]
		if genome_object is BrainRegion:
			regions[genome_object as BrainRegion] = genome_objects_to_locations[genome_object]
	cortical_areas.FEAGI_mass_update_2D_positions(corticals)

## Deletes all mappings involving a cortical area before deleting the area itself
func FEAGI_delete_all_mappings_involving_area_and_area(deleting: AbstractCorticalArea) -> void:
	for recursive in deleting.recursive_mappings.keys():
		mapping_data.FEAGI_delete_mappings(deleting, deleting)
	for efferent in deleting.efferent_mappings.keys():
		mapping_data.FEAGI_delete_mappings(deleting, efferent)
	for afferent in deleting.afferent_mappings.keys():
		mapping_data.FEAGI_delete_mappings(afferent, deleting)
	cortical_areas.remove_cortical_area(deleting.cortical_ID)
	
	

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
			AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU
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
			AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU
		)
	
	_set_IPU_OPU_to_capability_key_mappings(ipu_devices["name_to_id_mapping"], opu_devices["name_to_id_mapping"])
	
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
signal genome_availability_or_brain_readiness_changed(available: bool, ready: bool)

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
var _neuron_count_max: int = -1
var _synapse_count_max: int = -1
var _neuron_count_current: int = -1
var _synapse_count_current: int = -1
var _genome_availability: bool
var _genome_validity: bool
var _brain_readiness: bool

var _pending_amalgamation: StringName = ""

## Given a dict form feagi of health info, update cached health values
func update_health_from_FEAGI_dict(health: Dictionary) -> void:
	
	if "genome_availability" in health and "brain_readiness" in health:
		if health["genome_availability"] != _genome_availability or health["brain_readiness"] != _brain_readiness:
			genome_availability_or_brain_readiness_changed.emit(health["genome_availability"], health["brain_readiness"])
	
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
	if "brain_readiness" in health: 
		brain_readiness = health["brain_readiness"]
	
	#TEMP amalgamation
	#TODO FEAGI really shouldnt be doing this here
	if "amalgamation_pending" in health:
		var dict: Dictionary = health["amalgamation_pending"]
		if "amalgamation_id" not in dict:
			push_error("FEAGI HEALTHCHECK: Pending amalgmation missing amalgamation_id")
			return
		if "genome_title" not in dict:
			push_error("FEAGI HEALTHCHECK: Pending amalgmation missing genome_title")
			return
		if "circuit_size" not in dict:
			push_error("FEAGI HEALTHCHECK: Pending amalgmation missing amalgamation_id")
			return

		var amal_ID: StringName = dict["amalgamation_id"]
		var amal_name: StringName = dict["genome_title"]
		var dimensions: Vector3i = FEAGIUtils.array_to_vector3i(dict["circuit_size"])
		
		if _pending_amalgamation == amal_ID:
			# we already know about this amalgamation, ignore
			return
		if _pending_amalgamation == "":
			print("FEAGI Cache: Detected Amalgamation request %s from healthcheck!" % amal_ID)
			amalgamation_pending.emit(amal_ID, amal_name, dimensions)
			_pending_amalgamation = amal_ID
	else:
		if _pending_amalgamation != "":
			# An amalgamation was pending, now its not (either due to confirmation OR deletion
			_pending_amalgamation = ""
			amalgamation_no_longer_pending.emit(_pending_amalgamation)
			
	

## Useful when communicaiton with feagi is lost, mark all cached health data as dead
func set_health_dead() -> void:
	burst_engine = false
	influxdb_availability = false
	neuron_count_max = 0
	synapse_count_max = 0
	neuron_count_current = 0
	synapse_count_current = 0
	genome_availability = false
	genome_validity = false
	brain_readiness = false
	
#endregion

#region Other
signal plasticity_queue_depth_changed(new_val: int)



var plasticity_queue_depth: int:
	get: return _plasticity_queue_depth

var configuration_jsons: Array[Dictionary]:
	get: return _configuration_jsons

var IPU_cortical_ID_to_capability_key: Dictionary:
	get: return _IPU_cortical_ID_to_capability_key

var OPU_cortical_ID_to_capability_key: Dictionary:
	get: return _OPU_cortical_ID_to_capability_key

var _plasticity_queue_depth: int = 3
var _configuration_jsons: Array[Dictionary] = []
var _OPU_cortical_ID_to_capability_key: Dictionary = {}
var _IPU_cortical_ID_to_capability_key: Dictionary = {}

func update_plasticity_queue_depth(new_depth: int) -> void:
	if new_depth == _plasticity_queue_depth:
		return
	_plasticity_queue_depth = new_depth
	plasticity_queue_depth_changed.emit(new_depth)

func clear_configuration_jsons() -> void:
	_configuration_jsons = []

## Add a configuration json to the cache. Dictionary should be the dictionary holding inputs / output keys
func append_configuration_json(configuration: Dictionary) -> void:
	_configuration_jsons.append(configuration)

## given the name_to_ID_mapping for IPU/OPU from FEAGI, store it in cache for later use
func _set_IPU_OPU_to_capability_key_mappings(IPU_mappings: Dictionary, OPU_mappings: Dictionary) -> void:
	_IPU_cortical_ID_to_capability_key = {}
	_OPU_cortical_ID_to_capability_key = {}
	
	for IPU_ID: String in IPU_mappings.keys():
		var IPU_cortical_IDs: String = IPU_mappings[IPU_ID]
		for IPU_cortical_ID in IPU_cortical_IDs:
			_IPU_cortical_ID_to_capability_key[IPU_cortical_ID] = IPU_ID
		
	for OPU_ID: String in OPU_mappings.keys():
		var OPU_cortical_IDs: String = OPU_mappings[OPU_ID]
		for OPU_cortical_ID in OPU_cortical_IDs:
			_OPU_cortical_ID_to_capability_key[OPU_cortical_ID] = OPU_ID
	

#endregion

