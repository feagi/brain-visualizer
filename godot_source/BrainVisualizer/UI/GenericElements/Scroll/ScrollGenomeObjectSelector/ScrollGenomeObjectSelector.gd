extends ScrollContainer
class_name ScrollGenomeObjectSelector

const PREFAB_SCROLLREGIONVIEW: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Scroll/ScrollGenomeObjectSelector/ScrollRegionInternalsView/ScrollRegionInternalsView.tscn")
const ScenePick = preload("res://BrainVisualizer/UI/Windows/SelectGenomeObject/CorticalExplorerScenePick.gd")


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

func reset_views() -> void:
	for child in _container.get_children():
		queue_free() # get rid of any stranglers
	
func setup_from_starting_region(settings: SelectGenomeObjectSettings) -> void:
	_view_config = settings
	_selected_objects = _view_config.preselected_objects
	_multiselect_enabled = _view_config.is_multiselect_allowed()
	var scene: ScrollRegionInternalsView = PREFAB_SCROLLREGIONVIEW.instantiate()
	_container.add_child(scene)
	_views.append(scene)
	scene.setup_first(_view_config.starting_region, _view_config, _selected_objects)
	scene.region_expansion_attempted.connect(_user_expanding_region)
	scene.genome_object_toggled.connect(_user_selected_object)
	# Auto-expand the root region so children are visible by default.
	if _view_config.starting_region != null and _view_config.starting_region.is_root_region():
		_user_expanding_region(_view_config.starting_region, scene)

#TODO improve
func apply_name_filter(filter: StringName) -> void:
	for view in _views:
		view.filter_by_name(filter)

func _user_expanding_region(region: BrainRegion, from_view: ScrollRegionInternalsView) -> void:
	var index: int = _views.find(from_view)
	if index == -1:
		push_error("UI: Unable to find the View to selected region %s" % region.ID)
		return
	_close_to_the_right_of(index + 1)
	var scene: ScrollRegionInternalsView = PREFAB_SCROLLREGIONVIEW.instantiate()
	_container.add_child(scene)
	_views.append(scene)
	scene.setup_rest(region, _view_config, _selected_objects)
	scene.region_expansion_attempted.connect(_user_expanding_region)
	scene.genome_object_toggled.connect(_user_selected_object)

## Close all views right of the given index (inclusive)
func _close_to_the_right_of(last_to_close: int) -> void:
	while len(_views) > last_to_close:
		var view: ScrollRegionInternalsView = _views.pop_back()
		view.queue_free()

## Checks objects the user picked with the mouse in the 3D view.
## Single-select replaces the current choice. Multi-select adds each eligible object.
func apply_mouse_pick(objects: Array[GenomeObject]) -> void:
	var eligible: Array[GenomeObject] = []
	for object in objects:
		if _can_choose(object):
			eligible.append(object)
	if eligible.is_empty():
		return
	if ScenePick.replaces_existing_choices(_multiselect_enabled):
		_set_membership(eligible[0], true)
		return
	for object in eligible:
		_set_membership(object, true)

func _can_choose(object: GenomeObject) -> bool:
	if _view_config == null or object == null:
		return false
	if object is AbstractCorticalArea:
		var area: AbstractCorticalArea = object as AbstractCorticalArea
		return ScenePick.is_chooser_eligible(
			true,
			false,
			_view_config.is_cortical_area_shown(area),
			_view_config.is_cortical_area_disabled(area),
		)
	if object is BrainRegion:
		var region: BrainRegion = object as BrainRegion
		return ScenePick.is_chooser_eligible(
			false,
			true,
			_view_config.is_region_shown(region),
			_view_config.is_region_disabled(region),
		)
	return false

func has_selected_id(object: GenomeObject) -> bool:
	if object == null:
		return false
	if object in _selected_objects:
		return true
	if object is AbstractCorticalArea:
		var area_id: StringName = (object as AbstractCorticalArea).cortical_ID
		for selected in _selected_objects:
			if selected is AbstractCorticalArea and (selected as AbstractCorticalArea).cortical_ID == area_id:
				return true
	if object is BrainRegion:
		var region_id: StringName = (object as BrainRegion).region_ID
		for selected in _selected_objects:
			if selected is BrainRegion and (selected as BrainRegion).region_ID == region_id:
				return true
	return false

## Opens the circuit columns that contain [param object] and sets its checkbox.
func _set_membership(object: GenomeObject, is_on: bool) -> void:
	if is_on == has_selected_id(object):
		_reveal(object)
		return
	if is_on and not _reveal(object):
		return
	if not is_on:
		_reveal(object)
	var view: ScrollRegionInternalsView = _direct_view(object)
	if view != null:
		_user_selected_object(object, is_on, view)
		return
	if is_on:
		_selected_objects.append(object)
		object_added.emit(object)
		return
	var index: int = _selected_objects.find(object)
	if index != -1:
		_selected_objects.remove_at(index)
		object_removed.emit(object)

func _reveal(object: GenomeObject) -> bool:
	var open_view: ScrollRegionInternalsView = _direct_view(object)
	if open_view != null:
		open_view.focus_object(object)
		_scroll_view_into_sight(open_view)
		return true
	var chain: Array[BrainRegion] = _regions_to_expand(object)
	if chain.is_empty():
		return false
	for region in chain:
		if not _expand_region(region):
			return false
	var shown: ScrollRegionInternalsView = _direct_view(object)
	if shown == null:
		return false
	shown.focus_object(object)
	_scroll_view_into_sight(shown)
	return true

## Circuits from the explorer's start region through the parent that lists [param object].
func _regions_to_expand(object: GenomeObject) -> Array[BrainRegion]:
	if object == _view_config.starting_region:
		return []
	var chain: Array[BrainRegion] = []
	var cursor: BrainRegion = object.current_parent_region
	var guard: int = 0
	while cursor != null and guard < 64:
		chain.push_front(cursor)
		if _same_region(cursor, _view_config.starting_region):
			return chain
		cursor = cursor.current_parent_region
		guard += 1
	return []

func _same_region(a: BrainRegion, b: BrainRegion) -> bool:
	if a == null or b == null:
		return false
	return a.region_ID == b.region_ID

func _expand_region(region: BrainRegion) -> bool:
	for view in _views:
		if _same_region(view.representing_region, region):
			return true
	for view in _views:
		if view.has_direct(region):
			_user_expanding_region(region, view)
			return true
	return false

func _direct_view(object: GenomeObject) -> ScrollRegionInternalsView:
	for view in _views:
		if view.has_direct(object):
			return view
	return null

func _scroll_view_into_sight(view: ScrollRegionInternalsView) -> void:
	if view == null:
		return
	call_deferred("_deferred_scroll_to", view)

func _deferred_scroll_to(view: ScrollRegionInternalsView) -> void:
	if is_instance_valid(view):
		ensure_control_visible(view)

func _user_selected_object(genome_object: GenomeObject, is_on: bool, from_view: ScrollRegionInternalsView) -> void:
	if !_multiselect_enabled:
		if len(_selected_objects) != 0:
			# Deselect previous object
			var previous_object: GenomeObject = _selected_objects[0]
			_selected_objects = []
			object_removed.emit(previous_object)
			# object_added called later
			for view in _views:
				if view.has_direct(previous_object):
					view.set_toggle(previous_object, false)
					break
	
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

