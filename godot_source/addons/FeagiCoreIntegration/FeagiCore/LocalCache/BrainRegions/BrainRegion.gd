extends GenomeObject
class_name BrainRegion
## Defines an area enclosing various [BaseCorticalArea]s

const ROOT_REGION_ID: StringName = "root" ## This is the ID that is unique to the root region

signal about_to_be_deleted()
signal name_updated(new_name: StringName)
signal coordinates_2D_updated(new_position: Vector2i)
signal coordinates_3D_updated(new_position: Vector3i)
signal dimensions_3D_changed(new_dimension: Vector3i)
signal cortical_area_added_to_region(area: BaseCorticalArea)
signal cortical_area_removed_from_region(area: BaseCorticalArea)
signal subregion_added_to_region(subregion: BrainRegion)
signal subregion_removed_from_region(subregion: BrainRegion)
signal bridge_link_added(link: ConnectionChainLink)
signal bridge_link_removed(link: ConnectionChainLink)


var ID: StringName:
	get: return _ID
var name: StringName:
	get: return _name
	set(v):
		_name = v
		name_updated.emit(v)
var coordinates_3d: Vector3i:
	get: return _coordinates_3d
	set(v):
		_coordinates_3d = v
		coordinates_3D_updated.emit(v)
var coordinates_2d: Vector2i:
	get: return _coordinates_2d
	set(v):
		_coordinates_2d = v
		coordinates_2D_updated.emit(v)
var dimensions_3d: Vector3i:
	get: return _dimensions_3d
	set(v):
		_dimensions_3d = v
		dimensions_3D_changed.emit(v)
var contained_cortical_areas: Array[BaseCorticalArea]:
	get: return _contained_cortical_areas
var contained_regions: Array[BrainRegion]:
	get: return _contained_regions
var bridge_chain_links: Array[ConnectionChainLink]: ## Bridge links connect 2 internal members together, they do not connect to the input / output of the region
	get: return _bridge_chain_links

var _ID: StringName
var _name: StringName
var _coordinates_3d: Vector3i
var _coordinates_2d: Vector2i
var _dimensions_3d: Vector3i
var _contained_cortical_areas: Array[BaseCorticalArea]
var _contained_regions: Array[BrainRegion]
var _bridge_chain_links: Array[ConnectionChainLink]

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
	if A is BaseCorticalArea:
		return (A as BaseCorticalArea).current_region
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
		output.append(region.ID)
	return output

#NOTE: Specifically not initing regions since we need to set up all objects FIRST
func _init(region_ID: StringName, region_name: StringName, coord_2D: Vector2i, coord_3D: Vector3i):
	_ID = region_ID
	_name = region_name
	_coordinates_3d = coord_3D
	_coordinates_2d = coord_2D

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
	if genome_object is BaseCorticalArea:
		var cortical_area: BaseCorticalArea = (genome_object as BaseCorticalArea)
		if cortical_area in _contained_cortical_areas:
			push_error("CORE CACHE: Cannot add cortical area %s to region %s that already contains it! Skipping!" % [cortical_area.cortical_ID, _ID])
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
			push_error("CORE CACHE: Cannot add region %s to region %s that already contains it! Skipping!" % [region.ID, _ID])
			return
		_contained_regions.append(region)
		subregion_added_to_region.emit(region)
		return
	push_error("CORE CACHE: Unknown GenomeObject type tried to be added to region %s!" % _ID)

func FEAGI_genome_object_deregister_as_child(genome_object: GenomeObject) -> void:
	if genome_object is BaseCorticalArea:
		var cortical_area: BaseCorticalArea = (genome_object as BaseCorticalArea)
		var index: int = _contained_cortical_areas.find(cortical_area)
		if index == -1:
			push_error("CORE CACHE: Cannot remove cortical area %s from region %s that doesn't contains it! Skipping!" % [cortical_area.cortical_ID, _ID])
			return
		_contained_cortical_areas.remove_at(index)
		cortical_area_removed_from_region.emit(cortical_area)
		return
	if genome_object is BrainRegion:
		var region: BrainRegion = (genome_object as BrainRegion)
		var index: int = _contained_regions.find(region)
		if index == -1:
			push_error("CORE CACHE: Cannot remove region %s from region %s that doesn't contains it! Skipping!" % [region.ID, _ID])
			return
		_contained_regions.remove_at(index)
		subregion_removed_from_region.emit(region)
		return
	push_error("CORE CACHE: Unknown GenomeObject type tried to be removed from region %s!" % _ID)

## Called from FEAGI when we update properties of the brain region
func FEAGI_edited_region(title: StringName, _description: StringName, new_parent_region: BrainRegion, position_2D: Vector2i, position_3D: Vector3i) -> void:
	name = title
	#TODO description?
	coordinates_2d = position_2D
	coordinates_3d = position_3D
	if new_parent_region.ID != current_parent_region.ID:
		change_parent_brain_region(new_parent_region)


#TODO make better deletion with proper checks
## FEAGI confirmed this region is deleted. Called by [BrainRegionCache]
func FEAGI_delete_this_region() -> void:
	if len(_contained_regions) != 0:
		push_error("CORE CACHE: Cannot remove region %s as it still contains regions! Skipping!" % [_ID])
	if len(_contained_cortical_areas) != 0:
		push_error("CORE CACHE: Cannot remove region %s as it still contains cortical areas! Skipping!" % [_ID])
	about_to_be_deleted.emit()
	# This function should be called by [BrainRegionsCache], which will then free this object

#endregion


## [ConnectionChain] Interactions, as the result of mapping updates or hint updates
#region ConnectionChainLink changes

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region
func input_add_link(link: ConnectionChainLink) -> void:
	if link in _input_chain_links:
		push_error("CORE CACHE: Unable to add input link to region %s when it already exists!" % name)
		return
	_input_chain_links.append(link)
	input_link_added.emit(link)

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region
func output_add_link(link: ConnectionChainLink) -> void:
	if link in _output_chain_links:
		push_error("CORE CACHE: Unable to add output link to region %s when it already exists!" % name)
		return
	_output_chain_links.append(link)
	output_link_added.emit(link)

## Called by [ConnectionChainLink] when it instantiates, adds a reference to that link to this region
func bridge_add_link(link: ConnectionChainLink) -> void:
	if link in _bridge_chain_links:
		push_error("CORE CACHE: Unable to add bridge link to region %s when it already exists!" % name)
		return
	_bridge_chain_links.append(link)
	bridge_link_added.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func input_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _input_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from region %s as it wasn't found!" % name)
		return
	_input_chain_links.remove_at(index)
	input_link_removed.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func output_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _output_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from region %s as it wasn't found!" % name)
		return
	_output_chain_links.remove_at(index)
	output_link_removed.emit(link)

## Called by [ConnectionChainLink] when it is about to be free'd, removes the reference to that link to this region
func bridge_remove_link(link: ConnectionChainLink) -> void:
	var index: int = _bridge_chain_links.find(link)
	if index == -1:
		push_error("CORE CACHE: Unable to add remove link from region %s as it wasn't found!" % name)
		return
	_bridge_chain_links.remove_at(index)
	bridge_link_removed.emit(link)

#endregion


## Queries that can be made from the UI layer to ascern specific properties
#region Queries

## Returns if this region is the root region or not
func is_root_region() -> bool:
	return _ID == ROOT_REGION_ID

## Returns if a cortical area is a cortical area within this region (not nested in another region)
func is_cortical_area_in_region_directly(cortical_area: BaseCorticalArea) -> bool:
	return cortical_area in _contained_cortical_areas

func is_subregion_directly(region: BrainRegion) -> bool:
	return region in _contained_regions

func is_genome_object_in_region_directly(object: GenomeObject) -> bool:
	if object is BaseCorticalArea:
		return is_cortical_area_in_region_directly(object as BaseCorticalArea)
	if object is BrainRegion:
		return is_subregion_directly(object as BrainRegion)
	return false

## Returns if a cortical area is within this region (including within another region inside here)
func is_cortical_area_in_region_recursive(cortical_area: BaseCorticalArea) -> bool:
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

func get_all_included_genome_objects() -> Array[GenomeObject]:
	var contained_objects: Array[GenomeObject] = []
	for area in _contained_cortical_areas:
		contained_objects.append(area)
	for region in _contained_regions:
		contained_objects.append(region)
	return contained_objects


#endregion
