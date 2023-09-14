extends Node
## AUTOLOADED
## This Node simply listens in on manmy common signals and prints them
## This node also immediately deletes itself if not running in a debug build

func _ready():
	if !OS.is_debug_build():
		queue_free()
	
	FeagiCacheEvents.morphology_added.connect(cache_morphology_added)
	FeagiCacheEvents.morphology_removed.connect(cache_morphology_removed)
	FeagiCacheEvents.morphology_updated.connect(cache_morphology_updated)
	FeagiCacheEvents.cortical_area_added.connect(cache_cortical_added)
	FeagiCacheEvents.cortical_area_removed.connect(cache_cortical_removed)
	FeagiCacheEvents.cortical_area_updated.connect(cache_cortical_updated)
	FeagiCacheEvents.cortical_areas_disconnected.connect(cache_connection_disconnected)
	FeagiCacheEvents.cortical_areas_connection_modified.connect(cache_connection_updated)
	FeagiCacheEvents.delay_between_bursts_updated.connect(cache_updated_burst_rate)
	FeagiCacheEvents.available_circuit_listing_updated.connect(cache_available_circuits)
	

func cache_morphology_added(morphology: Morphology) -> void:
	print("CACHE: Added Morphology " + morphology.name)

func cache_morphology_removed(morphology: Morphology) -> void:
	print("CACHE: Removed Morphology " + morphology.name)

func cache_morphology_updated(morphology: Morphology) -> void:
	print("CACHE: Updated Morphology " + morphology.name)

func cache_cortical_added(cortical_area: CorticalArea) -> void:
	print("CACHE: Added Cortical Area " + cortical_area.cortical_ID)

func cache_cortical_removed(cortical_area: CorticalArea) -> void:
	print("CACHE: Removed Cortical Area " + cortical_area.cortical_ID)

func cache_cortical_updated(cortical_area: CorticalArea) -> void:
	print("CACHE: Updated Cortical Area " + cortical_area.cortical_ID)

func cache_connection_disconnected(source_cortical_area: CorticalArea, destination_cortical_area: CorticalArea) -> void:
	print("CACHE: Removed connection from %s to %s" % [source_cortical_area.cortical_ID, destination_cortical_area.cortical_ID])

func cache_connection_updated(source_cortical_area: CorticalArea, destination_cortical_area: CorticalArea, number_of_mappings: int) -> void:
	print("CACHE: Updated connection from %s to %s with %d mappings" % [source_cortical_area.cortical_ID, destination_cortical_area.cortical_ID, number_of_mappings])

func cache_updated_burst_rate(seconds_delay_between_bursts: float) -> void:
	print("CACHE: Set seconds delay between bursts to " + str(seconds_delay_between_bursts))

func cache_available_circuits(available_circuits: PackedStringArray) -> void:
	var as_str: String = ""
	for a in available_circuits:
		as_str = as_str + ", " + a
		print("CACHE: Set available circuits read as " + as_str)
