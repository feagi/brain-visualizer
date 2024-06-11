extends PanelContainer
class_name ScrollRegionInternalsView

const LIST_ITEM_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollGenomeObjectSelector/ScrollRegionInternalsView/ScrollRegionInternalsViewItem.tscn")

signal clicked_cortical_area(area: AbstractCorticalArea, self_reference: ScrollRegionInternalsView)
signal clicked_region(region: BrainRegion, self_reference: ScrollRegionInternalsView)
signal selected_object_removed(removed: GenomeObject, self_reference: ScrollRegionInternalsView)

var selected_object: GenomeObject:
	get: return _selected_object

var _representing_region: BrainRegion
var _internal_regions: Dictionary
var _internal_cortical_areas: Dictionary
var _selected_object: GenomeObject

var _container: VBoxContainer

func _ready():
	_container = $Scroll/VBoxContainer

func setup(brain_region: BrainRegion) -> void:
	_representing_region = brain_region
	for region in brain_region.contained_regions:
		_add_region(region)
	for area in brain_region.contained_cortical_areas:
		_add_cortical_area(area)
	brain_region.cortical_area_added_to_region.connect(_add_cortical_area)
	brain_region.cortical_area_removed_from_region.connect(_remove_cortical_area)
	brain_region.subregion_added_to_region.connect(_add_region)
	brain_region.subregion_removed_from_region.connect(_remove_region)
	#NOTE: We do not have to worry about the region this object represents in this code, since the left side InternalsView will send out a signal that will result in closing this view

func setup_blank() -> void:
	reset_to_blank()

func reset_to_blank() -> void:
	_representing_region = null
	_selected_object = null
	_internal_regions = {}
	_internal_cortical_areas = {}
	for child in _container.get_children():
		child.queue_free()

func _add_region(region: BrainRegion) -> void:
	if region.region_ID in _internal_regions:
		push_error("UI: Unable to add region %s to ScrollRegionInternalView of region %s as it already exists!" % [region.region_ID, _representing_region.region_ID])
		return
	var item: ScrollRegionInternalsViewItem =  LIST_ITEM_PREFAB.instantiate()
	_container.add_child(item)
	item.setup_region(region)
	item.user_clicked.connect(_region_selected)
	_internal_regions[region.region_ID] = item

func _add_cortical_area(area: AbstractCorticalArea) -> void:
	if area.cortical_ID in _internal_cortical_areas:
		push_error("UI: Unable to add area %s to ScrollRegionInternalView of region %s as it already exists!" % [area.cortical_ID, _representing_region.region_ID])
		return
	var item: ScrollRegionInternalsViewItem =  LIST_ITEM_PREFAB.instantiate()
	_container.add_child(item)
	item.setup_cortical_area(area)
	item.user_clicked.connect(_area_selected)
	_internal_cortical_areas[area.cortical_ID] = item

func _remove_region(region: BrainRegion) -> void:
	if !(region.region_ID in _internal_regions):
		push_error("UI: Unable to remove region %s to ScrollRegionInternalView of region %s as it doesn't exist in this list!" % [region.region_ID, _representing_region.region_ID])
		return
	_internal_regions[region.region_ID].queue_free()
	_internal_regions.erase(region.region_ID)
	if region == _selected_object:
		selected_object_removed.emit(region, self)

func _remove_cortical_area(area: AbstractCorticalArea) -> void:
	if !(area.cortical_ID in _internal_cortical_areas):
		push_error("UI: Unable to remove area %s to ScrollRegionInternalView of region %s as it doesn't exist in this list!" % [area.cortical_ID, _representing_region.region_ID])
		return
	_internal_cortical_areas[area.cortical_ID].queue_free()
	_internal_cortical_areas.erase(area.cortical_ID)
	if area == _selected_object:
		selected_object_removed.emit(area, self)

func _region_selected(region: BrainRegion) -> void:
	_selected_object = region
	clicked_region.emit(region, self)

func _area_selected(area: AbstractCorticalArea) -> void:
	_selected_object = area
	clicked_cortical_area.emit(area, self)
