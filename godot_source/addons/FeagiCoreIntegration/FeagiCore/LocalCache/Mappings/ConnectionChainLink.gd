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
	INVALID, ## Pathing makes no sense. Error state!
	PARENTS_OUTPUT_OPEN, ## Region Output but unconnected
	PARENTS_INPUT_OPEN, ## Region Input but unconnected
}


var parent_region: BrainRegion:
	get: return _parent_region
var source: GenomeObject: ## Can be [BrainRegion] or [AbstractCorticalArea]
	get: return _source
var destination: GenomeObject: ## Can be [BrainRegion] or [AbstractCorticalArea]
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

#TODO this shouldnt be a seperate static function since it can be confusingly misused easliy
## Given 2 objects next to each other in a connection chain, what kind of connection link would be formed?
static func determine_link_type(start: GenomeObject, end: GenomeObject) -> LINK_TYPE:
	if start is BrainRegion and end == null:
		return LINK_TYPE.PARENTS_OUTPUT_OPEN
	if end is BrainRegion and start == null:
		return LINK_TYPE.PARENTS_INPUT_OPEN
	if start == null or end == null:
		return LINK_TYPE.INVALID
	if GenomeObject.are_siblings(start, end):
		return LINK_TYPE.BRIDGE
	if start is AbstractCorticalArea:
		return LINK_TYPE.PARENTS_OUTPUT
	if end is AbstractCorticalArea:
		return LINK_TYPE.PARENTS_INPUT
	if (start as BrainRegion).is_subregion_directly(end as BrainRegion):
		return LINK_TYPE.PARENTS_INPUT
	if (end as BrainRegion).is_subregion_directly(start as BrainRegion):
		return LINK_TYPE.PARENTS_OUTPUT
	return LINK_TYPE.INVALID # This can only happen if the 2 objects are not directly next to each other
	


func _init(region_parent: BrainRegion, coming_from: GenomeObject, going_to: GenomeObject, total_chain: ConnectionChain, link_type_: LINK_TYPE):
	_parent_region = region_parent
	_parent_chain = total_chain
	_source = coming_from
	_destination = going_to
	_link_type = link_type_
	match(_link_type):
		LINK_TYPE.INVALID:
			push_error("FEAGI CORE CACHE: Invalid link with %s towards %s!" % [coming_from.genome_ID, going_to.genome_ID])
			return
			
		LINK_TYPE.BRIDGE:
			coming_from.FEAGI_output_add_link(self)
			going_to.FEAGI_input_add_link(self)
			_parent_region.FEAGI_bridge_add_link(self)
		
		LINK_TYPE.PARENTS_OUTPUT:
			coming_from.FEAGI_output_add_link(self)
			going_to.FEAGI_output_add_link(self)
		
		LINK_TYPE.PARENTS_INPUT:
			coming_from.FEAGI_input_add_link(self)
			going_to.FEAGI_input_add_link(self)

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
			_source.FEAGI_output_remove_link(self)
			_destination.FEAGI_input_remove_link(self)
			_parent_region.FEAGI_bridge_remove_link(self)
		
		LINK_TYPE.PARENTS_OUTPUT:
			_source.FEAGI_output_remove_link(self)
			_destination.FEAGI_output_remove_link(self)

		LINK_TYPE.PARENTS_INPUT:
			_source.FEAGI_input_remove_link(self)
			_destination.FEAGI_input_remove_link(self)

func is_source_cortical_area() -> bool:
	return _source is AbstractCorticalArea

func is_destination_cortical_area() -> bool:
	return _destination is AbstractCorticalArea

func is_source_region() -> bool:
	return _source is BrainRegion

func is_destination_region() -> bool:
	return _destination is BrainRegion

func is_recursive() -> bool:
	return _source == _destination
