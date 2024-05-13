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
	return cortical_area.current_region.get_path()

## Gets the path of regions that holds the common demoninator path between 2 regions
## Example: if region e is in region path [a,b,e] and region d is in path [a,b,c,d], this will return [a,b]
func get_common_path_containing_both_regions(A: BrainRegion, B: BrainRegion) -> Array[BrainRegion]:
	var path_A: Array[BrainRegion] = A.get_path()
	var path_B: Array[BrainRegion] = B.get_path()
	
	if len(path_A) == 0 or len(path_B) == 0:
		push_error("CORE CACHE: Unable to calculate lowest similar region path between %s and %s!" % [A.ID, B.ID])
		return []
	
	var search_depth: int
	var path: Array[BrainRegion] = []
	# Stop at shorter path distance
	if len(path_A) > len(path_B):
		search_depth = len(path_B)
	else:
		search_depth = len(path_A)
	
	for i in search_depth:
		if path_A[i].ID != path_B[i].ID:
			return path
		path.append(path_A[i])
	
	# no further to go, return the path
	return path

## Defines the directional path with 2 arrays (upward then downward) of the regions to transverse to get from the source to the destination
## Example given region layout {R{a,b{c,d{e}},f{g{h}}}, going from d -> g will return [[d,b,R],[R,f,g]]
func get_directional_path_between_regions(source: BrainRegion, destination: BrainRegion) -> Array[Array]:
	var lowest_common_region: BrainRegion = get_common_path_containing_both_regions(source, destination).back()
	if len(lowest_common_region) == 0:
		push_error("CORE CACHE: Unable to calculate directional path between %s toward %s!" % [source.ID, destination.ID])
	
	var source_path_reversed: Array[BrainRegion] = source.get_path()
	source_path_reversed.reverse()
	var index: int = source_path_reversed.find(lowest_common_region)
	var upward_path: Array[BrainRegion] = source_path_reversed.slice(0, index)
	
	var destination_path: Array[BrainRegion] = destination.get_path()
	index = destination_path.find(lowest_common_region)
	var downward_path: Array[BrainRegion]  = destination_path.slice(0, index)
	
	return [upward_path, downward_path]
