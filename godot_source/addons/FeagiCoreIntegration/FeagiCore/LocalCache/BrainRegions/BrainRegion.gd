extends GenomeObject
class_name BrainRegion
## Defines an area enclosing various [AbstractCorticalArea]s

const ROOT_REGION_ID: StringName = "root" ## This is the ID that is unique to the root region

signal name_updated(new_name: StringName)
signal cortical_area_added_to_region(area: AbstractCorticalArea)
signal cortical_area_removed_from_region(area: AbstractCorticalArea)
signal subregion_added_to_region(subregion: BrainRegion)
signal subregion_removed_from_region(subregion: BrainRegion)
signal bridge_link_added(link: ConnectionChainLink)
signal bridge_link_removed(link: ConnectionChainLink)
signal input_open_link_added(link: ConnectionChainLink)
signal input_open_link_removed(link: ConnectionChainLink)
signal output_open_link_added(link: ConnectionChainLink)
signal output_open_link_removed(link: ConnectionChainLink)
signal partial_mappings_inputted(mappings: PartialMappingSet)
signal partial_mappings_about_to_be_removed(mappings: PartialMappingSet)


var region_ID: StringName:
	get: return _genome_ID
var contained_cortical_areas: Array[AbstractCorticalArea]:
	get: return _contained_cortical_areas
var contained_regions: Array[BrainRegion]:
	get: return _contained_regions
var bridge_chain_links: Array[ConnectionChainLink]: ## Bridge links connect 2 internal members together, they do not connect to the input / output of the region
	get: return _bridge_chain_links
var input_open_chain_links: Array[ConnectionChainLink]: 
	get: return _input_open_chain_links
var output_open_chain_links: Array[ConnectionChainLink]:
	get: return _output_open_chain_links
var partial_mappings: Array[PartialMappingSet]:
	get: return _partial_mappings

var _contained_cortical_areas: Array[AbstractCorticalArea]
var _contained_regions: Array[BrainRegion]
var _bridge_chain_links: Array[ConnectionChainLink]
var _input_open_chain_links: Array[ConnectionChainLink]
var _output_open_chain_links: Array[ConnectionChainLink]
var _partial_mappings: Array[PartialMappingSet] = []

## Spawns a [BrainRegion] from the JSON details from FEAGI, but doesn't add any children regions or areas
static func from_FEAGI_JSON_ignore_children(dict: Dictionary, ID: StringName) -> BrainRegion:
	return BrainRegion.new(
		ID,
		dict["title"],
		FEAGIUtils.array_to_vector2i(dict["coordinate_2d"]),
		#FEAGIUtils.array_to_vector3i(dict["coordinate_3d"]),
		Vector3i(10,10,10), #TODO
	)
	

## Gets the parent region of the object (if it is capable of having one)
static func get_parent_region_of_object(A: GenomeObject) -> BrainRegion:
	if A is AbstractCorticalArea:
		return (A as AbstractCorticalArea).current_region
	if A is BrainRegion:
		if (A as BrainRegion).is_root_region():
			push_error("CORE CACHE: Unable to get parent region of the root region!")
			return null
		return (A as BrainRegion).parent_region
	push_error("CORE CACHE: Unable to get parent region of an object of unknown type!")
	return null

static func object_array_to_ID_array(regions: Array[BrainRegion]) -> Array[StringName]:
	var output: Array[StringName] = []
	for region in regions:
		output.append(region.region_ID)
	return output

#NOTE: Specifically not initing region connections since we need to set up all objects FIRST
func _init(region_ID: StringName, region_name: StringName, coord_2D: Vector2i, coord_3D: Vector3i):
	_genome_ID = region_ID
	_friendly_name = region_name
	_coordinates_3D = coord_3D
	_coordinates_2D = coord_2D
	#TODO Size should be calculated in FEAGI

## Updates from FEAGI updating this cache object
#region FEAGI Interactions

## Only called by FEAGI during Genome loading, inits the parent region of this region
func FEAGI_init_parent_relation(parent_region: BrainRegion) -> void:
	if is_root_region():
		push_error("CORE CACHE: Root region cannot be a subregion!")
		return
	_init_self_to_brain_region(parent_region)

## When an [GenomeObject] gets a parent region set / changed, it calls this function of the new parent instance to register itself
func FEAGI_genome_object_register_as_child(genome_object: GenomeObject) -> void:
	if genome_object is AbstractCorticalArea:
		var cortical_area: AbstractCorticalArea = (genome_object as AbstractCorticalArea)
		if cortical_area in _contained_cortical_areas:
			push_error("CORE CACHE: Cannot add cortical area %s to region %s that already contains it! Skipping!" % [cortical_area.cortical_ID, _genome_ID])
			return
		_contained_cortical_areas.append(cortical_area)
		cortical_area_added_to_region.emit(cortical_area)
		return
	if genome_object is BrainRegion:
		var region: BrainRegion = (genome_object as BrainRegion)
		if region.is_root_region():
			push_error("CORE CACHE: Unable to add root region as a subregion!")
			return
		if region in _contained_regions:
			push_error("CORE CACHE: Cannot add region %s to region %s that already contains it! Skipping!" % [region.region_ID, _genome_ID])
			return
		_contained_regions.append(region)
		subregion_added_to_region.emit(region)
		return
	push_error("CORE CACHE: Unknown GenomeObject type tried to be added to region %s!" % _genome_ID)

## When an [GenomeObject] gets a parent region set / changed, it calls this function of the old parent instance to deregister itself
func FEAGI_genome_object_deregister_as_child(genome_object: GenomeObject) -> void:
	if genome_object is AbstractCorticalArea:
		var cortical_area: AbstractCorticalArea = (genome_object as AbstractCorticalArea)
		var index: int = _contained_cortical_areas.find(cortical_area)
		if index == -1:
			push_error("CORE CACHE: Cannot remove cortical area %s from region %s that doesn't contains it! Skipping!" % [cortical_area.cortical_ID, _genome_ID])
			return
		_contained_cortical_areas.remove_at(index)
		cortical_area_removed_from_region.emit(cortical_area)
		return
	if genome_object is BrainRegion:
		var region: BrainRegion = (genome_object as BrainRegion)
		var index: int = _contained_regions.find(region)
		if index == -1:
			push_error("CORE CACHE: Cannot remove region %s from region %s that doesn't contains it! Skipping!" % [region.region_ID, _genome_ID])
			return
		_contained_regions.remove_at(index)
		subregion_removed_from_region.emit(region)
		return
	push_error("CORE CACHE: Unknown GenomeObject type tried to be removed from region %s!" % _genome_ID)

## Called from FEAGI when we update properties of the brain region. Called by [BrainRegionCache]
func FEAGI_edited_region(title: StringName, _description: StringName, new_parent_region: BrainRegion, position_2D: Vector2i, position_3D: Vector3i) -> void:
	FEAGI_change_friendly_name(title)
	#TODO description?
	FEAGI_change_coordinates_2D(position_2D)
	FEAGI_change_coordinates_3D(position_3D)
	FEAGI_change_parent_brain_region(new_parent_region)


## FEAGI confirmed this region is deleted. Called by [BrainRegionCache]
func FEAGI_delete_this_region() -> void:
	if len(_contained_regions) != 0:
		push_error("CORE CACHE: Cannot remove region %s as it still contains regions! Skipping!" % [_genome_ID])
	if len(_contained_cortical_areas) != 0:
		push_error("CORE CACHE: Cannot remove region %s as it still contains cortical areas! Skipping!" % [_genome_ID])
	if is_root_region():
		push_error("CORE CACHE: Cannot remove root region region! Skipping!")
	about_to_be_deleted.emit()
	current_parent_region.FEAGI_genome_object_deregister_as_child(self)
	# This function should be called by [BrainRegionsCache], which will then free this object

func FEAGI_establish_partial_mappings_from_JSONs(JSON_arr: Array[Dictionary], is_input: bool) -> void:
	if len(JSON_arr) == 0:
		return # No point if the arr is empty
	var new_mappings: Array[PartialMappingSet] = PartialMappingSet.from_FEAGI_JSON_array(JSON_arr, is_input, self)
	_partial_mappings.append_array(new_mappings)
	for mapping in new_mappings:
		partial_mappings_inputted.emit(mapping)
		mapping.mappings_about_to_be_deleted.connect(_FEAGI_partical_mapping_removed)

func _FEAGI_partical_mapping_removed(mapping: PartialMappingSet) -> void:
	var index: int = _partial_mappings.find(mapping)
	if index == -1:
		push_error("CORE CACHE: Unable to find PartialMappingSet to remove!")
		return
	partial_mappings_about_to_be_removed.emit(mapping)
	_partial_mappings.remove_at(index)

#endregion


## [ConnectionChain] Interactions, as the result of mapping updates or hint updates
#region ConnectionChainLink changes


## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region
func FEAGI_bridge_add_link(link: ConnectionChainLink) -> void:
	if link in _bridge_chain_links:
		push_error("CORE CACHE: Unable to add bridge link to region %s when it already exists!" % _genome_ID)
		return
	_bridge_chain_links.append(link)
	bridge_link_added.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func FEAGI_bridge_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _bridge_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from region %s as it wasn't found!" % _genome_ID)
		return
	_bridge_chain_links.remove_at(index)
	bridge_link_removed.emit(link)

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region
func FEAGI_input_open_add_link(link: ConnectionChainLink) -> void:
	if link in _input_open_chain_links:
		push_error("CORE CACHE: Unable to add bridge link to region %s when it already exists!" % _genome_ID)
		return
	_input_open_chain_links.append(link)
	input_open_link_added.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func FEAGI_input_open_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _input_open_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from region %s as it wasn't found!" % _genome_ID)
		return
	_input_open_chain_links.remove_at(index)
	input_open_link_removed.emit(link)

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region
func FEAGI_output_open_add_link(link: ConnectionChainLink) -> void:
	if link in _output_open_chain_links:
		push_error("CORE CACHE: Unable to add bridge link to region %s when it already exists!" % _genome_ID)
		return
	_output_open_chain_links.append(link)
	output_open_link_added.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func FEAGI_output_open_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _output_open_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from region %s as it wasn't found!" % _genome_ID)
		return
	_output_open_chain_links.remove_at(index)
	output_open_link_removed.emit(link)

#endregion


## Queries that can be made from the UI layer to ascern specific properties
#region Queries

## Returns if this region is the root region or not
func is_root_region() -> bool:
	return _genome_ID == ROOT_REGION_ID

## Returns if a cortical area is a cortical area within this region (not nested in another region)
func is_cortical_area_in_region_directly(cortical_area: AbstractCorticalArea) -> bool:
	return cortical_area in _contained_cortical_areas

func is_subregion_directly(region: BrainRegion) -> bool:
	return region in _contained_regions

func is_genome_object_in_region_directly(object: GenomeObject) -> bool:
	if object is AbstractCorticalArea:
		return is_cortical_area_in_region_directly(object as AbstractCorticalArea)
	if object is BrainRegion:
		return is_subregion_directly(object as BrainRegion)
	return false

## Returns if a cortical area is within this region (including within another region inside here)
func is_cortical_area_in_region_recursive(cortical_area: AbstractCorticalArea) -> bool:
	if cortical_area in _contained_cortical_areas:
		return true
	for region: BrainRegion in _contained_regions:
		if region.is_cortical_area_in_region_recursive(cortical_area):
			return true
	return false

func is_subregion_recursive(region: BrainRegion) -> bool:
	for search_region in _contained_regions:
		if search_region == region:
			return true
		if search_region.is_subregion_recursive(region):
			return true
	return false

## Returns the path of this region, starting with the root region and ending with this region
func get_path() -> Array[BrainRegion]:
	var searching_region: BrainRegion = self
	var path: Array[BrainRegion] = []
	while !searching_region.is_root_region():
		path.append(searching_region)
		searching_region = searching_region.current_parent_region
	path.append(searching_region)
	path.reverse()
	return path

func is_safe_to_add_child_region(possible_child: BrainRegion) -> bool:
	return !(possible_child in get_path())

## Returns an array of all directly contained GenomeObjects (non-recursive)
func get_all_included_genome_objects() -> Array[GenomeObject]:
	var contained_objects: Array[GenomeObject] = []
	for area in _contained_cortical_areas:
		contained_objects.append(area)
	for region in _contained_regions:
		contained_objects.append(region)
	return contained_objects

## Returns an vec2i of the number of objects inside this region, where the first number is the total  number of regions and the second the number of cortical areas
func get_number_of_internals_recursive() -> Vector2i:
	var current: Vector2i = Vector2i(0,0)
	for region in _contained_regions:
		current.x += 1
		current += region.get_number_of_internals_recursive()
	current.y = len(_contained_cortical_areas)
	return current

func has_partial_mappings() -> bool:
	return len(_partial_mappings) > 0

## Returns the PartialMappingSet that involved the target area if it exists. Otherwise returns null
func return_partial_mapping_set_of_target_area(internal_target: AbstractCorticalArea) -> PartialMappingSet:
	for partial_mapping in _partial_mappings:
		if partial_mapping.internal_target_cortical_area == internal_target:
			return partial_mapping
	return null

## Returns true if any immediate children areas / regions have a name containing the given substring. Case Insensitive
func contains_any_object_with_friendly_name_containing_substring(substring: StringName) -> bool:
	var loweer: StringName = substring.to_lower()
	var all_objects: Array[GenomeObject] = get_all_included_genome_objects()
	for object in all_objects:
		if object.friendly_name.to_lower().contains(substring):
			return true
	return false

## Returns true if any immediate children areas / regions, or the region internals, have a name containing the given substring
func contains_any_object_with_friendly_name_containing_substring_recursive(substring: StringName) -> bool:
	if contains_any_object_with_friendly_name_containing_substring(substring):
		return true
	for region in _contained_regions:
		if region.contains_any_object_with_friendly_name_containing_substring_recursive(substring):
			return true
	return false

## Returns all regions, recursively, under this region
func get_all_subregions_recursive() -> Array[BrainRegion]:
	var output: Array[BrainRegion] = _contained_regions
	for subregion in _contained_regions:
		output.append_array(subregion.get_all_subregions_recursive())
	return output
	
	

#endregion

