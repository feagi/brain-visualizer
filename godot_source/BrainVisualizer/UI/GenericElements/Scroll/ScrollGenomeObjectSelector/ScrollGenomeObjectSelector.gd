extends ScrollContainer
class_name ScrollGenomeObjectSelector

const PREFAB_SCROLLREGIONVIEW: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollGenomeObjectSelector/ScrollRegionInternalsView/ScrollRegionInternalsView.tscn")

signal region_selected(region: BrainRegion)
signal area_selected(area: BaseCorticalArea)
 # ScrollRegionInternalsView

var last_selected_region: BrainRegion:
	get: return _last_selected_region

var last_selected_area: BaseCorticalArea:
	get: return _last_selected_area

var _last_selected_region: BrainRegion
var _last_selected_area: BaseCorticalArea
var _starting_region: BrainRegion
var _views: Array[ScrollRegionInternalsView] = []
var _container: HBoxContainer

func _ready():
	_container = $HBoxContainer

func reset_to_empty() -> void:
	_close_to_the_right_of(0)

func setup_from_starting_region(starting_region: BrainRegion) -> void:
	reset_to_empty()
	_add_view(starting_region)

## Close all views right of the given index (inclusive)
func _close_to_the_right_of(last_to_close: int) -> void:
	while len(_views) > last_to_close:
		var view: ScrollRegionInternalsView = _views.pop_back()
		view.queue_free()

func _add_view(region: BrainRegion) -> void:
	var scene: ScrollRegionInternalsView = PREFAB_SCROLLREGIONVIEW.instantiate()
	_container.add_child(scene)
	_views.append(scene)
	scene.setup(region)
	scene.clicked_region.connect(_user_selected_region)
	scene.clicked_cortical_area.connect(_user_selected_cortical_area)

func _user_selected_region(region: BrainRegion, from_view: ScrollRegionInternalsView) -> void:
	var index: int = _views.find(from_view)
	if index == -1:
		push_error("UI: Unable to find the View to selected region %s" % region.ID)
		return
	_last_selected_region = region
	region_selected.emit(region)
	_close_to_the_right_of(index + 1)
	_add_view(region)

func _user_selected_cortical_area(area: BaseCorticalArea, from_view: ScrollRegionInternalsView) -> void:
	_last_selected_area = area
	var index: int = _views.find(from_view)
	if index == -1:
		push_error("UI: Unable to find the View")
		return
	area_selected.emit(area)
	_close_to_the_right_of(index + 1)
