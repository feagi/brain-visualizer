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
var is_bridge: bool: # If this chain is a bridge (if it connects to elements internal to the parent together, and not with the parent)
	get: return _is_bridge

var _parent_region: BrainRegion
var _source: Variant = null ## Can be [BrainRegion] or [BaseCorticalArea]
var _destination: Variant = null ## Can be [BrainRegion] or [BaseCorticalArea]
var _parent_chain: ConnectionChain
var _is_bridge: bool
var _is_input_in_source: bool = false
var _is_input_in_destination: bool = false


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
	
	# We need to determine if this chain is a bridge(connecting 2 internal elements of the parent element), and/ or
	# input (connecting the parent region to an internal), or an output ((connecting an internal to the parent region) to each other involved connections

	if coming_from is BaseCorticalArea:
		(coming_from as BaseCorticalArea).output_add_link(self) # NOTE: the input of this chain is the output of the cortical area
		_is_input_in_source = false
		if going_to is BaseCorticalArea:
			# bridge between 2 internal cortical areas, this must be a bridge
			(going_to as BaseCorticalArea).input_add_link(self)
			_is_input_in_destination = true
			_parent_region.bridge_add_link(self)
			_is_bridge = true
			return
		else:
			# going_to is a region
			if (going_to as BrainRegion).ID == _parent_region.ID:
				# We are going to the parent, this isnt a bridge
				(going_to as BrainRegion).output_add_link(self) # if we are going to parent from the inside, then this must be an output in perspective of the region
				_is_input_in_destination = false
				return
			else:
				# We are going to another internal member, this is a bridge
				(going_to as BrainRegion).input_add_link(self) # if we are going to the input of a region, from that regions perspective this is an input
				_is_input_in_destination = true
				_parent_region.bridge_add_link(self)
				_is_bridge = true
				return
	else:
		# coming_from is a region
		if going_to is BaseCorticalArea:
			(going_to as BaseCorticalArea).input_add_link(self)
			_is_input_in_destination = true
			if (coming_from as BrainRegion).ID == _parent_region.ID:
				# Not a bridge, coming_from is the parent
				(coming_from as BrainRegion).input_add_link(self) # If we are coming from a region when we are inside of it, this must be an input to said region
				_is_input_in_source = true
				return
			else:
				# is a bridge
				(coming_from as BrainRegion).output_add_link(self) # If we are coming from a region from an outside perspective, this must be an output of that region
				_is_input_in_source = false
				_parent_region.bridge_add_link(self)
				_is_bridge = true
				return
				
		else:
			# going_to is a region (both are regions)
			if (coming_from as BrainRegion).ID == _parent_region.ID and (going_to as BrainRegion).ID == _parent_region.ID:
				# This can only occur during recursions, which isn't allowed
				push_error("CORE CACHE: Cannot finish init of ConnectionChainLink with the source and destination being the same region!")
				return
			
			if (coming_from as BrainRegion).ID == _parent_region.ID:
				(coming_from as BrainRegion).input_add_link(self) # If we are coming from a region when we are inside of it, this must be an input to said region
				_is_input_in_source = true
				(going_to as BrainRegion).input_add_link(self)
				_is_input_in_destination = true
				return
			
			if (going_to as BrainRegion).ID == _parent_region.ID:
				(coming_from as BrainRegion).output_add_link(self) # If we are going to a region when we are inside of it, this must be an output to said region
				_is_input_in_source = false
				(going_to as BrainRegion).output_add_link(self)
				_is_input_in_destination = false
				return
			
			# This is a bridge, connecting 2 internal regions
			(coming_from as BrainRegion).output_add_link(self)
			_is_input_in_source = false
			(going_to as BrainRegion).input_add_link(self)
			_is_input_in_destination = true
			_parent_region.bridge_add_link(self)
			_is_bridge = true


## Called by [ConnectionChain] when this object is about to be deleted
func prepare_to_delete() -> void:
	# source
	if _source is BaseCorticalArea:
		if _is_input_in_source:
			(_source as BaseCorticalArea).input_remove_link(self)
		else:
			(_source as BaseCorticalArea).output_remove_link(self)
	else:
		if _is_input_in_source:
			(_source as BrainRegion).input_remove_link(self)
		else:
			(_source as BrainRegion).output_remove_link(self)
	
	# destination
	if _destination is BaseCorticalArea:
		if _is_input_in_destination:
			(_destination as BaseCorticalArea).input_remove_link(self)
		else:
			(_destination as BaseCorticalArea).output_remove_link(self)
	else:
		if _is_input_in_destination:
			(_destination as BrainRegion).input_remove_link(self)
		else:
			(_destination as BrainRegion).output_remove_link(self)
	
	# bridge if applicable
	if _is_bridge:
		# can only be parent
		_parent_region.bridge_remove_link(self)

	


