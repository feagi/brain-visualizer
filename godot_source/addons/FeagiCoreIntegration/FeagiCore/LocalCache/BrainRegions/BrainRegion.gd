extends RefCounted
class_name BrainRegion
## Defines an area enclosing various [BaseCorticalArea]s

const ROOT_REGION_ID: StringName = "root" ## This is the ID that is unique to the root region

signal about_to_be_deleted()
signal internals_changed()
signal inputs_changed()
signal outputs_changed()
signal name_changed(new_name: StringName)
signal position_2D_changed(new_position: Vector2i)
signal position_3D_changed(new_position: Vector3i)
signal dimensions_3D_changed(new_dimension: Vector3i)
signal parent_region_changed(old_parent_region: BrainRegion, new_parent_region: BrainRegion)


var ID: StringName:
	get: return _ID
var name: StringName:
	get: return _name
	set(v):
		_name = v
		name_changed.emit(v)
var coordinates_3d: Vector3i:
	get: return _coordinates_3d
	set(v):
		_coordinates_3d = v
		position_3D_changed.emit(v)
var coordinates_2d: Vector2i:
	get: return _coordinates_2d
	set(v):
		_coordinates_2d = v
		position_2D_changed.emit(v)
var dimensions_3d: Vector3i:
	get: return _dimensions_3d
	set(v):
		_dimensions_3d = v
		dimensions_3D_changed.emit(v)
var contained_cortical_areas: Array[BaseCorticalArea]:
	get: return _contained_cortical_areas
var contained_regions: Array[BrainRegion]:
	get: return _contained_regions
var inputs: Dictionary: 
	get: return _inputs # key'd by name stringname, data is [RegionMappingSuggestion]
var outputs: Dictionary: 
	get: return _outputs # key'd by name stringname, data is [RegionMappingSuggestion]
var parent_region: BrainRegion:
	get: return _parent_region

var _ID: StringName
var _name: StringName
var _coordinates_3d: Vector3i
var _coordinates_2d: Vector2i
var _dimensions_3d: Vector3i
var _contained_cortical_areas: Array[BaseCorticalArea]
var _contained_regions: Array[BrainRegion]
var _inputs: Dictionary = {}
var _outputs: Dictionary = {}
var _parent_region: BrainRegion


#NOTE: Specifically not initing regions since we need to set up all objects FIRST
func _init(region_ID: StringName, region_name: StringName, coord_2D: Vector2i, coord_3D: Vector3i, dim_3D: Vector3i,
	contained_areas: Array[BaseCorticalArea], region_inputs: Dictionary, region_outputs: Dictionary):
	
	_ID = region_ID
	_name = region_name
	_coordinates_3d = coord_3D
	_coordinates_2d = coord_2D
	_dimensions_3d = dim_3D
	_contained_cortical_areas = contained_areas
	_inputs = region_inputs
	_outputs = region_outputs

## during Genome loading ONLY, after we created the general objects, now we can 
func init_region_relationships(containing_regions: Array[BrainRegion], parent_region: BrainRegion) -> void:
	_contained_regions = containing_regions
	_parent_region = parent_region

## FEAGI confirmed a cortical area was added
func FEAGI_add_a_cortical_area(cortical_area: BaseCorticalArea) -> void:
	if cortical_area in _contained_cortical_areas:
		push_error("CORE CACHE: Cannot add cortical area %s to region %s that already contains it! Skipping!" % [cortical_area.cortical_ID, _ID])
		return
	_contained_cortical_areas.append(cortical_area)

## FEAGI confirmed a cortical area was removed
func FEAGI_remove_a_cortical_area(cortical_area: BaseCorticalArea) -> void:
	var index: int = _contained_cortical_areas.find(cortical_area)
	if index == -1:
		push_error("CORE CACHE: Cannot remove cortical area %s from region %s that doesn't contains it! Skipping!" % [cortical_area.cortical_ID, _ID])
		return
	_contained_cortical_areas.remove_at(index)

## FEAGI confirmed a region was added
func FEAGI_add_a_region(region: BrainRegion) -> void:
	if region in _contained_regions:
		push_error("CORE CACHE: Cannot add region %s to region %s that already contains it! Skipping!" % [region.ID, _ID])
		return
	_contained_regions.append(region)

## FEAGI confirmed a region was removed
func FEAGI_remove_a_region(region: BrainRegion) -> void:
	var index: int = _contained_regions.find(region)
	if index == -1:
		push_error("CORE CACHE: Cannot remove region %s from region %s that doesn't contains it! Skipping!" % [region.ID, _ID])
		return
	_contained_regions.remove_at(index)

## FEAGI confirmed that this region was moved and now has another parent region
func FEAGI_change_parent_region(new_region: BrainRegion) -> void:
	var old_cache: BrainRegion = _parent_region # yes this method uses more memory but avoids potential shenanigans
	_parent_region = new_region
	parent_region_changed.emit(old_cache, new_region)

## FEAGI confirmed this region is deleted
func FEAGI_delete_this_region() -> void:
	if len(_contained_regions) != 0:
		push_error("CORE CACHE: Cannot remove region %s as it still contains regions! Skipping!" % [_ID])
	if len(_contained_cortical_areas) != 0:
		push_error("CORE CACHE: Cannot remove region %s as it still contains regions! Skipping!" % [_ID])
	about_to_be_deleted.emit()
	# This function should be called by [BrainRegionsCache], which will then free this object

## Returns if this region is the root region or not
func is_root_region() -> bool:
	return _ID == ROOT_REGION_ID

## Returns if a cortical area is a cortical area within this region (not nested in another region)
func is_cortical_area_in_region_directly(cortical_area: BaseCorticalArea) -> bool:
	return cortical_area in _contained_cortical_areas

## Returns if a cortical area is within this region (including within another region inside here)
func is_cortical_area_in_region(cortical_area: BaseCorticalArea) -> bool:
	if cortical_area in _contained_cortical_areas:
		return true
	for region: BrainRegion in _contained_regions:
		if region.is_cortical_area_in_region(cortical_area):
			return true
	return false

## Returns the path of this region, starting with the root region and ending with this region
func get_path() -> Array[BrainRegion]:
	var searching_region: BrainRegion = self
	var path: Array[BrainRegion] = []
	while !searching_region.is_root_region():
		path.append(searching_region)
		searching_region = searching_region.parent_region
	path.append(searching_region)
	path.reverse()
	return path
	
	
