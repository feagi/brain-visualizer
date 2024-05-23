extends RefCounted
class_name ConnectionChain
## Stores information about the path connections / connection hints take through regions

signal about_to_be_deleted()

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
var _total_chain_path: Array
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
	_is_both_ends_cortical_areas = (starting_point is BaseCorticalArea) and (stoppping_point is BaseCorticalArea)
	_total_chain_path = FeagiCore.feagi_local_cache.brain_regions.get_total_path_between_objects(starting_point, stoppping_point)
	
	for i in (len(_total_chain_path) - 1):
		## If either side is a cortical area, then the parent region is the parent region of the cortical area. If both are regions, then the parent is the parent of either region
		var parent_region: BrainRegion
		var link_type: ConnectionChainLink.LINK_TYPE = ConnectionChainLink.determine_link_type(_source, _destination)
		match(link_type):
			
			ConnectionChainLink.LINK_TYPE.INVALID:
				var ID1: StringName
				if _source is BaseCorticalArea:
					ID1 = _source.cortical_ID
				else:
					ID1 = (_source as BrainRegion).ID
				var ID2: StringName
				if _destination is BaseCorticalArea:
					ID2 = _destination.cortical_ID
				else:
					ID2 = (_destination as BrainRegion).ID
				push_error("FEAGI CORE CACHE: Invalid link with %s towards %s attempted! Skipping!" % [ID1, ID2])
			
			ConnectionChainLink.LINK_TYPE.BRIDGE:
				if _source is BaseCorticalArea:
					parent_region = _source.current_region
				else:
					parent_region = (_source as BrainRegion).parent_region
			
			ConnectionChainLink.LINK_TYPE.PARENTS_OUTPUT:
				if _source is BaseCorticalArea:
					parent_region = _source.current_region
				else:
					parent_region = (_source as BrainRegion).parent_region
			
			ConnectionChainLink.LINK_TYPE.PARENTS_INPUT:
				if _destination is BaseCorticalArea:
					parent_region = _destination.current_region
				else:
					parent_region = (_destination as BrainRegion).parent_region
		
		_chain_links.append(ConnectionChainLink.new(parent_region, total_chain_path[i], total_chain_path[i + 1], self, link_type))

func FEAGI_set_mapping(mapping: InterCorticalMappingSet) -> void:
	_mapping_set = mapping

func FEAGI_set_partial_mapping(partial_mapping: PartialMappingSet) -> void:
	_partial_mapping_set = partial_mapping

func FEAGI_prepare_to_delete() -> void:
	for chain_link in _chain_links:
		chain_link.prepare_to_delete()
	about_to_be_deleted.emit()
	_chain_links = []

