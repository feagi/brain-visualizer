extends PanelContainer
class_name ScrollRegionInternalsView

const LIST_ITEM_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollGenomeObjectSelector/ScrollRegionInternalsView/ScrollRegionInternalsViewItem.tscn")

signal genome_object_toggled(genome_object: GenomeObject, is_selected: bool, self_ref: ScrollRegionInternalsView)
signal region_expansion_attempted(region: BrainRegion, self_ref: ScrollRegionInternalsView)

var representing_region: BrainRegion:
	get: return _representing_region

var _representing_region: BrainRegion
var _internal_regions: Dictionary
var _internal_cortical_areas: Dictionary
var _view_config: SelectGenomeObjectSettings
var _multiselect_enabled: bool

var _container: VBoxContainer

func _ready():
	_container = $Scroll/VBoxContainer

## In special case of left most container, just to show the root region, but technically nothing is holding this
func setup_first(first_region: BrainRegion, view_config: SelectGenomeObjectSettings, preselected_objects: Array[GenomeObject]) -> void:
	_view_config = view_config
	if !first_region.is_root_region():
		_representing_region = first_region.current_parent_region
	_multiselect_enabled = view_config.is_multiselect_allowed()
	reset_to_blank()
	_add_region(first_region, first_region in preselected_objects)

func setup_rest(brain_region: BrainRegion, view_config: SelectGenomeObjectSettings, preselected_objects: Array[GenomeObject]) -> void:
	_representing_region = brain_region
	_view_config = view_config
	_multiselect_enabled = _view_config.is_multiselect_allowed()
	for region in brain_region.contained_regions:
		_add_region(region, region in preselected_objects)
	for area in brain_region.contained_cortical_areas:
		_add_cortical_area(area, area in preselected_objects)
	brain_region.cortical_area_added_to_region.connect(_add_cortical_area)
	brain_region.cortical_area_removed_from_region.connect(_remove_cortical_area)
	brain_region.subregion_added_to_region.connect(_add_region)
	#NOTE: We do not have to worry about the region this object represents in this code, since the left side InternalsView will send out a signal that will result in closing this view


func reset_to_blank() -> void:
	_representing_region = null
	_internal_regions = {}
	_internal_cortical_areas = {}
	for child in _container.get_children():
		child.queue_free()

func set_toggle(object: GenomeObject, is_on: bool) -> void:
	if object is AbstractCorticalArea:
		if !object.genome_ID in _internal_cortical_areas:
			push_error("UI: Unable to find area %s to toggle!" % object.genome_ID)
			return
		(_internal_cortical_areas[object.cortical_ID] as ScrollRegionInternalsViewItem).set_checkbox_check(is_on)
		return
	if object is BrainRegion:
		if !object.genome_ID in _internal_regions:
			push_error("UI: Unable to find region %s to toggle!" % object.genome_ID)
			return
		(_internal_regions[object.genome_ID] as ScrollRegionInternalsViewItem).set_checkbox_check(is_on)
		return

func filter_by_name(friendly_name: StringName) -> void:
	if friendly_name == "":
		_show_all_allowed()
		return
	
	for item: ScrollRegionInternalsViewItem  in _internal_regions.values():
		if !_view_config.is_region_shown(item.target as BrainRegion):
			item.visible = false
			continue
		item.visible = (item.target as BrainRegion).contains_any_object_with_friendly_name_containing_substring_recursive(friendly_name) or item.target.friendly_name.to_lower().contains(friendly_name.to_lower())
	
	for item: ScrollRegionInternalsViewItem  in _internal_cortical_areas.values():
		if !_view_config.is_cortical_area_shown(item.target as AbstractCorticalArea):
			item.visible = false
			continue
		item.visible = item.target.friendly_name.contains(friendly_name)

func get_existing_internals() -> Array[GenomeObject]:
	if _representing_region == null:
		# This only occurs on the view holding a root region, as it has no parent
		return [FeagiCore.feagi_local_cache.brain_regions.get_root_region()]
	return _representing_region.get_all_included_genome_objects()

func _add_region(region: BrainRegion, is_preselected: bool = false) -> void:
	if region.region_ID in _internal_regions:
		push_error("UI: Unable to add region %s to ScrollRegionInternalView of region %s as it already exists!" % [region.region_ID, _representing_region.region_ID])
		return
	var item: ScrollRegionInternalsViewItem =  LIST_ITEM_PREFAB.instantiate()
	_container.add_child(item)
	item.setup_region(region)
	item.background_clicked.connect(_region_expansion_proxy)
	
	if !_view_config.is_region_disabled(region):
		item.disable_checkbox_button(false)
		item.checkbox_clicked.connect(_object_selection_proxy)
	else:
		item.disable_checkbox_button(true)
	_internal_regions[region.region_ID] = item
	
	if is_preselected:
		item.set_checkbox_check(true)
	
	if !_multiselect_enabled:
		item.set_to_radio_button_mode()
		
	item.visible = _view_config.is_region_shown(region)

func _add_cortical_area(area: AbstractCorticalArea, is_preselected: bool = false) -> void:
	if area.cortical_ID in _internal_cortical_areas:
		push_error("UI: Unable to add area %s to ScrollRegionInternalView of region %s as it already exists!" % [area.cortical_ID, _representing_region.region_ID])
		return
	var item: ScrollRegionInternalsViewItem =  LIST_ITEM_PREFAB.instantiate()
	_container.add_child(item)
	item.setup_cortical_area(area)
	if !_view_config.is_cortical_area_disabled(area):
		item.disable_checkbox_button(false)
		item.checkbox_clicked.connect(_object_selection_proxy)
	else:
		item.disable_checkbox_button(true)
	_internal_cortical_areas[area.cortical_ID] = item
	
	if is_preselected:
		item.set_checkbox_check(true)
		
	if !_multiselect_enabled:
		item.set_to_radio_button_mode()
	
	item.visible = _view_config.is_cortical_area_shown(area)

func _remove_cortical_area(area: AbstractCorticalArea) -> void:
	if !(area.cortical_ID in _internal_cortical_areas):
		push_error("UI: Unable to remove area %s to ScrollRegionInternalView of region %s as it doesn't exist in this list!" % [area.cortical_ID, _representing_region.region_ID])
		return
	_internal_cortical_areas[area.cortical_ID].queue_free()
	_internal_cortical_areas.erase(area.cortical_ID)

func _region_expansion_proxy(region: BrainRegion) -> void:
	region_expansion_attempted.emit(region, self)

func _object_selection_proxy(object: GenomeObject, is_selected: bool) -> void:
	genome_object_toggled.emit(object, is_selected, self)

func _show_all_allowed() -> void:
	for item: ScrollRegionInternalsViewItem  in _internal_regions.values():
		if _view_config.is_region_shown(item.target):
			item.visible = true

	for item: ScrollRegionInternalsViewItem  in _internal_cortical_areas.values():
		if _view_config.is_cortical_area_shown(item.target):
			item.visible = true
		
