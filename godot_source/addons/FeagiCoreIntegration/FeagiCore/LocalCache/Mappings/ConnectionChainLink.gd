extends RefCounted
class_name ConnectionChainLink
## Stores a single connection between 2 elements directly within a region
## NOTE: Is read only following creation

signal associated_mapping_set_updated()
signal about_to_be_removed()

enum LINK_TYPE {
	BRIDGE, ## The chain link connects 2 internal members of a region
	PARENTS_OUTPUT, ## The Chain link connects an internal member of a region toward that regions output
	PARENTS_INPUT, ## The Chain link connects the regions input toward an internal member of that region
	INVALID ## Pathing makes no sense. Error state!
}


var parent_region: BrainRegion:
	get: return _parent_region
var source: GenomeObject: ## Can be [BrainRegion] or [BaseCorticalArea]
	get: return _source
var destination: GenomeObject: ## Can be [BrainRegion] or [BaseCorticalArea]
	get: return _destination
var parent_chain: ConnectionChain:
	get: return _parent_chain
var link_type: LINK_TYPE:
	get: return _link_type

var _parent_region: BrainRegion
var _source: GenomeObject = null
var _destination: GenomeObject = null
var _parent_chain: ConnectionChain
var _link_type: LINK_TYPE

## Given 2 objects, what kind of connection link would be formed?
static func determine_link_type(start: GenomeObject, end: GenomeObject) -> LINK_TYPE:
	if start is BaseCorticalArea:
		if end is BaseCorticalArea:
			return LINK_TYPE.BRIDGE
		return LINK_TYPE.PARENTS_OUTPUT
	if end is BaseCorticalArea:
		return LINK_TYPE.PARENTS_INPUT
	# Both are regions
	if (start as BrainRegion).parent_region.ID == (end as BrainRegion).parent_region.ID:
		return LINK_TYPE.BRIDGE # If the start and end have the same parent, then they must be siblings within it
	if (start as BrainRegion).ID == (end as BrainRegion).parent_region.ID:
		return LINK_TYPE.PARENTS_INPUT
	if (start as BrainRegion).parent_region.ID == (end as BrainRegion).ID:
		return LINK_TYPE.PARENTS_OUTPUT # If the start and end have the same parent, then they must be siblings within it
	return LINK_TYPE.INVALID # This can only happen if the 2 objects are not directly next to each other
	


func _init(region_parent: BrainRegion, coming_from: GenomeObject, going_to: GenomeObject, total_chain: ConnectionChain, link_type_: LINK_TYPE):
	_parent_region = region_parent
	_parent_chain = total_chain
	_source = coming_from
	_destination = going_to
	_link_type = link_type_
	
	match(_link_type):
		LINK_TYPE.INVALID:
			var ID1: StringName
			if coming_from is BaseCorticalArea:
				ID1 = coming_from.cortical_ID
			else:
				ID1 = (coming_from as BrainRegion).ID
			var ID2: StringName
			if going_to is BaseCorticalArea:
				ID2 = going_to.cortical_ID
			else:
				ID2 = (going_to as BrainRegion).ID
			push_error("FEAGI CORE CACHE: Invalid link with %s towards %s!" % [ID1, ID2])
			return
			
		LINK_TYPE.BRIDGE:
			if coming_from is BaseCorticalArea:
				(coming_from as BaseCorticalArea).output_add_link(self)
			else:
				(coming_from as BrainRegion).output_add_link(self)
			if going_to is BaseCorticalArea:
				(going_to as BaseCorticalArea).input_add_link(self)
			else:
				(going_to as BrainRegion).input_add_link(self)
			_parent_region.bridge_add_link(self)
		
		LINK_TYPE.PARENTS_OUTPUT:
			if coming_from is BaseCorticalArea:
				(coming_from as BaseCorticalArea).output_add_link(self)
			else:
				(coming_from as BrainRegion).output_add_link(self)
			if going_to is BaseCorticalArea:
				(going_to as BaseCorticalArea).output_add_link(self)
			else:
				(going_to as BrainRegion).output_add_link(self)
		
		LINK_TYPE.PARENTS_INPUT:
			if coming_from is BaseCorticalArea:
				(coming_from as BaseCorticalArea).input_add_link(self)
			else:
				(coming_from as BrainRegion).input_add_link(self)
			if going_to is BaseCorticalArea:
				(going_to as BaseCorticalArea).input_add_link(self)
			else:
				(going_to as BrainRegion).input_add_link(self)

## Called from [ConnectionChain] when the associated mapping set gets updated
func FEAGI_updated_associated_mapping_set() -> void:
	associated_mapping_set_updated.emit()


## Called by [ConnectionChain] when this object is about to be deleted
func FEAGI_prepare_to_delete() -> void:
	about_to_be_removed.emit()
	match(_link_type):
		LINK_TYPE.INVALID:
			# We didnt register with anything, nothing to remove
			pass
			
		LINK_TYPE.BRIDGE:
			if _source is BaseCorticalArea:
				(_source as BaseCorticalArea).output_remove_link(self)
			else:
				(_source as BrainRegion).output_remove_link(self)
			if _destination is BaseCorticalArea:
				(_destination as BaseCorticalArea).input_remove_link(self)
			else:
				(_destination as BrainRegion).input_remove_link(self)
			_parent_region.bridge_remove_link(self)
		
		LINK_TYPE.PARENTS_OUTPUT:
			if _source is BaseCorticalArea:
				(_source as BaseCorticalArea).output_remove_link(self)
			else:
				(_source as BrainRegion).output_remove_link(self)
			if _destination is BaseCorticalArea:
				(_destination as BaseCorticalArea).output_remove_link(self)
			else:
				(_destination as BrainRegion).output_remove_link(self)

		LINK_TYPE.PARENTS_INPUT:
			if _source is BaseCorticalArea:
				(_source as BaseCorticalArea).input_remove_link(self)
			else:
				(_source as BrainRegion).input_remove_link(self)
			if _destination is BaseCorticalArea:
				(_destination as BaseCorticalArea).input_remove_link(self)
			else:
				(_destination as BrainRegion).input_remove_link(self)

func is_source_cortical_area() -> bool:
	return _source is BaseCorticalArea

func is_destination_cortical_area() -> bool:
	return _destination is BaseCorticalArea

func is_source_region() -> bool:
	return _source is BrainRegion

func is_destination_region() -> bool:
	return _destination is BrainRegion


