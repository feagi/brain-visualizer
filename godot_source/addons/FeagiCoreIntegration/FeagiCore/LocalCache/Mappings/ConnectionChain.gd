extends RefCounted
class_name ConnectionChain
## Stores information about the path connections / conneciton hints take through regions

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

var _source: GenomeObject = null
var _destination: GenomeObject = null
var _chain_links: Array[ConnectionChainLink] = []
var _total_chain_path: Array
var _is_both_ends_cortical_areas: bool


func _init(starting_point: GenomeObject, stoppping_point: GenomeObject):
	_source = starting_point
	_destination = stoppping_point

	
	_is_both_ends_cortical_areas = (starting_point is BaseCorticalArea) and (stoppping_point is BaseCorticalArea)
	
	_total_chain_path = FeagiCore.feagi_local_cache.brain_regions.get_total_path_between_objects(starting_point, stoppping_point)
	
	for i in (len(total_chain_path) - 1):
		## If either side is a cortical area, then the parent region is the parent region of the cortical area. If both are regions, then the parent is the parent of either region
		var parent_region: BrainRegion
		if total_chain_path[i] is BaseCorticalArea:
			parent_region = (total_chain_path[i] as BaseCorticalArea).current_region
		elif total_chain_path[i + 1] is BaseCorticalArea:
			parent_region = (total_chain_path[i + 1] as BaseCorticalArea).current_region
		else:
			parent_region = (total_chain_path[i] as BrainRegion).parent_region
		
		_chain_links.append(ConnectionChainLink.new(parent_region, total_chain_path[i], total_chain_path[i + 1], self))

func prepare_to_delete() -> void:
	for chain_link in _chain_links:
		chain_link.prepare_to_delete()
	about_to_be_deleted.emit()
	_chain_links = []
