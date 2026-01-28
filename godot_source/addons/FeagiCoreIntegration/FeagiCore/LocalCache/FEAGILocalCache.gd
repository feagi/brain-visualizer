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
signal mappings_reloaded()
signal cortical_areas_reloaded()
signal brain_regions_reloaded()
signal morphologies_reloaded()
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
	print("FEAGI CACHE: Replacing genome from %s" % _caller)
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
	
	cache_reloaded.emit()

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
	
	mapping_data.FEAGI_delete_all_mappings()
	cortical_areas.FEAGI_hard_wipe_available_cortical_areas()
	
	# CRITICAL: Ensure brain regions are also completely cleared  
	brain_regions.FEAGI_clear_all_regions()
	
	morphologies.update_morphology_cache_from_summary({})
	clear_templates()
	
	# Clear mapping restrictions cache
	MappingRestrictionsAPI.clear_cache()
	
	cache_reloaded.emit()
	

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
			
			# Handle both old format (cortical_name) and new format (description)
			var cortical_name: String = ipu_device.get("cortical_name", ipu_device.get("description", "Unknown"))
			var enabled: bool = ipu_device.get("enabled", true)
			
			_IPU_templates[ipu_ID] = CorticalTemplate.new(
				ipu_ID,
				enabled,
				cortical_name,
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
			
			# Handle both old format (cortical_name) and new format (description)
			var cortical_name: String = opu_device.get("cortical_name", opu_device.get("description", "Unknown"))
			var enabled: bool = opu_device.get("enabled", true)
			
			_OPU_templates[opu_ID] = CorticalTemplate.new(
				opu_ID,
				enabled,
				cortical_name,
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
signal genome_refresh_needed(feagi_session: int, genome_num: int, reason: String)
signal agent_reregistration_needed(reason: String)  # Emitted when FEAGI restarts and agent needs to re-register

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

# Genome change detection tracking
var _previous_feagi_session: int = 0
var _previous_genome_num: int = 0
var _had_valid_session: bool = false  # Track if we ever had a valid session (to detect FEAGI restart)
var _last_genome_change_time: int = 0  # Time of last change detection
var _genome_change_cooldown_ms: int = 10000  # 10 second cooldown

# Hash change detection tracking (event-driven hashes from health_check)
var _previous_brain_regions_hash: int = 0
var _previous_cortical_areas_hash: int = 0
var _previous_brain_geometry_hash: int = 0
var _previous_morphologies_hash: int = 0
var _previous_cortical_mappings_hash: int = 0
var _hash_refresh_in_flight: Dictionary = {}
var _pending_hash_values: Dictionary = {}

var _pending_amalgamation: StringName = ""

## Given a dict form feagi of health info, update cached health values
func update_health_from_FEAGI_dict(health: Dictionary) -> void:
	
	# GENOME CHANGE DETECTION: Check feagi_session and genome_num for changes
	if "feagi_session" in health and "genome_num" in health:
		var feagi_session_value = health["feagi_session"]
		var genome_num_value = health["genome_num"]
		
		# CRITICAL: Detect FEAGI readiness (null → valid session) to trigger agent re-registration
		# This handles the case where BV connects before FEAGI is ready (feagi_session is null)
		# and then FEAGI becomes ready (feagi_session becomes valid)
		if feagi_session_value != null and (typeof(feagi_session_value) == TYPE_INT or typeof(feagi_session_value) == TYPE_FLOAT):
			var current_session = int(feagi_session_value)
			# Detect transition from null/invalid to valid session (FEAGI became ready)
			# Only trigger if:
			# 1. Current session is valid (> 0)
			# 2. We haven't seen a valid session yet (or previous was 0)
			# 3. BV is already connected (not during initial connection attempt)
			if current_session > 0:
				var was_previously_null_or_zero = (_previous_feagi_session == 0 and not _had_valid_session)
				if was_previously_null_or_zero:
					_had_valid_session = true
					# Only trigger re-registration if BV is already connected (not during initial connection)
					# Check if FeagiCore exists and is in a connected state
					if FeagiCore and FeagiCore.network:
						var conn_state = FeagiCore.network.connection_state
						var is_already_connected = (conn_state == FeagiCore.network.CONNECTION_STATE.HEALTHY or 
													conn_state == FeagiCore.network.CONNECTION_STATE.RETRYING_HTTP or
													conn_state == FeagiCore.network.CONNECTION_STATE.RETRYING_WS)
						if is_already_connected:
							print("🔍 [AGENT-REG] FEAGI became ready (session: %d) while BV is connected - triggering re-registration" % current_session)
							agent_reregistration_needed.emit("FEAGI became ready (session: %d)" % current_session)
		
		# Genome change detection requires BOTH feagi_session and genome_num to be non-null
		# This ensures we only detect changes when FEAGI is fully initialized
		if feagi_session_value != null and genome_num_value != null:
			var current_feagi_session = int(feagi_session_value)
			var current_genome_num = int(genome_num_value)

			# Cache and health status checks
			var health_genome_available = health.get("genome_availability", false)
			var health_brain_ready = health.get("brain_readiness", false)
			var cache_is_empty = (cortical_areas.available_cortical_areas.size() == 0 and brain_regions.available_brain_regions.size() == 0)

			# Session changes: detect both initial connection (0 → new) and FEAGI restarts (old → new)
			var session_changed = ((_previous_feagi_session == 0 and current_feagi_session > 0) or
								  (_previous_feagi_session != 0 and current_feagi_session != _previous_feagi_session))
			
			# If session changed and we previously had a valid session, trigger agent re-registration
			if session_changed and _previous_feagi_session != 0:
				print("🔍 [AGENT-REG] FEAGI session changed (old: %d → new: %d) - agent needs to re-register" % [_previous_feagi_session, current_feagi_session])
				agent_reregistration_needed.emit("FEAGI restarted (session: %d → %d)" % [_previous_feagi_session, current_feagi_session])

			# Genome changes: only detect actual changes (not initial from 0)
			var genome_changed = (_previous_genome_num != 0 and current_genome_num != _previous_genome_num)
			
			# DEBUG: Log genome_num tracking
			if _previous_genome_num != current_genome_num:
				print("🧬 [GENOME-CHANGE-DEBUG] genome_num changed: %d → %d (will reload: %s)" % [_previous_genome_num, current_genome_num, genome_changed])

			# Special case: If we have genome data but both session and genome are different from what we expect,
			# this might be a FEAGI restart that we missed - force a reload
			var force_reload_needed = false
			if FeagiCore.genome_load_state == FeagiCore.GENOME_LOAD_STATE.GENOME_READY and current_feagi_session > 0 and current_genome_num > 0:
				if _previous_feagi_session != current_feagi_session or _previous_genome_num != current_genome_num:
					print("  - WARNING: Loaded genome state but session/genome mismatch - forcing reload")
					force_reload_needed = true

			if health_genome_available and health_brain_ready and cache_is_empty and current_genome_num > 0:
				force_reload_needed = true


			if session_changed or genome_changed or force_reload_needed:
				# CRITICAL FIX: Never apply cooldown to initial startup (when _previous_feagi_session was 0)
				var is_initial_startup = (_previous_feagi_session == 0)

				if not is_initial_startup:  # Only apply cooldown after initial startup
					# Check cooldown to prevent rapid-fire reloads (but NOT on initial startup!)
					var current_time = Time.get_ticks_msec()
					if current_time - _last_genome_change_time < _genome_change_cooldown_ms:
						var remaining_cooldown = (_genome_change_cooldown_ms - (current_time - _last_genome_change_time)) / 1000.0
						print("⚠️ FEAGI CACHE: Genome change detected but still in cooldown period (%.1fs remaining)" % remaining_cooldown)
						# Update tracking variables but don't trigger reload
						_previous_feagi_session = current_feagi_session
						_previous_genome_num = current_genome_num
						return

				# Check if genome is already reloading (but allow force reload to override stuck reloads)
				if FeagiCore.genome_load_state == FeagiCore.GENOME_LOAD_STATE.GENOME_RELOADING:
					if force_reload_needed and cache_is_empty:
						# Force reload to break out of stuck state
						pass
					else:
						# Update tracking variables but don't trigger another reload
						_previous_feagi_session = current_feagi_session
						_previous_genome_num = current_genome_num
						return

				var reason = ""
				if session_changed:
					if is_initial_startup:
						reason = "Initial BV startup (session: %d)" % current_feagi_session
					else:
						reason = "FEAGI restarted (session: %d → %d)" % [_previous_feagi_session, current_feagi_session]
				if genome_changed:
					if reason != "":
						reason += " & "
					reason += "genome changed (num: %d → %d)" % [_previous_genome_num, current_genome_num]
				if force_reload_needed:
					if reason != "":
						reason += " & "
					if cache_is_empty:
						if FeagiCore.genome_load_state == FeagiCore.GENOME_LOAD_STATE.GENOME_RELOADING:
							reason += "STUCK RELOAD - cache empty despite GENOME_RELOADING state"
						else:
							reason += "cache empty despite genome ready"
					else:
						reason += "state mismatch detected"

				var current_time = Time.get_ticks_msec()
				_last_genome_change_time = current_time
				genome_refresh_needed.emit(current_feagi_session, current_genome_num, reason)

			_previous_feagi_session = current_feagi_session
			_previous_genome_num = current_genome_num
	
	_process_hash_change_detection(health)
	
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
				print("🔥 FEAGI CACHE: Updated simulation_timestep from %s to %s seconds (from FEAGI health check 'simulation_timestep' field)" % [simulation_timestep, new_timestep])
				simulation_timestep = new_timestep
				simulation_timestep_changed.emit(simulation_timestep)
		else:
			print("🔥 FEAGI CACHE: Health check contains 'simulation_timestep' key but value is null")
	elif "burst_frequency" in health:
		var value = health["burst_frequency"]
		if value != null:
			var frequency = float(value)
			if frequency > 0.0:
				# Convert frequency to timestep (1/frequency)
				var timestep = 1.0 / frequency
				if timestep != simulation_timestep:
					print("🔥 FEAGI CACHE: Converted burst_frequency %s Hz to simulation_timestep %s seconds (FEAGI did not send 'simulation_timestep', using 'burst_frequency' instead)" % [frequency, timestep])
					simulation_timestep = timestep
					simulation_timestep_changed.emit(simulation_timestep)
			# Silently ignore invalid burst_frequency (0.0) to avoid spam
		else:
			print("🔥 FEAGI CACHE: Health check contains 'burst_frequency' key but value is null")
	else:
		# Log when neither field is present (only once to avoid spam)
		if not has_meta("_logged_missing_timestep"):
			print("🔥 FEAGI CACHE: WARNING - Health check does not contain 'simulation_timestep' or 'burst_frequency'. Using default/cached value: %s seconds" % simulation_timestep)
			set_meta("_logged_missing_timestep", true)
	
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
signal agent_capabilities_updated()



var plasticity_queue_depth: int:
	get: return _plasticity_queue_depth

var configuration_jsons: Array[Dictionary]:
	get: return _configuration_jsons

var agent_capabilities_map: Dictionary:
	get: return _agent_capabilities_map

var IPU_cortical_ID_to_capability_key: Dictionary:
	get: return _IPU_cortical_ID_to_capability_key

var OPU_cortical_ID_to_capability_key: Dictionary:
	get: return _OPU_cortical_ID_to_capability_key

var _plasticity_queue_depth: int = 3
var _configuration_jsons: Array[Dictionary] = []
var _agent_capabilities_map: Dictionary = {}
var _OPU_cortical_ID_to_capability_key: Dictionary = {}
var _IPU_cortical_ID_to_capability_key: Dictionary = {}

func update_plasticity_queue_depth(new_depth: int) -> void:
	if new_depth == _plasticity_queue_depth:
		return
	_plasticity_queue_depth = new_depth
	plasticity_queue_depth_changed.emit(new_depth)

func clear_configuration_jsons() -> void:
	_configuration_jsons = []

## Overwrites cached agent capability data (capabilities + device registrations).
func set_agent_capabilities_map(new_map: Dictionary) -> void:
	_agent_capabilities_map = new_map
	agent_capabilities_updated.emit()

## Clears cached agent capability data.
func clear_agent_capabilities_map() -> void:
	_agent_capabilities_map = {}
	agent_capabilities_updated.emit()

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

## Remap a cortical ID across cache structures (used when FEAGI changes cortical ID).
func FEAGI_remap_cortical_id(old_id: StringName, new_id: StringName) -> void:
	if old_id == new_id:
		return
	cortical_areas.FEAGI_update_cortical_area_id(old_id, new_id)
	mapping_data.FEAGI_remap_cortical_id(old_id, new_id)
	if _IPU_cortical_ID_to_capability_key.has(old_id):
		_IPU_cortical_ID_to_capability_key[new_id] = _IPU_cortical_ID_to_capability_key[old_id]
		_IPU_cortical_ID_to_capability_key.erase(old_id)
	if _OPU_cortical_ID_to_capability_key.has(old_id):
		_OPU_cortical_ID_to_capability_key[new_id] = _OPU_cortical_ID_to_capability_key[old_id]
		_OPU_cortical_ID_to_capability_key.erase(old_id)
	

#endregion

#region Brain Region Cache Auto-Refresh

## Controls verbose cache logging in this module.
## Disabled by default to avoid console spam during high-frequency mapping/cache updates.
const _ENABLE_CACHE_INFO_LOGS: bool = false

func _cache_info(message: String) -> void:
	if not _ENABLE_CACHE_INFO_LOGS:
		return
	print(message)

## Called when a new mapping is created - refreshes brain region cache designations
func _on_mapping_created(mapping: InterCorticalMappingSet) -> void:
	_cache_info("FEAGI CACHE: Auto-refreshing brain region cache due to mapping creation: %s -> %s" % [mapping.source_cortical_area.cortical_ID, mapping.destination_cortical_area.cortical_ID])
	_refresh_brain_region_cache_for_mapping(mapping)

## Called when an existing mapping is updated - refreshes brain region cache designations  
func _on_mapping_updated(mapping: InterCorticalMappingSet) -> void:
	_cache_info("FEAGI CACHE: Auto-refreshing brain region cache due to mapping update: %s -> %s" % [mapping.source_cortical_area.cortical_ID, mapping.destination_cortical_area.cortical_ID])
	_refresh_brain_region_cache_for_mapping(mapping)

## Called when a new brain region is created - immediately refresh its cache and connect to its signals
func _on_brain_region_added(region: BrainRegion) -> void:
	_cache_info("FEAGI CACHE: Auto-refreshing cache for newly created brain region: %s" % region.region_ID)
	
	# Connect to this region's area addition/removal signals for future updates
	region.cortical_area_added_to_region.connect(_on_cortical_area_added_to_region)
	region.cortical_area_removed_from_region.connect(_on_cortical_area_removed_from_region)
	
	# Only refresh if the region has cortical areas already
	# This avoids conflicts with FEAGI partial mapping loading
	if region.contained_cortical_areas.size() > 0:
		_refresh_single_brain_region_cache(region)

## Called when a brain region is about to be removed - disconnect from its signals
func _on_brain_region_about_to_be_removed(region: BrainRegion) -> void:
	_cache_info("FEAGI CACHE: Disconnecting signals for brain region about to be removed: %s" % region.region_ID)
	
	# Disconnect from this region's signals
	if region.cortical_area_added_to_region.is_connected(_on_cortical_area_added_to_region):
		region.cortical_area_added_to_region.disconnect(_on_cortical_area_added_to_region)
	if region.cortical_area_removed_from_region.is_connected(_on_cortical_area_removed_from_region):
		region.cortical_area_removed_from_region.disconnect(_on_cortical_area_removed_from_region)

## Called when a cortical area is added to a brain region - refresh that region's cache
func _on_cortical_area_added_to_region(area: AbstractCorticalArea) -> void:
	var region = area.current_parent_region
	if region:
		_cache_info("FEAGI CACHE: Auto-refreshing brain region cache due to area addition: %s added to %s" % [area.cortical_ID, region.region_ID])
		_refresh_single_brain_region_cache(region)

## Called when a cortical area is removed from a brain region - refresh that region's cache  
func _on_cortical_area_removed_from_region(area: AbstractCorticalArea) -> void:
	# Note: We need to get the region from the signal context since the area might already be moved
	# For now, we'll refresh all regions that might be affected
	_cache_info("FEAGI CACHE: Auto-refreshing brain region caches due to area removal: %s" % area.cortical_ID)
	
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
	_cache_info("FEAGI CACHE: Refreshing cache designations for brain region: %s" % region.region_ID)
	
	# Derive input/output designations from current cortical mappings and connections
	_update_brain_region_io_designations_from_local_mappings(region)

## Checks health hashes and triggers targeted cache refreshes
func _process_hash_change_detection(health: Dictionary) -> void:
	if not _should_process_hash_refreshes():
		return
	
	_previous_brain_regions_hash = _check_hash_and_queue(
		&"brain_regions_hash",
		health.get("brain_regions_hash", null),
		_previous_brain_regions_hash,
		&"_refresh_brain_regions_from_feagi"
	)
	_previous_cortical_areas_hash = _check_hash_and_queue(
		&"cortical_areas_hash",
		health.get("cortical_areas_hash", null),
		_previous_cortical_areas_hash,
		&"_refresh_cortical_areas_from_feagi"
	)
	_previous_brain_geometry_hash = _check_hash_and_queue(
		&"brain_geometry_hash",
		health.get("brain_geometry_hash", null),
		_previous_brain_geometry_hash,
		&"_refresh_brain_geometry_from_feagi"
	)
	_previous_morphologies_hash = _check_hash_and_queue(
		&"morphologies_hash",
		health.get("morphologies_hash", null),
		_previous_morphologies_hash,
		&"_refresh_morphologies_from_feagi"
	)
	_previous_cortical_mappings_hash = _check_hash_and_queue(
		&"cortical_mappings_hash",
		health.get("cortical_mappings_hash", null),
		_previous_cortical_mappings_hash,
		&"_refresh_mappings_from_feagi"
	)

## Determines if hash-driven refreshes should run
func _should_process_hash_refreshes() -> bool:
	if not FeagiCore:
		return false
	if FeagiCore.genome_load_state != FeagiCore.GENOME_LOAD_STATE.GENOME_READY:
		return false
	if not FeagiCore.network or not FeagiCore.requests:
		return false
	if cortical_areas.available_cortical_areas.size() == 0:
		return false
	return true

## Evaluates hash changes and schedules refresh when mismatch is detected
func _check_hash_and_queue(hash_key: StringName, current_value: Variant, previous_value: int, refresh_method: StringName) -> int:
	if current_value == null:
		return previous_value
	
	var current_hash: int = int(current_value)
	if previous_value == 0:
		return current_hash
	
	if current_hash != previous_value:
		print("HASH CHANGE DETECTED: %s %d -> %d (refresh=%s)" % [hash_key, previous_value, current_hash, refresh_method])
		_queue_hash_refresh(hash_key, current_hash, refresh_method)
	
	return previous_value

## Queue a hash refresh if one is not already running for the given key
func _queue_hash_refresh(hash_key: StringName, new_hash: int, refresh_method: StringName) -> void:
	if _hash_refresh_in_flight.get(hash_key, false):
		_pending_hash_values[hash_key] = new_hash
		return
	
	_hash_refresh_in_flight[hash_key] = true
	_pending_hash_values[hash_key] = new_hash
	call_deferred("_run_hash_refresh", hash_key, refresh_method)

## Runs the refresh method and updates the hash when successful
func _run_hash_refresh(hash_key: StringName, refresh_method: StringName) -> void:
	var call_result = call(refresh_method)
	if typeof(call_result) == TYPE_OBJECT and call_result.has_signal("completed"):
		call_result.completed.connect(_on_hash_refresh_completed.bind(hash_key), CONNECT_ONE_SHOT)
		return
	_finalize_hash_refresh(hash_key, call_result)

## Handles completion of async hash refresh calls
func _on_hash_refresh_completed(result: Variant, hash_key: StringName) -> void:
	_finalize_hash_refresh(hash_key, result)

## Applies refresh results and updates tracked hash values
func _finalize_hash_refresh(hash_key: StringName, result: Variant) -> void:
	if result is FeagiRequestOutput and result.success:
		_set_previous_hash_value(hash_key, int(_pending_hash_values.get(hash_key, 0)))
	_hash_refresh_in_flight.erase(hash_key)

## Applies the latest successful hash value to the tracked state
func _set_previous_hash_value(hash_key: StringName, value: int) -> void:
	match hash_key:
		&"brain_regions_hash":
			_previous_brain_regions_hash = value
		&"cortical_areas_hash":
			_previous_cortical_areas_hash = value
		&"brain_geometry_hash":
			_previous_brain_geometry_hash = value
		&"morphologies_hash":
			_previous_morphologies_hash = value
		&"cortical_mappings_hash":
			_previous_cortical_mappings_hash = value
		_:
			pass

## Refresh brain regions (and dependent cortical areas) from FEAGI
func _refresh_brain_regions_from_feagi() -> FeagiRequestOutput:
	var regions_output: FeagiRequestOutput = await FeagiCore.requests.get_regions_summary()
	if regions_output.has_errored or not regions_output.success:
		return regions_output
	
	var regions_summary: Dictionary = regions_output.decode_response_as_dict()
	var prior_region_ids: Array = brain_regions.available_brain_regions.keys()
	var area_mapping: Dictionary = brain_regions.FEAGI_apply_region_summary_diff(regions_summary)
	_refresh_partial_mappings_from_summary(regions_summary)
	_connect_to_existing_brain_region_signals()
	
	var cortical_output: FeagiRequestOutput = await FeagiCore.requests.get_cortical_area_geometry()
	if cortical_output.has_errored or not cortical_output.success:
		return cortical_output
	
	_apply_cortical_area_refresh(cortical_output.decode_response_as_dict(), area_mapping)
	print("HASH REFRESH: brain_regions_reloaded emitted for brain_regions_hash")
	brain_regions_reloaded.emit()
	cortical_areas_reloaded.emit()
	_emit_new_region_added_signals(prior_region_ids)
	return cortical_output

## Refresh cortical areas and properties from FEAGI
func _refresh_cortical_areas_from_feagi() -> FeagiRequestOutput:
	var cortical_output: FeagiRequestOutput = await FeagiCore.requests.get_cortical_area_geometry()
	if cortical_output.has_errored or not cortical_output.success:
		return cortical_output
	
	_apply_cortical_area_refresh(cortical_output.decode_response_as_dict(), {})
	print("HASH REFRESH: cortical_areas_reloaded emitted for cortical_areas_hash")
	cortical_areas_reloaded.emit()
	return cortical_output

## Refresh brain geometry (positions/dimensions) from FEAGI
func _refresh_brain_geometry_from_feagi() -> FeagiRequestOutput:
	return await _refresh_cortical_areas_from_feagi()

## Refresh morphologies from FEAGI
func _refresh_morphologies_from_feagi() -> FeagiRequestOutput:
	var morphologies_output: FeagiRequestOutput = await FeagiCore.requests.get_morphologies_summary()
	if morphologies_output.has_errored or not morphologies_output.success:
		return morphologies_output
	
	morphologies.update_morphology_cache_from_summary(morphologies_output.decode_response_as_dict())
	print("HASH REFRESH: morphologies_reloaded emitted for morphologies_hash")
	morphologies_reloaded.emit()
	return morphologies_output

## Refresh cortical mappings from FEAGI
func _refresh_mappings_from_feagi() -> FeagiRequestOutput:
	var mappings_output: FeagiRequestOutput = await FeagiCore.requests.get_mapping_summary()
	if mappings_output.has_errored or not mappings_output.success:
		return mappings_output
	
	mapping_data.FEAGI_apply_mapping_summary_diff(mappings_output.decode_response_as_dict())
	print("HASH REFRESH: mappings_reloaded emitted for cortical_mappings_hash")
	mappings_reloaded.emit()
	return mappings_output

## Update cortical areas cache using summary data without wiping the entire genome
func _apply_cortical_area_refresh(area_summary_data: Dictionary, area_ID_to_region_ID_mapping: Dictionary) -> void:
	var previous_suppress_state = cortical_areas.suppress_update_notifications
	cortical_areas.suppress_update_notifications = true
	var existing_ids: Array = cortical_areas.available_cortical_areas.keys()
	for existing_id in existing_ids:
		if not area_summary_data.has(existing_id):
			cortical_areas.remove_cortical_area(existing_id)
	
	for cortical_area_ID in area_summary_data.keys():
		var area_JSON_summary: Dictionary = area_summary_data[cortical_area_ID]
		if cortical_area_ID in cortical_areas.available_cortical_areas:
			cortical_areas.FEAGI_update_cortical_area_from_dict(area_JSON_summary)
		else:
			var parent_region = _resolve_parent_region_for_area(area_JSON_summary, cortical_area_ID, area_ID_to_region_ID_mapping)
			if parent_region == null:
				push_error("CORE CACHE: Unable to resolve parent region for new cortical area %s" % cortical_area_ID)
				continue
			cortical_areas.FEAGI_add_cortical_area_from_dict(area_JSON_summary, parent_region, cortical_area_ID)
	cortical_areas.suppress_update_notifications = previous_suppress_state

## Resolve parent region for a cortical area using API data or fallback mapping
func _resolve_parent_region_for_area(area_JSON_summary: Dictionary, cortical_area_ID: StringName, area_ID_to_region_ID_mapping: Dictionary) -> BrainRegion:
	var parent_region_id: StringName = ""
	if "parent_region_id" in area_JSON_summary and area_JSON_summary["parent_region_id"] != null:
		parent_region_id = area_JSON_summary["parent_region_id"]
	elif cortical_area_ID in area_ID_to_region_ID_mapping:
		parent_region_id = area_ID_to_region_ID_mapping[cortical_area_ID]
	else:
		var root_region = brain_regions.get_root_region()
		if root_region == null:
			return null
		parent_region_id = root_region.region_ID
	
	if not brain_regions.available_brain_regions.has(parent_region_id):
		return null
	return brain_regions.available_brain_regions[parent_region_id]

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
		_cache_info("FEAGI CACHE: Added synthetic I/O designations - Region: %s, New Inputs: %d, New Outputs: %d" % [region.region_ID, new_input_areas.size(), new_output_areas.size()])
	else:
		# Suppressed (default) to reduce log spam for no-op refreshes.
		_cache_info("FEAGI CACHE: No new I/O designations needed - Region: %s already has adequate mappings" % region.region_ID)

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

## Rebuild partial mappings from region summary data (clears existing mappings first).
func _refresh_partial_mappings_from_summary(region_summary_data: Dictionary) -> void:
	var region_count: int = 0
	var input_count: int = 0
	var output_count: int = 0
	for region_id in region_summary_data.keys():
		if not brain_regions.available_brain_regions.has(region_id):
			continue
		region_count += 1
		var region: BrainRegion = brain_regions.available_brain_regions[region_id]
		_clear_region_partial_mappings(region)
		var region_dict: Dictionary = region_summary_data[region_id]
		if region_dict.has("inputs"):
			var inputs: Array = []
			inputs.assign(region_dict["inputs"])
			input_count += inputs.size()
			region.FEAGI_establish_partial_mappings_from_JSONs(inputs, true)
		if region_dict.has("outputs"):
			var outputs: Array = []
			outputs.assign(region_dict["outputs"])
			output_count += outputs.size()
			region.FEAGI_establish_partial_mappings_from_JSONs(outputs, false)
	print("FEAGI CACHE: Partial mappings refreshed (regions=%d, inputs=%d, outputs=%d)" % [region_count, input_count, output_count])

## Emit region_added for any regions that were introduced during refresh.
func _emit_new_region_added_signals(previous_region_ids: Array) -> void:
	for region_id in brain_regions.available_brain_regions.keys():
		if region_id in previous_region_ids:
			continue
		var region: BrainRegion = brain_regions.available_brain_regions[region_id]
		brain_regions.emit_region_added_signal(region)

## Connects to signals from all existing brain regions (called during genome load)
func _connect_to_existing_brain_region_signals() -> void:
	_cache_info("FEAGI CACHE: Connecting to signals from %d existing brain regions" % brain_regions.available_brain_regions.size())
	
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
