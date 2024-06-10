extends RefCounted
class_name ConnectionChain
## Stores information about the path connections / connection hints take through regions

signal associated_mapping_set_updated(self_ref: ConnectionChain)
signal about_to_be_deleted(self_ref: ConnectionChain)

var source: GenomeObject:
	get: return _source
var destination: GenomeObject:
	get: return _destination
var chain_links: Array[ConnectionChainLink]:
	get: return _chain_links
var total_chain_path: Array:
	get: return _total_chain_path
var is_both_ends_cortical_areas: bool: ## If this happens, this is an established connectome mapping
	get: return _is_both_ends_cortical_areas
var mapping_set: InterCorticalMappingSet:
	get: return _mapping_set
var partial_mapping_set: PartialMappingSet:
	get: return _partial_mapping_set

var _source: GenomeObject = null
var _destination: GenomeObject = null
var _chain_links: Array[ConnectionChainLink] = []
var _total_chain_path: Array[GenomeObject]
var _is_both_ends_cortical_areas: bool
var _mapping_set: InterCorticalMappingSet
var _partial_mapping_set: PartialMappingSet

## Creates a connection chain from a established mapping between 2 cortical areas
static func from_established_FEAGI_mapping(mapping: InterCorticalMappingSet) -> ConnectionChain:
	var chain: ConnectionChain = ConnectionChain.new(mapping.source_cortical_area, mapping.destination_cortical_area)
	chain.FEAGI_set_mapping(mapping)
	return chain

## Creates a connection chain from a a mapping suggestion (incomplete mapping / hint)
static func from_mapping_suggestion(suggestion: PartialMappingSet) -> ConnectionChain:
	var chain: ConnectionChain = ConnectionChain.new(suggestion.source, suggestion.destination)
	chain.FEAGI_set_partial_mapping(suggestion)
	return chain

func _init(starting_point: GenomeObject, stoppping_point: GenomeObject):
	_source = starting_point
	_destination = stoppping_point
	_is_both_ends_cortical_areas = (starting_point is AbstractCorticalArea) and (stoppping_point is AbstractCorticalArea)
	_total_chain_path = FeagiCore.feagi_local_cache.brain_regions.get_total_path_between_objects(starting_point, stoppping_point)
	_rebuild_connection_chain_links(_total_chain_path)
	if _is_both_ends_cortical_areas:
		if starting_point.genome_ID == stoppping_point.genome_ID:
			(starting_point as AbstractCorticalArea).CACHE_connection_chain_register_an_recursive(self)
			return
		(stoppping_point as AbstractCorticalArea).CACHE_connection_chain_register_an_afferent(self)
		(starting_point as AbstractCorticalArea).CACHE_connection_chain_register_an_efferent(self)
	

func FEAGI_set_mapping(mapping: InterCorticalMappingSet) -> void:
	_mapping_set = mapping
	FEAGI_updated_associated_mapping_set()

func FEAGI_set_partial_mapping(partial_mapping: PartialMappingSet) -> void:
	_partial_mapping_set = partial_mapping

func FEAGI_prepare_to_delete() -> void:
	for chain_link in _chain_links:
		chain_link.FEAGI_prepare_to_delete()
	about_to_be_deleted.emit(self)
	_chain_links = []

## Called by [InterCorticalMappingSet] when it gets updated gets updated
func FEAGI_updated_associated_mapping_set() -> void:
	associated_mapping_set_updated.emit(self)
	for chain_link in _chain_links:
		chain_link.FEAGI_updated_associated_mapping_set()


## Does this chain correspond to an actual mapping?
func is_registered_to_established_mapping_set() -> bool:
	return _mapping_set != null

## Does this chain correspond to a partial mapping set (A 'hint' from an imported region)
func is_registered_to_partial_mapping_set() -> bool:
	return _partial_mapping_set != null

## Wipes any existing series of [ConnectionChainLink]s and builds a new one given the complete chain path
func _rebuild_connection_chain_links(complete_chain_path: Array[GenomeObject]) -> void:
	
	for link in _chain_links:
		link.FEAGI_prepare_to_delete()

	for i in (len(complete_chain_path) - 1):
		var parent_region: BrainRegion
		var link_type: ConnectionChainLink.LINK_TYPE = ConnectionChainLink.determine_link_type(complete_chain_path[i], complete_chain_path[i + 1])
		match(link_type):
			
			ConnectionChainLink.LINK_TYPE.INVALID:
				push_error("FEAGI CORE CACHE: Invalid link with %s towards %s attempted! Skipping!" % [complete_chain_path[i].genome_ID, complete_chain_path[i + 1].genome_ID])
			
			ConnectionChainLink.LINK_TYPE.BRIDGE:
				parent_region = complete_chain_path[i].current_parent_region
			
			ConnectionChainLink.LINK_TYPE.PARENTS_OUTPUT:
				parent_region = complete_chain_path[i].current_parent_region
			
			ConnectionChainLink.LINK_TYPE.PARENTS_INPUT:
				parent_region = complete_chain_path[i + 1].current_parent_region
		
		var connection_chain_link: ConnectionChainLink = ConnectionChainLink.new(parent_region, complete_chain_path[i], complete_chain_path[i + 1], self, link_type)
		_chain_links.append(connection_chain_link)
	
	## If any of these involved objects change parent region, this chain is invalid. We need to know so we can trash the current [ConnectionChainLink] and build new ones
	for involved_object: GenomeObject in complete_chain_path:
		if involved_object.parent_region_updated.is_connected(_involved_object_changed_parent):
			continue
		involved_object.parent_region_updated.connect(_involved_object_changed_parent)

func _involved_object_changed_parent(_irrelevant1, _irrelevant2) -> void:
	_total_chain_path = FeagiCore.feagi_local_cache.brain_regions.get_total_path_between_objects(_source, _destination)
	_rebuild_connection_chain_links(_total_chain_path)

func _mappings_changed(_irrelevant) -> void:
	FEAGI_prepare_to_delete()
