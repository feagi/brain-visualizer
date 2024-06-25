extends ScrollContainer
class_name ScrollGenomeObjectSelector

const PREFAB_SCROLLREGIONVIEW: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollGenomeObjectSelector/ScrollRegionInternalsView/ScrollRegionInternalsView.tscn")

signal object_added(genome_object: GenomeObject)
signal object_removed(genome_object: GenomeObject)

var selected_objects: Array[GenomeObject]:
	get: return _selected_objects

var _selected_objects: Array[GenomeObject]
var _multiselect_enabled: bool
var _view_config: SelectGenomeObjectSettings
var _starting_region: BrainRegion
var _views: Array[ScrollRegionInternalsView] = []
var _container: HBoxContainer

func _ready():
	_container = $HBoxContainer

func reset() -> void:
	for child in get_children():
		queue_free() # get rid of any stranglers
	
func setup_from_starting_region(settings: SelectGenomeObjectSettings) -> void:
	reset()
	_view_config = settings
	_multiselect_enabled = _view_config.multiselect_allowed()
	_add_starter_view(_view_config.starting_region)

#TODO improve
func apply_name_filter(filter: StringName) -> void:
	for view in _views:
		view.filter_by_name(filter)


func _add_starter_view(region: BrainRegion) -> void:
	var scene: ScrollRegionInternalsView = PREFAB_SCROLLREGIONVIEW.instantiate()
	_container.add_child(scene)
	_views.append(scene)
	scene.setup_as_first(region)
	scene.region_expansion_attempted.connect(_user_expanding_region)

func _user_expanding_region(region: BrainRegion, from_view: ScrollRegionInternalsView) -> void:
	var index: int = _views.find(from_view)
	if index == -1:
		push_error("UI: Unable to find the View to selected region %s" % region.ID)
		return
	_close_to_the_right_of(index)
	var scene: ScrollRegionInternalsView = PREFAB_SCROLLREGIONVIEW.instantiate()
	_container.add_child(scene)
	_views.append(scene)
	scene.setup(region, _view_config, _selected_objects)
	scene.region_expansion_attempted.connect(_user_expanding_region)

## Close all views right of the given index (inclusive)
func _close_to_the_right_of(last_to_close: int) -> void:
	while len(_views) > last_to_close:
		var view: ScrollRegionInternalsView = _views.pop_back()
		view.queue_free()

func _user_selected_object(genome_object: GenomeObject, is_on: bool, from_view: ScrollRegionInternalsView) -> void:
	if !_multiselect_enabled:
		object_removed.emit(_selected_objects[0])
		for view in _views:
			if view.representing_region.is_genome_object_in_region_directly(genome_object):
				view.set_toggle(genome_object, false)
				break
		_selected_objects = []
	
	from_view.set_toggle(genome_object, is_on)
	if is_on:
		if genome_object in _selected_objects:
			return
		_selected_objects.append(genome_object)
		object_added.emit(genome_object)
	else:
		var index: int = _selected_objects.find(genome_object)
		if index != -1:
			_selected_objects.remove_at(index)
			object_removed.emit(genome_object)
