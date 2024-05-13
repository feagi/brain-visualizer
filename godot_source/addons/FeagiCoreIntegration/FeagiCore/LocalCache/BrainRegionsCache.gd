extends RefCounted
class_name BrainRegionsCache
## Holds a local copy of all [BrainRegion]s

signal region_added(region: BrainRegion)
signal region_about_to_be_removed(region: BrainRegion)

var available_brain_regions: Dictionary:
	get: return _available_brain_regions

var _available_brain_regions: Dictionary = {}

func FEAGI_add_regions_from_new_genome(data: Dictionary) -> void:
	pass

func FEAGI_add_region(region_ID: StringName, region_name: StringName, coord_2D: Vector2i, coord_3D: Vector3i, 
	dim_3D: Vector3i, contained_areas: Array[BaseCorticalArea], region_inputs: Dictionary, 
	region_outputs: Dictionary, containing_regions: Array[BrainRegion]):
	
	var region: BrainRegion = BrainRegion.new(region_ID, region_name, coord_2D, coord_3D, 
		dim_3D, contained_areas, region_inputs, region_outputs)
	region.init_contained_regions(containing_regions)
	_available_brain_regions[region_ID] = region
	region_added.emit(region)

func FEAGI_remove_region(region_ID: StringName) -> void:
	if !(region_ID in _available_brain_regions.keys()):
		push_error("CORE CACHE: Unable to find region %s to delete! Skipping!" % region_ID)
	var region: BrainRegion = _available_brain_regions[region_ID]
	region.FEAGI_delete_this_region()
	region_about_to_be_removed.emit(region)
	_available_brain_regions.erase(region_ID)

## Attempts to return the root [BrainRegion]. If it fails, this logs and error and returns null
func return_root_region() -> BrainRegion:
	if !(BrainRegion.ROOT_REGION_ID in _available_brain_regions.keys()):
		push_error("CORE CACHE: Unable to find root region! Something is wrong!")
		return null
	return _available_brain_regions[BrainRegion.ROOT_REGION_ID]

## Returns an array of regions in order of the path to the given cortical area.
## Example: Cortical Area A in region X (under ROOT) would return [ROOT, X]
func get_path_to_cortical_area(cortical_area: BaseCorticalArea) -> Array[BrainRegion]:
	if !(BrainRegion.ROOT_REGION_ID in _available_brain_regions.keys()):
		push_error("CORE CACHE: Unable to find root region! Something is wrong!")
		return []
	var searching_region: BrainRegion = cortical_area.current_region
	var path: Array[BrainRegion] = []
	while !searching_region.is_root_region():
		searching_region = searching_region.parent_region
		path.append(searching_region)
	path.append(return_root_region())
	path.reverse()
	return path

