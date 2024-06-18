extends RefCounted
class_name SelectGenomeObjectSettings
## Allows for easy configuration of the [WindowSelectGenomeObject] directly or via presets

var target_type: GenomeObject.SINGLE_MAKEUP = GenomeObject.SINGLE_MAKEUP.ANY_GENOME_OBJECT

var starting_region: BrainRegion = null
var override_regions_to_not_hide: Array[BrainRegion] = []
var hide_all_regions: bool = false
var regions_to_hide: Array[BrainRegion] = []
var override_regions_to_not_disable: Array[BrainRegion] = []
var disable_all_regions: bool = false
var regions_to_disable: Array[BrainRegion] = []

var hide_all_cortical_areas: bool = false
var override_cortical_areas_to_not_hide: Array[AbstractCorticalArea] = []
var hide_all_cortical_areas_of_types: Array[AbstractCorticalArea.CORTICAL_AREA_TYPE] = []
var cortical_areas_to_hide: Array[AbstractCorticalArea] = []
var disable_all_cortical_areas: bool = false
var override_cortical_areas_to_not_disable: Array[AbstractCorticalArea] = []
var disable_all_cortical_areas_of_types: Array[AbstractCorticalArea.CORTICAL_AREA_TYPE] = []
var cortical_areas_to_disable: Array[AbstractCorticalArea] = []

static func config_for_region_selection(starting_region: BrainRegion, area_to_show_disabled: AbstractCorticalArea = null) -> SelectGenomeObjectSettings:
	var output: SelectGenomeObjectSettings = SelectGenomeObjectSettings.new()
	output.starting_region = starting_region
	output.hide_all_cortical_areas = true
	output.target_type = GenomeObject.SINGLE_MAKEUP.SINGLE_BRAIN_REGION
	if area_to_show_disabled != null:
		output.override_cortical_areas_to_not_hide = [area_to_show_disabled]
		output.disable_all_cortical_areas = true
	return output

static func config_for_cortical_area_selection(starting_region: BrainRegion, area_to_show_disabled: AbstractCorticalArea = null) -> SelectGenomeObjectSettings:
	var output: SelectGenomeObjectSettings = SelectGenomeObjectSettings.new()
	output.starting_region = starting_region
	output.target_type = GenomeObject.SINGLE_MAKEUP.SINGLE_CORTICAL_AREA
	if area_to_show_disabled != null:
		output.cortical_areas_to_disable = [area_to_show_disabled]
	return output

static func config_for_cortical_area_moving_to_subregion(starting_region: BrainRegion, area_to_show_disabled: AbstractCorticalArea = null) -> SelectGenomeObjectSettings:
	var output: SelectGenomeObjectSettings = SelectGenomeObjectSettings.new()
	output.starting_region = starting_region
	output.target_type = GenomeObject.SINGLE_MAKEUP.ANY_GENOME_OBJECT
	var disable_types: Array[AbstractCorticalArea.CORTICAL_AREA_TYPE] = [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.CORE, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]
	output.disable_all_cortical_areas_of_types = disable_types
	if area_to_show_disabled != null:
		output.cortical_areas_to_disable = [area_to_show_disabled]
	return output

static func config_for_selecting_anything(starting_region: BrainRegion) -> SelectGenomeObjectSettings:
	var output: SelectGenomeObjectSettings = SelectGenomeObjectSettings.new()
	output.starting_region = starting_region
	return output

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

## Returns false if a region is to be disabled
func is_region_disabled(region: BrainRegion) -> bool:
	if region in override_regions_to_not_disable:
		return false
	if region in regions_to_disable:
		return true
	return disable_all_regions