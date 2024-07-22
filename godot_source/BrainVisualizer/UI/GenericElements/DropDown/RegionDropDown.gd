extends OptionButton
class_name RegionDropDown
## Dropdown specifically intended to list Regions by name

signal user_selected_region(region_ref: BrainRegion)

# If true, will automatically remove regions from the drop down that were removed from cache
@export var sync_removed_regions: bool = true
# If true, will automatically add regions from the drop down that were added to the cache
@export var sync_added_regions: bool = true

@export var load_available_brain_regions_on_start = true

## If True, will hide the circle selection icon on the dropdown
@export var hide_circle_select_icon: bool = true

var _listed_regions: Array[BrainRegion] = []
var _popup: PopupMenu
var _default_width: float

func _ready():
	_default_width = custom_minimum_size.x
	_popup = get_popup()
	if load_available_brain_regions_on_start:
		reload_available_brain_regions()
	item_selected.connect(_user_selected_option)
	if sync_removed_regions:
		FeagiCore.feagi_local_cache.brain_regions.region_about_to_be_removed.connect(_region_was_deleted_from_cache)
	if sync_added_regions:
		FeagiCore.feagi_local_cache.brain_regions.region_added.connect(_region_was_added_to_cache)
	BV.UI.theme_changed.connect(_on_theme_change)
	_on_theme_change()

func reload_available_brain_regions() -> void:
	var regions: Array[BrainRegion] = []
	regions.assign(FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.values())
	overwrite_regions(regions)

## Clears all listed regions
func clear_all_regions() -> void:
	_listed_regions = []
	clear()

## Replace region listing with a new one
func overwrite_regions(new_region: Array[BrainRegion]) -> void:
	clear_all_regions()
	for region in new_region:
		add_region(region)

## Add a singular region to the end of the drop down
func add_region(new_region: BrainRegion) -> void:
	_listed_regions.append(new_region)
	add_item(new_region.name) # using name only since as of writing, regions do not have IDs
	if hide_circle_select_icon:
		_popup.set_item_as_radio_checkable(_popup.get_item_count() - 1, false) # Remove Circle Selection
	

## Retrieves selected region. If none is selected, returns a Null
func get_selected_region() -> BrainRegion:
	if selected == -1: 
		return null
	return _listed_regions[selected]

## retrieves the region name of the selected region
## Returns "" if none is selected!
func get_selected_region_name() -> StringName:
	if selected == -1: 
		return &""
	return _listed_regions[selected].name

## Set the drop down selection to a specific (contained) region
func set_selected_region(set_region: BrainRegion) -> void:
	var index: int = _listed_regions.find(set_region)
	if index == -1:
		push_warning("Attemped to set region drop down to an item that the drop down does not contain! Skipping!")
		return
	select(index)

func set_selected_region_by_ID(region_ID: StringName) -> void:
	if region_ID not in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.keys():
		push_error("Attempted to set region dropdown to region not found in cache by ID of " + region_ID + ". Skipping!")
		return
	set_selected_region(FeagiCore.feagi_local_cache.brain_regions.available_brain_regions[region_ID])

## Set the dropdown to select nothing
func deselect_all() -> void:
	select(-1)

## Remove region from listing
func remove_region(removing: BrainRegion) -> void:
	var index: int = _listed_regions.find(removing)
	if index == -1:
		push_warning("Attempted to remove cortical area that the drop down does not contain! Skipping!")
		return
	_listed_regions.remove_at(index)
	remove_item(index)

func _user_selected_option(index: int) -> void:
	user_selected_region.emit(_listed_regions[index])

func _region_was_deleted_from_cache(deleted_region: BrainRegion) -> void:
	if deleted_region not in _listed_regions:
		return
	remove_region(deleted_region)

func _region_was_added_to_cache(added_region: BrainRegion) -> void:
	if added_region not in _listed_regions:
		add_region(added_region)

func _on_theme_change(_new_theme: Theme = null) -> void:
	custom_minimum_size.x = _default_width * BV.UI.loaded_theme_scale.x
