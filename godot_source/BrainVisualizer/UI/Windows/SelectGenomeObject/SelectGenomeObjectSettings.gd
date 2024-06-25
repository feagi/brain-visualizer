extends RefCounted
class_name SelectGenomeObjectSettings
## Allows for easy configuration of the [WindowSelectGenomeObject] directly or via presets

# Objects that are hidden / not shown will not appear at the list at all
# Objects that are disabled will appear, but cannot be selected (regions can still be expanded)

# NOTE: Keep rules for what is / isn't allowed, so when new objects are added, we can update the selector dynamically!


var target_type: GenomeObject.ARRAY_MAKEUP = GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA
var pick_instructions: StringName = ""

var starting_region: BrainRegion = null
var preselected_objects: Array[GenomeObject] = []

# NOTE: Rules proceed from top down, where top takes precedence

var override_regions_to_not_hide: Array[BrainRegion] = []
var hide_all_regions: bool = false
var regions_to_hide: Array[BrainRegion] = []

var override_regions_to_not_disable: Array[BrainRegion] = []
var disable_all_regions: bool = false
var regions_to_disable: Array[BrainRegion] = []


var override_cortical_areas_to_not_hide: Array[AbstractCorticalArea] = []
var hide_all_cortical_areas_of_types: Array[AbstractCorticalArea.CORTICAL_AREA_TYPE] = []
var hide_all_cortical_areas: bool = false
var cortical_areas_to_hide: Array[AbstractCorticalArea] = []

var override_cortical_areas_to_not_disable: Array[AbstractCorticalArea] = []
var disable_all_cortical_areas_of_types: Array[AbstractCorticalArea.CORTICAL_AREA_TYPE] = []
var disable_all_cortical_areas: bool = false
var cortical_areas_to_disable: Array[AbstractCorticalArea] = []

## Preselcts the current parent, disables the selection of objects being moved
static func config_for_selecting_new_parent_region(current_parent: BrainRegion, objects_being_moved: Array[GenomeObject]) -> SelectGenomeObjectSettings:
	var output: SelectGenomeObjectSettings = SelectGenomeObjectSettings.new()
	output.target_type = GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION
	output.starting_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
	output.pick_instructions = "Please select the new parent Brain Region:"
	output.hide_all_cortical_areas = true
	output.preselected_objects = [current_parent]
	
	# Disallow the moving regions, or their subregions, from being move targets
	var regions_being_moved: Array[BrainRegion] = GenomeObject.filter_brain_regions(objects_being_moved)
	var subregions_being_moved: Array[BrainRegion] = []
	for region_being_moved in regions_being_moved:
		subregions_being_moved.append_array(region_being_moved.get_all_subregions_recursive())
	var regions_to_disallow_picking =  regions_being_moved
	regions_to_disallow_picking.append_array(subregions_being_moved)
	# remove duplicates
	for region in regions_to_disallow_picking:
		if !(region in output.regions_to_disable):
			output.regions_to_disable.append(region)
	return output

## Starts at a given area, allows for picking a single cortical area, bar the defined unpickables
static func config_for_single_cortical_area_selection(starting_region: BrainRegion, unpickable_areas: Array[AbstractCorticalArea] = []) -> SelectGenomeObjectSettings:
	var output: SelectGenomeObjectSettings = SelectGenomeObjectSettings.new()
	output.target_type = GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA
	output.starting_region = starting_region
	output.pick_instructions = "Please select a cortical area:"
	output.disable_all_regions = true
	output.cortical_areas_to_disable = unpickable_areas
	return output

## Starts at a given area, allows for selecting multiple objects to move to a subregion. Automatically disallows picking areas that cannot be moved and the root region
static func config_for_multiple_objects_moving_to_subregion(starting_region_: BrainRegion, objects_already_tagged_for_moving: Array[GenomeObject] = [], other_objects_not_to_move: Array[GenomeObject] = []) -> SelectGenomeObjectSettings:
	var output: SelectGenomeObjectSettings = SelectGenomeObjectSettings.new()
	output.target_type = GenomeObject.ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS
	output.pick_instructions = "Please select the objects you wish to move:"
	output.starting_region = starting_region_
	output.preselected_objects = objects_already_tagged_for_moving
	output.disable_all_cortical_areas_of_types = AbstractCorticalArea.TYPES_NOT_ALLOWED_TO_BE_MOVED_INTO_SUBREGION
	output.cortical_areas_to_disable = GenomeObject.filter_cortical_areas(other_objects_not_to_move)
	output.regions_to_disable = [FeagiCore.feagi_local_cache.brain_regions.get_root_region()]
	output.regions_to_disable.append_array(GenomeObject.filter_brain_regions(other_objects_not_to_move))
	return output

## Starting at given region, select any number of given objects
static func config_for_selecting_anything(starting_region_: BrainRegion) -> SelectGenomeObjectSettings:
	var output: SelectGenomeObjectSettings = SelectGenomeObjectSettings.new()
	output.target_type = GenomeObject.ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS
	output.starting_region = starting_region_
	return output

func is_multiselect_allowed() -> bool:
	return target_type in [GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS, GenomeObject.ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS, GenomeObject.ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS]

## Returns false if a cortical area is not to be shown (not visible)
func is_cortical_area_shown(area: AbstractCorticalArea) -> bool:
	if area in override_cortical_areas_to_not_hide:
		return true
	if area.cortical_type in hide_all_cortical_areas_of_types:
		return false
	if area in cortical_areas_to_hide:
		return false
	return !hide_all_cortical_areas

## Returns false if a cortical area is to be disabled
func is_cortical_area_disabled(area: AbstractCorticalArea) -> bool:
	if area in override_cortical_areas_to_not_disable:
		return false
	if area.cortical_type in disable_all_cortical_areas_of_types:
		return true
	if area in cortical_areas_to_disable:
		return true
	return disable_all_cortical_areas

## Returns false if a region is not to be shown (not visible)
func is_region_shown(region: BrainRegion) -> bool:
	if region in override_regions_to_not_hide:
		return true
	if region in regions_to_hide:
		return false
	return !hide_all_regions

## Returns false if a region is to be disabled (preventing to be selected, but user can still click it to expand)
func is_region_disabled(region: BrainRegion) -> bool:
	if region in override_regions_to_not_disable:
		return false
	if !(target_type in [GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION, GenomeObject.ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS, GenomeObject.ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS]):
		return true
	if region in regions_to_disable:
		return true
	return disable_all_regions

