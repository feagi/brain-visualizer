extends RefCounted
class_name ConnectionChain
## Stores information about the path connections / conneciton hints take through regions


var source: Variant: ## Can be [BrainRegion] or [BaseCorticalArea]
	get: return _source
var destination: Variant: ## Can be [BrainRegion] or [BaseCorticalArea]
	get: return _destination
var chain_links: Array[ConnectionChainLink]:
	get: return _chain_links
var total_chain_path: Array:
	get: return _total_chain_path
var is_both_ends_cortical_areas: bool: ## If this happens, this is an established connectome mapping
	get: return _is_both_ends_cortical_areas

var _source: Variant = null ## Can be [BrainRegion] or [BaseCorticalArea]
var _destination: Variant = null ## Can be [BrainRegion] or [BaseCorticalArea]
var _chain_links: Array[ConnectionChainLink] = []
var _total_chain_path: Array
var _is_both_ends_cortical_areas: bool


func _init(starting_point: Variant, stoppping_point: Variant):
	var errored: bool = false
	if !BrainRegion.is_object_able_to_be_within_region(starting_point):
		push_error("CORE CACHE: Cannot create ConnectionChain with source type that isnt BrainRegion or BaseCorticalArea!")
		errored = true
	else:
		_source = starting_point
	if !BrainRegion.is_object_able_to_be_within_region(stoppping_point):
		push_error("CORE CACHE: Cannot create ConnectionChain with destination type that isnt BrainRegion or BaseCorticalArea!")
		errored = true
	else:
		_destination = stoppping_point

	if errored:
		return  ## No point generating anything if our stop / endpoints arent valid
	
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


