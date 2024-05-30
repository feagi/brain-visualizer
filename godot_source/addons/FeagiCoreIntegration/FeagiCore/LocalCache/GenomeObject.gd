extends RefCounted
class_name GenomeObject
## Any singular object that exists in the genome (essentially any object that can be within a region) that can be linked and exist in a [BrainRegion]

signal parent_region_changed(old_region: BrainRegion, new_region: BrainRegion)
signal input_link_added(link: ConnectionChainLink)
signal output_link_added(link: ConnectionChainLink)
signal input_link_removed(link: ConnectionChainLink)
signal output_link_removed(link: ConnectionChainLink)

enum ARRAY_MAKEUP {
	SINGLE_CORTICAL_AREA,
	SINGLE_BRAIN_REGION,
	MULTIPLE_CORTICAL_AREAS,
	MULTIPLE_BRAIN_REGIONS,
	VARIOUS_GENOME_OBJECTS,
	UNKNOWN
}

## What reigon is this object under?
var current_parent_region: BrainRegion:
	get: return _current_parent_region

## What [ConnectionChainLink]s are going into this object?
var input_chain_links: Array[ConnectionChainLink]:
	get: return _input_chain_links

## What [ConnectionChainLink] are leaving this object
var output_chain_links: Array[ConnectionChainLink]:
	get: return _output_chain_links

var _current_parent_region: BrainRegion
var _input_chain_links: Array[ConnectionChainLink]
var _output_chain_links: Array[ConnectionChainLink]


static func are_siblings(A: GenomeObject, B: GenomeObject) -> bool:
	var par_A: BrainRegion = A.current_parent_region
	var par_B: BrainRegion = B.current_parent_region
	
	if (par_A == null) or (par_B == null):
		return false
	return par_A.ID == par_B.ID

static func get_makeup_of_array(genome_objects: Array[GenomeObject]) -> ARRAY_MAKEUP:
	if len(genome_objects) == 0:
		return ARRAY_MAKEUP.UNKNOWN
	if len(genome_objects) == 1:
		if genome_objects[0] is BaseCorticalArea:
			return ARRAY_MAKEUP.SINGLE_CORTICAL_AREA
		if genome_objects[0] is BrainRegion:
			return ARRAY_MAKEUP.SINGLE_BRAIN_REGION
		return ARRAY_MAKEUP.UNKNOWN
	var br: bool
	var ca: bool
	for selection in genome_objects:
		if selection is BaseCorticalArea:
			ca = true
			continue
		if selection is BrainRegion:
			br = true
			continue
		return ARRAY_MAKEUP.UNKNOWN
		
	if br and ca:
		return ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS
	if br:
		return ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS
	return ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS

static func get_ID_array(genome_objects: Array[GenomeObject]) -> Array[StringName]:
	var output: Array[StringName] = []
	for object in genome_objects:
		output.append(object.get_ID())
	return output

static func filter_cortical_areas(genome_objects: Array[GenomeObject]) -> Array[BaseCorticalArea]:
	var output: Array[BaseCorticalArea] = []
	for object in genome_objects:
		if object is BaseCorticalArea:
			output.append(object as BaseCorticalArea)
	return output

static func filter_brain_regions(genome_objects: Array[GenomeObject]) -> Array[BrainRegion]:
	var output: Array[BrainRegion] = []
	for object in genome_objects:
		if object is BrainRegion:
			output.append(object as BrainRegion)
	return output

## Change form one existing parent region to another
func change_parent_brain_region(new_parent_region: BrainRegion) -> void:
	var old_region_cache: BrainRegion = _current_parent_region # yes this method uses more memory but avoids potential shenanigans
	_current_parent_region = new_parent_region
	old_region_cache.FEAGI_genome_object_deregister_as_child(self)
	new_parent_region.FEAGI_genome_object_register_as_child(self)
	parent_region_changed.emit(old_region_cache, new_parent_region)

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region. 
func input_add_link(link: ConnectionChainLink) -> void:
	if link in _input_chain_links:
		push_error("CORE CACHE: Unable to add input link to object %s when it already exists!" % get_ID())
		return
	_input_chain_links.append(link)
	input_link_added.emit(link)

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region
func output_add_link(link: ConnectionChainLink) -> void:
	if link in _output_chain_links:
		push_error("CORE CACHE: Unable to add output link to object %s when it already exists!" % get_ID())
		return
	_output_chain_links.append(link)
	output_link_added.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func input_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _input_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from object %s as it wasn't found!" % get_ID())
		return
	_input_chain_links.remove_at(index)
	input_link_removed.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func output_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _output_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from object %s as it wasn't found!" % get_ID())
		return
	_output_chain_links.remove_at(index)
	output_link_removed.emit(link)

func get_name() -> StringName:
	if self is BrainRegion:
		return (self as BrainRegion).name
	if self is BaseCorticalArea:
		return (self as BaseCorticalArea).name
	return "UNKNOWN"

func get_ID() -> StringName:
	if self is BrainRegion:
		return (self as BrainRegion).ID
	if self is BaseCorticalArea:
		return (self as BaseCorticalArea).cortical_ID
	return "UNKNOWN"

## For initialization of an object to a [BrainRegion]. Not for CHANGING regions!
func _init_self_to_brain_region(parent_region: BrainRegion) -> void:
	_current_parent_region = parent_region
	parent_region.FEAGI_genome_object_register_as_child(self)
