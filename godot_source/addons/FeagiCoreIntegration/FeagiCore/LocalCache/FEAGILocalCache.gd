extends RefCounted
class_name FEAGILocalCache

# Import the MappingRestrictionsAPI
const MappingRestrictionsAPI = preload("res://addons/FeagiCoreIntegration/FeagiCore/ConfigScripts/MappingRestrictions.gd")

## Helper function to safely convert dimensions data that might be Array or Dictionary
func _safe_convert_to_vector3i(data: Variant, field_name: String = "") -> Vector3i:
	if data is Array:
		return FEAGIUtils.array_to_vector3i(data)
	elif data is Dictionary:
		var dict_data: Dictionary = data as Dictionary
		# Handle common dictionary formats for 3D coordinates
		if dict_data.has("x") and dict_data.has("y") and dict_data.has("z"):
			return Vector3i(int(dict_data["x"]), int(dict_data["y"]), int(dict_data["z"]))
		elif dict_data.has("width") and dict_data.has("height") and dict_data.has("depth"):
			return Vector3i(int(dict_data["width"]), int(dict_data["height"]), int(dict_data["depth"]))
		else:
			push_error("FEAGI LOCAL CACHE: Unsupported dictionary format for %s: %s" % [field_name, str(dict_data)])
			return Vector3i(1, 1, 1)  # Default fallback
	else:
		push_error("FEAGI LOCAL CACHE: Unsupported data type for %s: %s" % [field_name, str(type_string(typeof(data)))])
		return Vector3i(1, 1, 1)  # Default fallback

#region main
signal cache_about_to_reload()
signal cache_reloaded()
signal amalgamation_pending(amalgamation_id: StringName, genome_title: StringName, dimensions: Vector3i) # is called any time a new amalgamation is pending
signal amalgamation_no_longer_pending(amalgamation_id: StringName) # may occur following confirmation OR deletion

var brain_regions: BrainRegionsCache
var cortical_areas: CorticalAreasCache
var morphologies: MorphologiesCache
var mapping_data: MappingsCache

func _init():
	cortical_areas = CorticalAreasCache.new()
	morphologies = MorphologiesCache.new()
	brain_regions = BrainRegionsCache.new()
	mapping_data = MappingsCache.new()
	
	# Connect to mapping update signals to automatically refresh brain region cache
	mapping_data.mapping_created.connect(_on_mapping_created)
	mapping_data.mapping_updated.connect(_on_mapping_updated)
	
	# Connect to brain region creation and modification signals
	brain_regions.region_added.connect(_on_brain_region_added)
	brain_regions.region_about_to_be_removed.connect(_on_brain_region_about_to_be_removed)

## Given several summary datas from FEAGI, we can build the entire cache at once
func replace_whole_genome(cortical_area_summary: Dictionary, morphologies_summary: Dictionary, mapping_summary: Dictionary, regions_summary: Dictionary) -> void:

	var _stack: Array = get_stack()
	var _caller: String = "unknown"
	if _stack.size() > 1 and _stack[1] is Dictionary and (_stack[1] as Dictionary).has("source"):
		_caller = String((_stack[1] as Dictionary)["source"])
	print("\n🔄 FEAGI CACHE: Replacing the ENTIRE local cached genome! (called from: %s)" % _caller)
	cache_about_to_reload.emit()
	clear_whole_genome()
	
	# Methdology:
	# Add Regions first, followed by establishing relations with child regions to parent regions
	# 	Given input data structure, we calculate a dict of corticalIDs mapped to a target region ID
	# Create cortical area objects, using the above dict to retrieve the parent region in an efficient manner
	# Create morphology objects
	# Create mapping objects
	# Create connection hint objects
	# Load mapping restrictions from server
	
	var cortical_area_IDs_mapped_to_parent_regions_IDs = brain_regions.FEAGI_load_all_regions_and_establish_relations_and_calculate_area_region_mapping(regions_summary) 
	cortical_areas.FEAGI_load_all_cortical_areas(cortical_area_summary, cortical_area_IDs_mapped_to_parent_regions_IDs)
	morphologies.update_morphology_cache_from_summary(morphologies_summary)
	mapping_data.FEAGI_load_all_mappings(mapping_summary)
	brain_regions.FEAGI_load_all_partial_mapping_sets(regions_summary)
	
	# Connect to signals from all existing brain regions for future updates
	_connect_to_existing_brain_region_signals()
	
	# Load mapping restrictions from server (async call)
	_load_mapping_restrictions_async()
	
	print("FEAGI CACHE: DONE Replacing the ENTIRE local cached genome!\n")
	print("FEAGI CACHE: 📡 Emitting cache_reloaded signal...")
	cache_reloaded.emit()
	print("FEAGI CACHE: ✅ cache_reloaded signal emitted successfully")

# Helper function to load mapping restrictions asynchronously
func _load_mapping_restrictions_async() -> void:
	var success = await MappingRestrictionsAPI.load_mapping_restrictions()
	if not success:
		push_warning("FEAGI CACHE: Failed to load mapping restrictions from server")

## Deletes the genome from cache (safely). NOTE: this triggers the cache_reloaded signal too
func clear_whole_genome() -> void:
	var _stack: Array = get_stack()
	var _caller: String = "unknown"
	if _stack.size() > 1 and _stack[1] is Dictionary and (_stack[1] as Dictionary).has("source"):
		_caller = String((_stack[1] as Dictionary)["source"])
	print("\n🗑️ FEAGI CACHE: REMOVING the ENTIRE local cached genome! (called from: %s)" % _caller)
	mapping_data.FEAGI_delete_all_mappings()
	cortical_areas.FEAGI_hard_wipe_available_cortical_areas()
	morphologies.update_morphology_cache_from_summary({})
	clear_templates()
	
	# Clear mapping restrictions cache
	MappingRestrictionsAPI.clear_cache()
	
	print("🗑️ FEAGI CACHE: DONE REMOVING the ENTIRE local cached genome!\n")
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
	print("🔍 TEMPLATE CACHE: Updating templates from FEAGI")
	
	# Handle nested structure: data might be under "types" key
	var template_data: Dictionary = dict
	if dict.has("types") and dict["types"] is Dictionary:
		template_data = dict["types"]
		print("🔍 TEMPLATE CACHE: Found nested 'types' structure, using nested data")
	
	# Safely access IPU devices
	if template_data.has("IPU") and template_data["IPU"] is Dictionary and template_data["IPU"].has("supported_devices"):
		var ipu_devices: Dictionary = template_data["IPU"]["supported_devices"]
		
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
	else:
		push_warning("FEAGI LOCAL CACHE: IPU templates data not found or invalid in update dictionary")
	
	# Safely access OPU devices
	if template_data.has("OPU") and template_data["OPU"] is Dictionary and template_data["OPU"].has("supported_devices"):
		var opu_devices: Dictionary = template_data["OPU"]["supported_devices"]
		
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
	else:
		push_warning("FEAGI LOCAL CACHE: OPU templates data not found or invalid in update dictionary")
	
	print("🔍 TEMPLATE CACHE: Final template counts - IPU: %d, OPU: %d" % [_IPU_templates.size(), _OPU_templates.size()])
	templates_updated.emit()
	
	# Safely access name to ID mappings
	var ipu_mapping: Dictionary = {}
	var opu_mapping: Dictionary = {}
	
	if template_data.has("IPU") and template_data["IPU"] is Dictionary and template_data["IPU"].has("name_to_id_mapping"):
		ipu_mapping = template_data["IPU"]["name_to_id_mapping"]
	else:
		push_warning("FEAGI LOCAL CACHE: IPU name_to_id_mapping not found in update dictionary")
		
	if template_data.has("OPU") and template_data["OPU"] is Dictionary and template_data["OPU"].has("name_to_id_mapping"):
		opu_mapping = template_data["OPU"]["name_to_id_mapping"]
	else:
		push_warning("FEAGI LOCAL CACHE: OPU name_to_id_mapping not found in update dictionary")
	
	_set_IPU_OPU_to_capability_key_mappings(ipu_mapping, opu_mapping)
	
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
signal simulation_timestep_changed(new_timestep: float)

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

var genome_num: int:
	get: return _genome_num

var simulation_timestep: float:
	get: return _simulation_timestep
	set(v):
		if v != _simulation_timestep:
			_simulation_timestep = v
			simulation_timestep_changed.emit(v)

var _burst_engine: bool
var _influxdb_availability: bool
var _neuron_count_max: int = -1
var _synapse_count_max: int = -1
var _neuron_count_current: int = -1
var _synapse_count_current: int = -1
var _genome_availability: bool
var _genome_validity: bool
var _brain_readiness: bool
var _genome_num: int = 0
var _simulation_timestep: float = 0.05  # Default 50ms

# Memory area stats from health check
var memory_area_stats: Dictionary = {}  # cortical_id -> {neuron_count, created_total, deleted_total, last_updated}
signal memory_area_stats_updated(stats: Dictionary)

var _pending_amalgamation: StringName = ""

## Given a dict form feagi of health info, update cached health values
func update_health_from_FEAGI_dict(health: Dictionary) -> void:
	
	# DEBUG: Show health check details for amalgamation tracking (only when relevant)
	if _pending_amalgamation != "":
		if health.has("amalgamation_pending"):
			print("FEAGI Cache: 🔍 HEALTH DEBUG - amalgamation_pending in health: %s" % health["amalgamation_pending"])
		else:
			print("FEAGI Cache: 🔍 HEALTH DEBUG - No amalgamation_pending in health data (expecting completion)")
		print("FEAGI Cache: 🔍 HEALTH DEBUG - Currently tracking pending amalgamation: '%s'" % _pending_amalgamation)
	
	if "genome_availability" in health and "brain_readiness" in health:
		var genome_avail = health["genome_availability"]
		var brain_ready = health["brain_readiness"]
		if genome_avail != null and brain_ready != null:
			if bool(genome_avail) != _genome_availability or bool(brain_ready) != _brain_readiness:
				genome_availability_or_brain_readiness_changed.emit(bool(genome_avail), bool(brain_ready))
	
	if "burst_engine" in health: 
		var value = health["burst_engine"]
		if value != null:
			burst_engine = bool(value)
	if "influxdb_availability" in health: 
		var value = health["influxdb_availability"]
		if value != null:
			influxdb_availability = bool(value)
	if "neuron_count_max" in health: 
		var value = health["neuron_count_max"]
		if value != null:
			neuron_count_max = int(value)
	if "synapse_count_max" in health: 
		var value = health["synapse_count_max"]
		if value != null:
			synapse_count_max = int(value)
	if "neuron_count" in health: 
		var value = health["neuron_count"]
		if value != null:
			neuron_count_current = int(value)
	if "synapse_count" in health: 
		var value = health["synapse_count"]
		if value != null:
			synapse_count_current = int(value)
	if "genome_availability" in health: 
		var value = health["genome_availability"]
		if value != null:
			genome_availability = bool(value)
	if "genome_validity" in health: 
		var value = health["genome_validity"]
		if value != null:
			genome_validity = bool(value)
	if "brain_readiness" in health: 
		var value = health["brain_readiness"]
		if value != null:
			brain_readiness = bool(value)
	if "genome_num" in health: 
		var value = health["genome_num"]
		if value != null:
			genome_num = int(value)
	
	# Handle simulation_timestep or burst_frequency
	if "simulation_timestep" in health:
		var value = health["simulation_timestep"]
		if value != null:
			var new_timestep = float(value)
			if new_timestep != simulation_timestep:
				print("🔥 FEAGI CACHE: Updated simulation_timestep from %s to %s seconds" % [simulation_timestep, new_timestep])
				simulation_timestep = new_timestep
				simulation_timestep_changed.emit(simulation_timestep)
	elif "burst_frequency" in health:
		var value = health["burst_frequency"]
		if value != null:
			var frequency = float(value)
			if frequency > 0.0:
				# Convert frequency to timestep (1/frequency)
				var timestep = 1.0 / frequency
				if timestep != simulation_timestep:
					print("🔥 FEAGI CACHE: Converted burst_frequency %s Hz to simulation_timestep %s seconds" % [frequency, timestep])
					simulation_timestep = timestep
					simulation_timestep_changed.emit(simulation_timestep)
			# Silently ignore invalid burst_frequency (0.0) to avoid spam
	
	# Handle memory area stats
	if "memory_area_stats" in health:
		var new_memory_stats = health["memory_area_stats"]
		if new_memory_stats != null and new_memory_stats is Dictionary:
			memory_area_stats = new_memory_stats.duplicate()
			# print("🧠 FEAGI CACHE: Updated memory area stats for ", memory_area_stats.size(), " areas")  # Suppressed to reduce log spam
			memory_area_stats_updated.emit(memory_area_stats)
	
	#TEMP amalgamation
	#TODO FEAGI really shouldnt be doing this here
	
	# Check if there's an active amalgamation in the health data
	var has_active_amalgamation = false
	if "amalgamation_pending" in health and health["amalgamation_pending"] != null:
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
		var dimensions: Vector3i = _safe_convert_to_vector3i(dict["circuit_size"], "circuit_size")
		
		if _pending_amalgamation == amal_ID:
			# we already know about this amalgamation, ignore
			return
		if _pending_amalgamation == "":
			print("FEAGI Cache: Detected Amalgamation request %s from healthcheck!" % amal_ID)
			print("FEAGI Cache: 🎯 SETTING _pending_amalgamation to: %s" % amal_ID)
			amalgamation_pending.emit(amal_ID, amal_name, dimensions)
			_pending_amalgamation = amal_ID
			print("FEAGI Cache: 🎯 CONFIRMED _pending_amalgamation is now: '%s'" % _pending_amalgamation)
		
		has_active_amalgamation = true
	
	# If no active amalgamation but we were tracking one, it's complete
	if not has_active_amalgamation and _pending_amalgamation != "":
		# An amalgamation was pending, now its not (either due to confirmation OR deletion
		var completed_amalgamation_id = _pending_amalgamation
		print("FEAGI Cache: 🎯 CRITICAL - Amalgamation %s is no longer pending - emitting completion signal" % completed_amalgamation_id)
		_pending_amalgamation = ""
		print("FEAGI Cache: 🎯 CRITICAL - About to emit amalgamation_no_longer_pending signal with ID: %s" % completed_amalgamation_id)
		amalgamation_no_longer_pending.emit(completed_amalgamation_id)
		print("FEAGI Cache: 🎯 CRITICAL - amalgamation_no_longer_pending signal emitted successfully")
			
	

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
		var IPU_cortical_IDs: Array = IPU_mappings[IPU_ID]
		for IPU_cortical_ID in IPU_cortical_IDs:
			_IPU_cortical_ID_to_capability_key[IPU_cortical_ID] = IPU_ID
		
	for OPU_ID: String in OPU_mappings.keys():
		var OPU_cortical_IDs: Array = OPU_mappings[OPU_ID]
		for OPU_cortical_ID in OPU_cortical_IDs:
			_OPU_cortical_ID_to_capability_key[OPU_cortical_ID] = OPU_ID
	

#endregion

#region Brain Region Cache Auto-Refresh

## Called when a new mapping is created - refreshes brain region cache designations
func _on_mapping_created(mapping: InterCorticalMappingSet) -> void:
	print("🔄 FEAGI CACHE: Auto-refreshing brain region cache due to mapping creation: %s -> %s" % [mapping.source_cortical_area.cortical_ID, mapping.destination_cortical_area.cortical_ID])
	_refresh_brain_region_cache_for_mapping(mapping)

## Called when an existing mapping is updated - refreshes brain region cache designations  
func _on_mapping_updated(mapping: InterCorticalMappingSet) -> void:
	print("🔄 FEAGI CACHE: Auto-refreshing brain region cache due to mapping update: %s -> %s" % [mapping.source_cortical_area.cortical_ID, mapping.destination_cortical_area.cortical_ID])
	_refresh_brain_region_cache_for_mapping(mapping)

## Called when a new brain region is created - immediately refresh its cache and connect to its signals
func _on_brain_region_added(region: BrainRegion) -> void:
	print("🔄 FEAGI CACHE: Auto-refreshing cache for newly created brain region: %s" % region.region_ID)
	
	# Connect to this region's area addition/removal signals for future updates
	region.cortical_area_added_to_region.connect(_on_cortical_area_added_to_region)
	region.cortical_area_removed_from_region.connect(_on_cortical_area_removed_from_region)
	
	# Only refresh if the region has cortical areas already
	# This avoids conflicts with FEAGI partial mapping loading
	if region.contained_cortical_areas.size() > 0:
		_refresh_single_brain_region_cache(region)

## Called when a brain region is about to be removed - disconnect from its signals
func _on_brain_region_about_to_be_removed(region: BrainRegion) -> void:
	print("🔄 FEAGI CACHE: Disconnecting signals for brain region about to be removed: %s" % region.region_ID)
	
	# Disconnect from this region's signals
	if region.cortical_area_added_to_region.is_connected(_on_cortical_area_added_to_region):
		region.cortical_area_added_to_region.disconnect(_on_cortical_area_added_to_region)
	if region.cortical_area_removed_from_region.is_connected(_on_cortical_area_removed_from_region):
		region.cortical_area_removed_from_region.disconnect(_on_cortical_area_removed_from_region)

## Called when a cortical area is added to a brain region - refresh that region's cache
func _on_cortical_area_added_to_region(area: AbstractCorticalArea) -> void:
	var region = area.current_parent_region
	if region:
		print("🔄 FEAGI CACHE: Auto-refreshing brain region cache due to area addition: %s added to %s" % [area.cortical_ID, region.region_ID])
		_refresh_single_brain_region_cache(region)

## Called when a cortical area is removed from a brain region - refresh that region's cache  
func _on_cortical_area_removed_from_region(area: AbstractCorticalArea) -> void:
	# Note: We need to get the region from the signal context since the area might already be moved
	# For now, we'll refresh all regions that might be affected
	print("🔄 FEAGI CACHE: Auto-refreshing brain region caches due to area removal: %s" % area.cortical_ID)
	
	# Since the area might have been moved, refresh all regions to be safe
	# This is less efficient but ensures correctness
	for region_id in brain_regions.available_brain_regions.keys():
		var region = brain_regions.available_brain_regions[region_id]
		_refresh_single_brain_region_cache(region)

## Refreshes brain region input/output cache designations when cortical mappings change
func _refresh_brain_region_cache_for_mapping(mapping: InterCorticalMappingSet) -> void:
	# Get the regions that contain the source and destination areas
	var source_region: BrainRegion = mapping.source_cortical_area.current_parent_region
	var destination_region: BrainRegion = mapping.destination_cortical_area.current_parent_region
	
	# Refresh cache for both regions if they exist
	if source_region:
		_refresh_single_brain_region_cache(source_region)
	if destination_region and destination_region != source_region:
		_refresh_single_brain_region_cache(destination_region)

## Refreshes the partial mapping cache for a specific brain region
func _refresh_single_brain_region_cache(region: BrainRegion) -> void:
	print("🔄 FEAGI CACHE: Refreshing cache designations for brain region: %s" % region.region_ID)
	
	# Derive input/output designations from current cortical mappings and connections
	_update_brain_region_io_designations_from_local_mappings(region)

## Updates brain region input/output designations based on current local mapping cache
func _update_brain_region_io_designations_from_local_mappings(region: BrainRegion) -> void:
	# DON'T clear existing partial mappings - they might be from FEAGI and still valid
	# Only add synthetic mappings for areas that don't already have partial mappings
	
	# Analyze current cortical mappings to determine input/output designations
	var input_areas: Array[AbstractCorticalArea] = []
	var output_areas: Array[AbstractCorticalArea] = []
	
	# Method 1: Analyze connection chain links for this region
	for input_link in region.input_open_chain_links:
		if input_link.destination and input_link.destination is AbstractCorticalArea:
			var dest_area = input_link.destination as AbstractCorticalArea
			if dest_area in region.contained_cortical_areas and not input_areas.has(dest_area):
				input_areas.append(dest_area)
	
	for output_link in region.output_open_chain_links:
		if output_link.source and output_link.source is AbstractCorticalArea:
			var source_area = output_link.source as AbstractCorticalArea
			if source_area in region.contained_cortical_areas and not output_areas.has(source_area):
				output_areas.append(source_area)
	
	# Method 2: Analyze cortical mappings that cross region boundaries
	for contained_area in region.contained_cortical_areas:
		# Check if this area receives inputs from outside the region (making it an input area)
		for afferent_id in contained_area.afferent_mappings.keys():
			var afferent_area = cortical_areas.available_cortical_areas.get(afferent_id)
			if afferent_area and afferent_area.current_parent_region != region:
				if not input_areas.has(contained_area):
					input_areas.append(contained_area)
		
		# Check if this area sends outputs outside the region (making it an output area)  
		for efferent_id in contained_area.efferent_mappings.keys():
			var efferent_area = cortical_areas.available_cortical_areas.get(efferent_id)
			if efferent_area and efferent_area.current_parent_region != region:
				if not output_areas.has(contained_area):
					output_areas.append(contained_area)
	
	# Method 3: Use cortical area types as fallback hints
	for contained_area in region.contained_cortical_areas:
		if contained_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			if not input_areas.has(contained_area):
				input_areas.append(contained_area)
		elif contained_area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			if not output_areas.has(contained_area):
				output_areas.append(contained_area)
	
	# Only create synthetic partial mappings for areas that don't already have them
	var areas_with_existing_mappings: Array[AbstractCorticalArea] = []
	for existing_mapping in region.partial_mappings:
		if existing_mapping.internal_target_cortical_area not in areas_with_existing_mappings:
			areas_with_existing_mappings.append(existing_mapping.internal_target_cortical_area)
	
	# Filter out areas that already have partial mappings
	var new_input_areas: Array[AbstractCorticalArea] = []
	var new_output_areas: Array[AbstractCorticalArea] = []
	
	for input_area in input_areas:
		if input_area not in areas_with_existing_mappings:
			new_input_areas.append(input_area)
	
	for output_area in output_areas:
		if output_area not in areas_with_existing_mappings:
			new_output_areas.append(output_area)
	
	# Only create synthetic mappings for truly new areas
	if new_input_areas.size() > 0 or new_output_areas.size() > 0:
		_create_synthetic_partial_mappings_for_region(region, new_input_areas, new_output_areas)
		print("✅ FEAGI CACHE: Added synthetic I/O designations - Region: %s, New Inputs: %d, New Outputs: %d" % [region.region_ID, new_input_areas.size(), new_output_areas.size()])
	else:
		print("✅ FEAGI CACHE: No new I/O designations needed - Region: %s already has adequate mappings" % region.region_ID)

## Creates synthetic partial mappings for a brain region based on analyzed input/output areas
func _create_synthetic_partial_mappings_for_region(region: BrainRegion, input_areas: Array[AbstractCorticalArea], output_areas: Array[AbstractCorticalArea]) -> void:
	# Create input partial mappings
	for input_area in input_areas:
		var synthetic_input_mapping = _create_synthetic_partial_mapping(input_area, region, true)
		if synthetic_input_mapping:
			region._partial_mappings.append(synthetic_input_mapping)
			region.partial_mappings_inputted.emit(synthetic_input_mapping)
	
	# Create output partial mappings
	for output_area in output_areas:
		var synthetic_output_mapping = _create_synthetic_partial_mapping(output_area, region, false)
		if synthetic_output_mapping:
			region._partial_mappings.append(synthetic_output_mapping)
			region.partial_mappings_inputted.emit(synthetic_output_mapping)

## Creates a synthetic partial mapping for an area within a region
func _create_synthetic_partial_mapping(area: AbstractCorticalArea, region: BrainRegion, is_input: bool) -> PartialMappingSet:
	# Create a minimal synthetic mapping based on the area's current state
	var synthetic_mappings: Array[SingleMappingDefinition] = []
	
	# Try to get a suitable morphology, fallback to memory morphology, then to null
	var morphology: BaseMorphology = morphologies.try_get_morphology_object(&"memory")
	if morphology == null:
		# If memory morphology doesn't exist, try to get any available morphology
		if morphologies.available_morphologies.size() > 0:
			var first_key = morphologies.available_morphologies.keys()[0]
			morphology = morphologies.available_morphologies[first_key]
	
	# Create a default mapping with the found morphology (can be null)
	var default_mapping = SingleMappingDefinition.create_default_mapping(morphology)
	synthetic_mappings.append(default_mapping)
	
	# Create a descriptive label
	var direction_label = "INPUT" if is_input else "OUTPUT"
	var label = "%s_%s_AUTO_REFRESH" % [direction_label, area.cortical_ID]
	
	return PartialMappingSet.new(is_input, synthetic_mappings, area, region, label)

## Clears existing partial mappings from a brain region
func _clear_region_partial_mappings(region: BrainRegion) -> void:
	# Create a copy to avoid modification during iteration
	var mappings_to_remove = region.partial_mappings.duplicate()
	
	for mapping in mappings_to_remove:
		# Trigger the removal signal and cleanup
		mapping.mappings_about_to_be_deleted.emit(mapping)

## Connects to signals from all existing brain regions (called during genome load)
func _connect_to_existing_brain_region_signals() -> void:
	print("🔄 FEAGI CACHE: Connecting to signals from %d existing brain regions" % brain_regions.available_brain_regions.size())
	
	for region_id in brain_regions.available_brain_regions.keys():
		var region = brain_regions.available_brain_regions[region_id]
		
		# Connect to area addition/removal signals if not already connected
		if not region.cortical_area_added_to_region.is_connected(_on_cortical_area_added_to_region):
			region.cortical_area_added_to_region.connect(_on_cortical_area_added_to_region)
		if not region.cortical_area_removed_from_region.is_connected(_on_cortical_area_removed_from_region):
			region.cortical_area_removed_from_region.connect(_on_cortical_area_removed_from_region)
		
		# Don't immediately refresh during genome load - let FEAGI partial mappings load first
		# _refresh_single_brain_region_cache(region)

#endregion
