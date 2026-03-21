extends RefCounted
class_name BrainRegionsCache
## Holds a local copy of all [BrainRegion]s

signal region_added(region: BrainRegion)
signal region_about_to_be_removed(region: BrainRegion)

var available_brain_regions: Dictionary:
	get: return _available_brain_regions

var _available_brain_regions: Dictionary = {}
var _cached_root_region_id: StringName = ""  # Cached for O(1) root lookup

## Calls from FEAGI to update the cache
#region FEAGI Interactions

## Called by [FEAGILocalCache] on genome load. Loads in all regions from FEAGI summary data to cache. Also creates a mapping table to add cortical areas in a later step of genome loading
func FEAGI_load_all_regions_and_establish_relations_and_calculate_area_region_mapping(region_summary_data: Dictionary) -> Dictionary: # This function name clearly isn't long enough
	
	# First pass is to generate all the region objects without any children
	for region_ID: StringName in region_summary_data.keys():
		_available_brain_regions[region_ID] = BrainRegion.from_FEAGI_JSON_ignore_children(region_summary_data[region_ID], region_ID)
	
	# Cache root region ID for O(1) lookup (check API data directly)
	_cache_root_region_id_from_api_data(region_summary_data)
	
	var cortical_area_mapping: Dictionary = {}
	# Second pass is to link all child region to a given parent region, and to calculate mappings for cortical IDs to their correct parent region
	for parent_region_ID: StringName in region_summary_data.keys():
		var parent_region: BrainRegion = _available_brain_regions[parent_region_ID]
		# link child regions
		var child_region_IDs: Array[StringName] = []
		child_region_IDs.assign(region_summary_data[parent_region_ID]["regions"])
		var child_regions: Array[BrainRegion] = arr_of_region_IDs_to_arr_of_Regions(child_region_IDs)
		for child_region in child_regions:
			# Skip if child is actually the root (safety check using API data)
			# Check if child has no parent in the API data (indicates it's the root)
			var child_data = region_summary_data.get(child_region.region_ID)
			if child_data:
				var child_parent_id = child_data.get("parent_region_id")
				# Root has parent_region_id == null
				if child_parent_id == null or String(child_parent_id) == "null" or String(child_parent_id) == "":
					continue
			
			# Establish parent relationship
			child_region.FEAGI_init_parent_relation(parent_region)
		
		# Create cortical ID mapping (but don't add cortical areas yet)
		var cortical_IDs: Array[StringName] = []
		cortical_IDs.assign(region_summary_data[parent_region_ID]["areas"])
		for cortical_ID in cortical_IDs:
			if cortical_ID in cortical_area_mapping.keys():
				push_warning("CORE CACHE: Cortical Area %s previously reported in region %s is now reported in region %s. Keeping the original region." % [cortical_ID, cortical_area_mapping[cortical_ID], parent_region_ID])
				continue
			cortical_area_mapping[cortical_ID] = parent_region_ID
	
	
	
	return cortical_area_mapping

func FEAGI_load_all_partial_mapping_sets(region_summary_data: Dictionary) -> void:
	var region_dict: Dictionary
	var arr_IO: Array  # Can be Array[String] or Array[Dictionary]
	var region: BrainRegion
	for region_ID in region_summary_data:
		region_dict = region_summary_data[region_ID]
		if region_dict.has("inputs"):
			if !(region_ID in _available_brain_regions):
				push_error("CORE CACHE: Unable to find region %s to add partial mapping set to!")
				continue
			region = _available_brain_regions[region_ID]
			arr_IO = []
			arr_IO.assign(region_dict["inputs"])
			region.FEAGI_establish_partial_mappings_from_JSONs(arr_IO, true)
		if region_dict.has("outputs"):
			if !(region_ID in _available_brain_regions):
				push_error("CORE CACHE: Unable to find region %s to add partial mapping set to!")
				continue
			region = _available_brain_regions[region_ID]
			arr_IO = []
			arr_IO.assign(region_dict["outputs"])
			region.FEAGI_establish_partial_mappings_from_JSONs(arr_IO, false)
			

## Applies region summary updates without clearing the entire cache.
## Returns a mapping of cortical_area_id -> parent_region_id for subsequent cortical area refresh.
func FEAGI_apply_region_summary_diff(region_summary_data: Dictionary) -> Dictionary:
	# During FEAGI restart windows, region summary may be transient/incomplete.
	# Do not run destructive diff logic unless a root region is present in the payload.
	if not summary_has_root_region(region_summary_data):
		push_warning("CORE CACHE: Region summary missing root region; skipping destructive region diff for this refresh cycle.")
		return {}

	# Remove regions no longer present.
	var removed_count: int = 0
	var added_count: int = 0
	var updated_parent_count: int = 0
	var existing_ids: Array = _available_brain_regions.keys()
	for existing_id in existing_ids:
		if not region_summary_data.has(existing_id):
			var region_to_remove: BrainRegion = _available_brain_regions[existing_id]
			FEAGI_remove_region_and_raise_internals(region_to_remove)
			removed_count += 1

	# Create new regions.
	for region_ID: StringName in region_summary_data.keys():
		if region_ID in _available_brain_regions:
			continue
		_available_brain_regions[region_ID] = BrainRegion.from_FEAGI_JSON_ignore_children(region_summary_data[region_ID], region_ID)
		added_count += 1

	# Cache root region ID for O(1) lookup (check API data directly).
	_cache_root_region_id_from_api_data(region_summary_data)

	var cortical_area_mapping: Dictionary = {}
	# Update region properties and parent relations.
	for region_ID: StringName in region_summary_data.keys():
		var region_data: Dictionary = region_summary_data[region_ID]
		var region: BrainRegion = _available_brain_regions[region_ID]
		region.FEAGI_change_friendly_name(region_data.get("title", region.friendly_name))
		if region_data.has("coordinate_2d"):
			region.FEAGI_change_coordinates_2D(FEAGIUtils.array_to_vector2i(region_data["coordinate_2d"]))
		if region_data.has("coordinate_3d"):
			region.FEAGI_change_coordinates_3D(FEAGIUtils.array_to_vector3i(region_data["coordinate_3d"]))

		var parent_id = region_data.get("parent_region_id")
		if parent_id != null:
			if parent_id in _available_brain_regions:
				var parent_region: BrainRegion = _available_brain_regions[parent_id]
				if region.current_parent_region == null:
					region.FEAGI_init_parent_relation(parent_region)
					updated_parent_count += 1
				else:
					var before_parent = region.current_parent_region
					region.FEAGI_change_parent_brain_region(parent_region)
					if before_parent != parent_region:
						updated_parent_count += 1
			else:
				push_error("CORE CACHE: Parent region %s not found for region %s" % [parent_id, region_ID])

		# Create cortical ID mapping (but don't add cortical areas yet).
		var cortical_IDs: Array[StringName] = []
		cortical_IDs.assign(region_data.get("areas", []))
		for cortical_ID in cortical_IDs:
			if cortical_ID in cortical_area_mapping.keys():
				push_warning("CORE CACHE: Cortical Area %s previously reported in region %s is now reported in region %s. Keeping the original region." % [cortical_ID, cortical_area_mapping[cortical_ID], region_ID])
				continue
			cortical_area_mapping[cortical_ID] = region_ID

	print("FEAGI CACHE: Region diff applied (added=%d, removed=%d, parent_updates=%d)" % [added_count, removed_count, updated_parent_count])
	return cortical_area_mapping

## True if the regions summary JSON includes a root entry (parent_region_id == null).
func summary_has_root_region(region_summary_data: Dictionary) -> bool:
	for region_id in region_summary_data.keys():
		var region_data: Variant = region_summary_data.get(region_id, null)
		if typeof(region_data) != TYPE_DICTIONARY:
			continue
		var parent_id: Variant = (region_data as Dictionary).get("parent_region_id", null)
		if parent_id == null:
			return true
	return false

## Clears all regions from the cache - used during full genome reload
func FEAGI_clear_all_regions() -> void:
	_available_brain_regions.clear()
	_cached_root_region_id = ""  # Clear root cache

func FEAGI_add_region(region_ID: StringName, parent_region: BrainRegion, region_name: StringName, coord_2D: Vector2i, coord_3D: Vector3i, contained_objects: Array[GenomeObject] = []) -> void:
	if region_ID in _available_brain_regions.keys():
		push_error("CORE CACHE: Unable to add another region of the ID %s!" % region_ID)
		return
	var region: BrainRegion = BrainRegion.new(region_ID, region_name, coord_2D, coord_3D)
	region.FEAGI_init_parent_relation(parent_region)
	_available_brain_regions[region_ID] = region
	for object in contained_objects:
		object.FEAGI_change_parent_brain_region(region)
	# NOTE: region_added signal will be emitted after all cache data is loaded (called from FEAGIRequests)

## Emits the region_added signal for a specific region (called after all cache data is loaded)
func emit_region_added_signal(region: BrainRegion) -> void:
	region_added.emit(region)

func FEAGI_edit_region(editing_region: BrainRegion, title: StringName, _description: StringName, new_parent_region: BrainRegion, position_2D: Vector2i, position_3D: Vector3i) -> void:
	if !(editing_region.region_ID in _available_brain_regions.keys()):
		push_error("CORE CACHE: Unable to edit noncached region of the ID %s!" % editing_region.region_ID)
		return
	editing_region.FEAGI_edited_region(title, _description, new_parent_region, position_2D, position_3D)

## Applies mass update of 2d locations to cortical areas. Only call from FEAGI
func FEAGI_mass_update_2D_positions(IDs_to_locations: Dictionary) -> void:
	for region in IDs_to_locations.keys():
		if region == null:
			push_error("Unable to update position of %s null bnrain region!")
			continue
		if !(region.region_ID in _available_brain_regions.keys()):
			push_error("Unable to update position of %s due to this brain region missing in cache" % region.cortical_ID)
			continue
		region.FEAGI_change_coordinates_2D(IDs_to_locations[region])

#NOT COMPLETE #TODO
#func FEAGI_remove_region_and_internals(region_ID: StringName) -> void:
#	if !(region_ID in _available_brain_regions.keys()):
#		push_error("CORE CACHE: Unable to find region %s to delete! Skipping!" % region_ID)
#	var region: BrainRegion = _available_brain_regions[region_ID]
#	
#	region.FEAGI_delete_this_region()
#	region_about_to_be_removed.emit(region)
#	_available_brain_regions.erase(region_ID)

## FEAGI states that a region is to be removed and internals raised
func FEAGI_remove_region_and_raise_internals(region: BrainRegion) -> void:
	if region == null or not is_instance_valid(region):
		push_warning("CORE CACHE: Cannot remove null/invalid region reference. Skipping.")
		return
	if region.is_root_region():
		push_warning("CORE CACHE: Cannot remove root region via raise internals path. Skipping.")
		return
	var new_parent: BrainRegion = region.current_parent_region
	if new_parent == null or not is_instance_valid(new_parent):
		push_warning("CORE CACHE: Cannot remove region %s because parent region reference is missing. Skipping." % region.region_ID)
		return
	for object: GenomeObject in region.get_all_included_genome_objects():
		object.FEAGI_change_parent_brain_region(new_parent)
	region_about_to_be_removed.emit(region)
	region.FEAGI_delete_this_region()
	_available_brain_regions.erase(region.region_ID)

#endregion


## Get information about the cache state
#region Queries

func _get_configured_root_id() -> StringName:
	var rid = ProjectSettings.get_setting("feagi/root_region_id")
	if rid == null or String(rid) == "":
		return BrainRegion.ROOT_REGION_ID
	return StringName(String(rid))

## Cache the root region ID for O(1) access
## Called after loading all regions
## Cache root region ID from API data (checks parent_region_id field)
func _cache_root_region_id_from_api_data(region_summary_data: Dictionary) -> void:
	# Find region where parent_region_id is null in API data
	for region_ID in region_summary_data.keys():
		var region_data = region_summary_data[region_ID]
		var parent_id = region_data.get("parent_region_id")
		if parent_id == null:
			_cached_root_region_id = region_ID
			return
	
	push_warning("CORE CACHE: No root region found in API data!")

## Returns True if the root region is in the cache
## Root region is identified by having no parent (UUID-based RegionID architecture)
func is_root_available() -> bool:
	# O(1) cached lookup
	if _cached_root_region_id != "" and _cached_root_region_id in _available_brain_regions:
		return true
	
	# Fallback: Search for region with no parent
	for region in _available_brain_regions.values():
		if region.is_root_region():
			_cached_root_region_id = region.region_ID  # Cache for next time
			return true
	
	return false


## Attempts to return the root [BrainRegion]. If it fails, logs an error and returns null
## Root region is identified by having no parent (UUID-based RegionID architecture)
func get_root_region() -> BrainRegion:
	# O(1) cached lookup
	if _cached_root_region_id != "" and _cached_root_region_id in _available_brain_regions:
		return _available_brain_regions[_cached_root_region_id]
	
	# Fallback: Search for region with no parent
	for region in _available_brain_regions.values():
		if region.is_root_region():
			_cached_root_region_id = region.region_ID  # Cache for next time
			return region
	
	push_error("CORE CACHE: Unable to find root region! No region has null parent!")
	push_error("CORE CACHE: Available regions: %s" % str(_available_brain_regions.keys()))
	return null

## Walk from [region] toward the root: [self, parent, grandparent, ... , root]. Cycle-safe.
func _ancestor_chain_toward_root(region: BrainRegion) -> Array[BrainRegion]:
	var out: Array[BrainRegion] = []
	if region == null or not is_instance_valid(region):
		return out
	var seen: Dictionary = {}
	var cur: BrainRegion = region
	while cur != null and is_instance_valid(cur):
		if seen.has(cur.region_ID):
			push_warning("CORE CACHE: Cycle in region parent pointers near %s" % cur.region_ID)
			break
		seen[cur.region_ID] = true
		out.append(cur)
		if cur.is_root_region():
			break
		cur = cur.current_parent_region
	return out


func _chain_contains_region_id(chain: Array[BrainRegion], region_id: StringName) -> bool:
	for n in chain:
		if n != null and is_instance_valid(n) and n.region_ID == region_id:
			return true
	return false


func _chain_index_of_region_id(chain: Array[BrainRegion], region_id: StringName) -> int:
	for i in range(chain.size()):
		var n: BrainRegion = chain[i]
		if n != null and is_instance_valid(n) and n.region_ID == region_id:
			return i
	return -1


## Lowest common ancestor of two regions using explicit parent walks (stable when get_path() prefixes disagree).
## If walks share no node but both reach the cached root, returns [get_root_region()].
func get_lowest_common_ancestor_region(a: BrainRegion, b: BrainRegion) -> BrainRegion:
	if a == null or b == null:
		return null
	if a.region_ID == b.region_ID:
		return a
	var chain_a: Array[BrainRegion] = _ancestor_chain_toward_root(a)
	var chain_b: Array[BrainRegion] = _ancestor_chain_toward_root(b)
	var ids_from_a: Dictionary = {}
	for r in chain_a:
		ids_from_a[r.region_ID] = true
	for r in chain_b:
		if ids_from_a.has(r.region_ID):
			return r
	var root: BrainRegion = get_root_region()
	if root != null:
		var rid: StringName = root.region_ID
		if _chain_contains_region_id(chain_a, rid) and _chain_contains_region_id(chain_b, rid):
			return root
	return null


## Gets the path of regions from root down to the lowest common ancestor of A and B (inclusive).
## Example: if region e is in region path [a,b,e] and region d is in path [a,b,c,d], this will return [a,b]
func get_common_path_containing_both_regions(A: BrainRegion, B: BrainRegion) -> Array[BrainRegion]:
	if A == null or B == null:
		push_error("CORE CACHE: Cannot calculate common path - A or B is null!")
		return []
	var lca: BrainRegion = get_lowest_common_ancestor_region(A, B)
	if lca == null:
		return []
	var chain: Array[BrainRegion] = _ancestor_chain_toward_root(lca)
	chain.reverse()
	return chain

## Defines the directional path with 2 arrays (upward then downward) of the regions to transverse to get from the source to the destination
## Example given region layout {R{a,b{c,d{e}},f{g{h}}}, going from d -> g will return [[d,b,R],[R,f,g]]
func get_directional_path_between_regions(source: BrainRegion, destination: BrainRegion) -> Array[Array]:
	if source == null or destination == null:
		push_error("CORE CACHE: Cannot calculate path - source or destination is null!")
		return [[], []]
	if source.region_ID == destination.region_ID:
		return [[], []]

	var chain_s: Array[BrainRegion] = _ancestor_chain_toward_root(source)
	var chain_d: Array[BrainRegion] = _ancestor_chain_toward_root(destination)
	if chain_s.is_empty() or chain_d.is_empty():
		push_warning("CORE CACHE: Empty ancestor chain for directional path (%s -> %s)." % [source.region_ID, destination.region_ID])
		return [[], []]

	var ids_from_s: Dictionary = {}
	for r in chain_s:
		ids_from_s[r.region_ID] = true

	var lca: BrainRegion = null
	for r in chain_d:
		if ids_from_s.has(r.region_ID):
			lca = r
			break

	if lca == null:
		var root_fallback: BrainRegion = get_root_region()
		if root_fallback != null:
			var rid: StringName = root_fallback.region_ID
			if _chain_contains_region_id(chain_s, rid) and _chain_contains_region_id(chain_d, rid):
				lca = root_fallback

	if lca == null:
		push_warning("CORE CACHE: No LCA between regions %s and %s; connection chain uses direct endpoint hop only." % [source.region_ID, destination.region_ID])
		return [[], []]

	var idx_s: int = _chain_index_of_region_id(chain_s, lca.region_ID)
	var idx_d: int = _chain_index_of_region_id(chain_d, lca.region_ID)
	if idx_s < 0 or idx_d < 0:
		push_warning("CORE CACHE: LCA %s not found on ancestor chain for %s or %s." % [lca.region_ID, source.region_ID, destination.region_ID])
		return [[], []]

	var upward_path: Array[BrainRegion] = []
	for i in range(idx_s):
		upward_path.append(chain_s[i])

	var downward_path: Array[BrainRegion] = []
	for j in range(idx_d):
		downward_path.append(chain_d[j])
	downward_path.reverse()

	return [upward_path, downward_path]

## Convert an array of region IDs to an array of [BrainRegion] from cache
func arr_of_region_IDs_to_arr_of_Regions(IDs: Array[StringName]) -> Array[BrainRegion]:
	var output: Array[BrainRegion] = []
	for ID in IDs:
		if !(ID in _available_brain_regions.keys()):
			push_error("CORE CACHE: Unable to find region %s! Skipping!" % ID)
			continue
		output.append(_available_brain_regions[ID])
	return output

## As a single flat array, get the end inclusive path from the starting [GenomeObject], to the end [GenomeObject]
func get_total_path_between_objects(starting_point: GenomeObject, stoppping_point: GenomeObject) -> Array[GenomeObject]:
	# Get start / stop points
	var is_start_cortical_area: bool = starting_point is AbstractCorticalArea
	var is_end_cortical_area: bool = stoppping_point is AbstractCorticalArea
	
	var start_region: BrainRegion
	if is_start_cortical_area:
		start_region = (starting_point as AbstractCorticalArea).current_parent_region
	else:
		start_region = starting_point
	var end_region: BrainRegion
	if is_end_cortical_area:
		end_region = (stoppping_point as AbstractCorticalArea).current_parent_region
	else:
		end_region = stoppping_point
	
	# Null check: Return empty path if parent regions not set yet
	if start_region == null or end_region == null:
		push_warning("CORE CACHE: Cannot calculate path - parent regions not set yet for cortical areas")
		return []
	
	# Generate total path
	var region_path: Array[Array] = FeagiCore.feagi_local_cache.brain_regions.get_directional_path_between_regions(start_region, end_region)
	if region_path.size() < 2:
		return [starting_point, stoppping_point]
	var up_regions: Array = region_path[0]
	var down_regions: Array = region_path[1]
	var total_chain_path: Array[GenomeObject] = []
	total_chain_path.append(starting_point)
	total_chain_path.append_array(up_regions)
	total_chain_path.append_array(down_regions)
	total_chain_path.append(stoppping_point)
	return total_chain_path

#endregion
