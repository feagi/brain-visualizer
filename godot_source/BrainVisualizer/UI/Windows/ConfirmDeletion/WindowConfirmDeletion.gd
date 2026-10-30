extends BaseDraggableWindow
class_name WindowConfirmDeletion

const WINDOW_NAME: StringName = "confirm_deletion"

var _label: Label
var _deletion_targets: Array[GenomeObject]
var _is_deleting_internals: bool
var _mode: GenomeObject.ARRAY_MAKEUP
var _scroll: ScrollSectionGeneric
var _delete_in_progress: bool = false

## Configure confirmation dialog text and targets.
func setup(selection: Array[GenomeObject], region_deleting_internals: bool = false) -> void:
	_label = _window_internals.get_node("DeleteText")
	_scroll = _window_internals.get_node("ScrollSectionGeneric")
	var cancel_button: Button = _window_internals.get_node("HBoxContainer/No")
	var confirm_button: Button = _window_internals.get_node("HBoxContainer/Yes")
	# Keep button labels consistent with confirmation intent.
	cancel_button.text = "Cancel"
	confirm_button.text = "Confirm"
	cancel_button.tooltip_text = "Close this window without deleting anything."
	confirm_button.tooltip_text = "Permanently delete the objects listed here in FEAGI. Pressing Enter does the same."
	_deletion_targets = selection
	_is_deleting_internals = region_deleting_internals
	_mode = GenomeObject.get_makeup_of_array(selection)
	_setup_base_window(WINDOW_NAME)
	match _mode:
		GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA:
			_label.text = "Are you sure you wish to delete cortical area %s?" % selection[0].friendly_name
			_scroll.visible = false
		GenomeObject.ARRAY_MAKEUP.SINGLE_CLASSIFIER:
			_label.text = "Are you sure you wish to delete classifier %s and its owned internals?" % selection[0].friendly_name
			_scroll.visible = false
		GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
			var internals: Array[GenomeObject] = (selection[0] as BrainRegion).get_all_included_genome_objects()
			if internals.is_empty():
				_scroll.visible = false
			else:
				_scroll_show_objects(internals)
				var toggle: CheckBox = _window_internals.get_node("DeleteInternalsToggle")
				toggle.visible = true
				toggle.set_pressed_no_signal(region_deleting_internals)
				if not toggle.toggled.is_connected(_on_delete_internals_toggled):
					toggle.toggled.connect(_on_delete_internals_toggled)
			_update_region_label()
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS:
			_label.text = "Are you sure you wish to delete %d cortical areas?" % len(selection)
			_scroll_show_objects(selection)
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS:
			_label.text = "Are you sure you wish to delete %d neural circuits and their internals?" % len(selection)
			_scroll_show_objects(selection)
		GenomeObject.ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS:
			_label.text = "Are you sure you wish to delete %d objects and their internals?" % len(selection)
			_scroll_show_objects(selection)
		_:
			push_error("UI: Unknown deletion target for deletion confirmation window! Closing!")
			close_window()
	set_process_unhandled_key_input(true)

## Rewrites the single-circuit label for the current delete-internals choice.
func _update_region_label() -> void:
	var region: BrainRegion = _deletion_targets[0] as BrainRegion
	var count: int = region.get_all_included_genome_objects().size()
	if _is_deleting_internals:
		_label.text = "Are you sure you wish to delete neural circuit %s with these %d internals?" % [region.friendly_name, count]
	else:
		# raising internals instead
		_label.text = "Are you sure you wish to delete neural circuit %s and raise its %d internals to the parent circuit %s?" % [region.friendly_name, count, region.current_parent_region.friendly_name]

func _on_delete_internals_toggled(pressed: bool) -> void:
	_is_deleting_internals = pressed
	_update_region_label()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			_yes_pressed()
		elif key.keycode == KEY_ESCAPE:
			_no_pressed()

func _scroll_show_objects(objects: Array[GenomeObject]) -> void:
	for object in objects:
		_scroll.add_text_button(object, object.friendly_name, Callable())

func _yes_pressed() -> void:
	if _delete_in_progress:
		return
	_delete_in_progress = true
	var deleted := true
	match _mode:
		GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA, GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS:
			deleted = await _delete_areas_with_history(GenomeObject.filter_cortical_areas(_deletion_targets))
		GenomeObject.ARRAY_MAKEUP.SINGLE_CLASSIFIER:
			FeagiCore.requests.delete_classifier(_deletion_targets[0] as GenomeClassifier)
		GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
			var single_region: BrainRegion = _deletion_targets[0] as BrainRegion
			deleted = await _delete_regions([single_region], _is_deleting_internals)
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS:
			# Dialog says "and their internals", so delete members too.
			deleted = await _delete_regions(GenomeObject.filter_brain_regions(_deletion_targets), true)
		GenomeObject.ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS:
			var cortical_areas: Array[AbstractCorticalArea] = GenomeObject.filter_cortical_areas(_deletion_targets)
			if not cortical_areas.is_empty():
				deleted = await _delete_areas_with_history(cortical_areas)
			if deleted:
				deleted = await _delete_regions(GenomeObject.filter_brain_regions(_deletion_targets), true)
		_:
			push_warning("UI: ConfirmDeletion received unsupported mode %s." % _mode)
	_delete_in_progress = false
	if deleted:
		close_window()


## Deletes regions one by one. [param with_internals] true deletes members too; false raises them to the parent.
## Regions already removed by an earlier delete in this batch (nested selections) are skipped. Returns false on the first failure.
func _delete_regions(regions: Array[BrainRegion], with_internals: bool) -> bool:
	for region in regions:
		if not is_instance_valid(region) or not (region.region_ID in FeagiCore.feagi_local_cache.brain_regions.available_brain_regions):
			continue
		var result: FeagiRequestOutput
		if with_internals:
			result = await FeagiCore.requests.delete_region_and_internals(region)
		else:
			result = await FeagiCore.requests.delete_regions_and_raise_internals(region)
		if result == null or result.has_errored or not result.success or result.failed_requirement:
			BV.NOTIF.add_notification("Delete failed", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
			return false
	return true


## Snapshots restorable areas, deletes them, and records one undo step when FEAGI accepts the delete.
func _delete_areas_with_history(areas: Array[AbstractCorticalArea]) -> bool:
	var edit: DeleteAreaEdit = await DeleteAreaApplier.capture(areas)
	if edit == null:
		BV.NOTIF.add_notification("Could not read the area before deleting it.", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return false
	if edit.area_count() < areas.size():
		BV.NOTIF.add_notification("Some deleted areas cannot be recreated, so they were left out of undo.")
	var result: FeagiRequestOutput
	if areas.size() == 1:
		result = await FeagiCore.requests.delete_cortical_area(areas[0])
	else:
		result = await FeagiCore.requests.mass_delete_cortical_areas(areas)
	if result == null or result.has_errored or not result.success or result.failed_requirement:
		BV.NOTIF.add_notification("Delete failed", NotificationSystemNotification.NOTIFICATION_TYPE.ERROR)
		return false
	BV.UI.record_genome_edit(edit)
	return true

func _no_pressed() -> void:
	close_window()
