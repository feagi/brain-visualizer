extends RefCounted
class_name ConnectionChainLink
## Stores a single connection between 2 elements directly within a region
## NOTE: Is read only following creation

var parent_region: BrainRegion:
	get: return _parent_region
var source: Variant: ## Can be [BrainRegion] or [BaseCorticalArea]
	get: return _source
var destination: Variant: ## Can be [BrainRegion] or [BaseCorticalArea]
	get: return _destination
var parent_chain: ConnectionChain:
	get: return _parent_chain

var _parent_region: BrainRegion
var _source: Variant = null ## Can be [BrainRegion] or [BaseCorticalArea]
var _destination: Variant = null ## Can be [BrainRegion] or [BaseCorticalArea]
var _parent_chain: ConnectionChain

func _init(region_parent: BrainRegion, coming_from: Variant, going_to: Variant, total_chain: ConnectionChain):
	var errored: bool = false
	_parent_region = region_parent
	_parent_chain = total_chain
	if !BrainRegion.is_object_able_to_be_within_region(coming_from):
		push_error("CORE CACHE: Cannot create ConnectionChainLink with source type that isnt BrainRegion or BaseCorticalArea!")
		errored = true
	else:
		_source = coming_from
	if !BrainRegion.is_object_able_to_be_within_region(going_to):
		push_error("CORE CACHE: Cannot create ConnectionChainLink with destination type that isnt BrainRegion or BaseCorticalArea!")
		errored = true
	else:
		_destination = going_to
	
	if errored:
		return # Don't bother signaling if we have null endpoints!
	
	#TODO alert parent brainRegion of creation and insert self reference

## Called by [ConnectionChain] when this object is about to be deleted
func prepare_to_delete() -> void:
	#TODO alert brainRegion of deletion and remove self reference
	pass
	


