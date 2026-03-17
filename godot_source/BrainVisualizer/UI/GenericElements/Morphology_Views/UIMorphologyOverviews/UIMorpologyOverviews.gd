extends HBoxContainer
class_name UIMorphologyOverviews

signal request_close()
signal requested_updating_morphology(morphology_name: StringName)

@export var enable_add_morphology_button: bool = true
@export var enable_update_morphology_button: bool = true
@export var enable_delete_morphology_button: bool = true
@export var enable_close_button: bool = true
@export var morphology_properties_editable: bool = true
@export var controls_to_scale_by_min_size: Array[Control]

var loaded_morphology: BaseMorphology:
	get: return _loaded_morphology

var _add_morphology_button: Button
var _morphology_scroll: MorphologyScroll
var _morphology_name_edit: LineEdit
var _UI_morphology_definition: UIMorphologyDefinition
var _UI_morphology_image: UIMorphologyImage
var _UI_morphology_usage: UIMorphologyUsage
var _UI_morphology_description: UIMorphologyDescription
var _UI_morphology_delete_button: UIMorphologyDeleteButton
var _close_button: Button
var _update_morphology_button: Button
var _custom_minimum_size_scalar: ScalingCustomMinimumSize

var _no_name_text: StringName
var _loaded_morphology: BaseMorphology
var _skip_next_focus_revert: bool = false

func _ready() -> void:
	# Get references
	_add_morphology_button = $Listings/AddMorphology
	_morphology_scroll = $Listings/MorphologyScroll
	_morphology_name_edit = $SelectedDetails/HBoxContainer/Name
	_morphology_name_edit.text_submitted.connect(_on_morphology_name_submitted)
	_morphology_name_edit.focus_exited.connect(_on_morphology_name_focus_exited)
	_UI_morphology_definition = $SelectedDetails/Details/MarginContainer/VBoxContainer/HBoxContainer/PanelContainer/SmartMorphologyView
	_UI_morphology_image = $SelectedDetails/Details/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/UIMorphologyImage
	_UI_morphology_usage = $SelectedDetails/Details/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/UIMorphologyUsage
	_UI_morphology_description = $SelectedDetails/Details/MarginContainer/VBoxContainer/UIMorphologyDescription
	_UI_morphology_delete_button = $SelectedDetails/Details/MarginContainer/VBoxContainer/Buttons/Delete
	_close_button = $SelectedDetails/Details/MarginContainer/VBoxContainer/Buttons/Close
	_update_morphology_button = $SelectedDetails/Details/MarginContainer/VBoxContainer/Buttons/Close
	
	_add_morphology_button.visible = enable_add_morphology_button
	_UI_morphology_delete_button.visible = enable_delete_morphology_button
	_close_button.visible = enable_close_button
	_update_morphology_button.visible = enable_update_morphology_button
	_UI_morphology_definition.editing_allowed_from_this_window = morphology_properties_editable
	_no_name_text = _morphology_name_edit.placeholder_text
	_custom_minimum_size_scalar = ScalingCustomMinimumSize.new(controls_to_scale_by_min_size)
	_custom_minimum_size_scalar.theme_updated(BV.UI.loaded_theme)
	BV.UI.theme_changed.connect(_custom_minimum_size_scalar.theme_updated)
	
func load_morphology(morphology: BaseMorphology, override_scroll_selection: bool = false) -> void:
	_loaded_morphology = morphology
	if morphology is NullMorphology:
		_morphology_name_edit.text = ""
		_morphology_name_edit.placeholder_text = _no_name_text
		_morphology_name_edit.editable = false
		_morphology_name_edit.tooltip_text = ""
	else:
		_morphology_name_edit.text = morphology.name
		_morphology_name_edit.placeholder_text = _no_name_text
		var is_custom: bool = morphology.internal_class == BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CUSTOM
		_morphology_name_edit.editable = is_custom
		_morphology_name_edit.tooltip_text = "Edit name and press Enter or click Update to rename" if is_custom else "Core connectivity rules cannot be renamed"
	_UI_morphology_definition.load_morphology(morphology)
	_UI_morphology_image.load_morphology(morphology)
	_UI_morphology_usage.load_morphology(morphology)
	_UI_morphology_description.load_morphology(morphology)
	_UI_morphology_delete_button.load_morphology(morphology)
	if override_scroll_selection:
		_morphology_scroll.select_morphology(morphology)
	
	# Scroll already requests a property refresh on selection, but since we use usages, lets also refresh usage information
	if !(morphology is NullMorphology):
		FeagiCore.requests.get_morphology_usage(morphology.name)
	size = Vector2i(0,0) # Force shrink to minimum possible size

func _user_requested_update_morphology() -> void:
	_skip_next_focus_revert = true
	if !_loaded_morphology or _loaded_morphology is NullMorphology:
		return
	var name_trimmed: String = _morphology_name_edit.text.strip_edges()
	var is_name_change: bool = name_trimmed != String(_loaded_morphology.name) and !name_trimmed.is_empty()
	var is_custom: bool = _loaded_morphology.internal_class == BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CUSTOM
	if is_name_change and is_custom:
		_rename_then_update_parameters(name_trimmed)
		return
	BV.NOTIF.add_notification("Requesting FEAGI to update Connectivity rule %s" % _loaded_morphology.name)
	_UI_morphology_definition.request_feagi_apply_morphology_settings(_loaded_morphology.name)

func _rename_then_update_parameters(new_name: String) -> void:
	var result: FeagiRequestOutput = await FeagiCore.requests.rename_morphology(_loaded_morphology.name, new_name)
	if result.has_errored:
		BV.NOTIF.add_notification("Failed to rename connectivity rule: %s" % result.failure_reason)
		_morphology_name_edit.text = _loaded_morphology.name
		return
	BV.NOTIF.add_notification("Renamed connectivity rule to %s" % new_name)
	_loaded_morphology = FeagiCore.feagi_local_cache.morphologies.try_get_morphology_object(new_name)
	if _loaded_morphology:
		BV.NOTIF.add_notification("Requesting FEAGI to update Connectivity rule %s" % _loaded_morphology.name)
		_UI_morphology_definition.request_feagi_apply_morphology_settings(_loaded_morphology.name)
		load_morphology(_loaded_morphology, true)

func repopulate_morphology_list() -> void:
	_morphology_scroll.repopulate_from_cache()

func _user_request_create_morphology() -> void:
	BV.WM.spawn_create_morphology()

func _user_requested_closing() -> void:
	request_close.emit()

func _user_request_delete_morphology() -> void:
	if _loaded_morphology == null:
		return
	FeagiCore.requests.delete_morphology(_loaded_morphology)

func _user_selected_morphology_from_scroll(morphology) -> void:
	load_morphology(morphology)

func _on_morphology_name_focus_exited() -> void:
	# Defer revert so that clicking Update (which steals focus) does not wipe the user's edit before the handler runs.
	if _loaded_morphology and !(_loaded_morphology is NullMorphology):
		call_deferred("_deferred_revert_name_if_not_submitted")

func _deferred_revert_name_if_not_submitted() -> void:
	if _skip_next_focus_revert:
		_skip_next_focus_revert = false
		return
	if _loaded_morphology and !(_loaded_morphology is NullMorphology) and _morphology_name_edit.text != String(_loaded_morphology.name):
		_morphology_name_edit.text = _loaded_morphology.name

func _on_morphology_name_submitted(new_name: String) -> void:
	_skip_next_focus_revert = true
	if _loaded_morphology == null or _loaded_morphology is NullMorphology:
		return
	if _loaded_morphology.internal_class == BaseMorphology.MORPHOLOGY_INTERNAL_CLASS.CORE:
		return
	var trimmed: String = new_name.strip_edges()
	if trimmed.is_empty():
		_morphology_name_edit.text = _loaded_morphology.name
		return
	if trimmed == String(_loaded_morphology.name):
		return
	_rename_morphology_async(trimmed)

func _rename_morphology_async(new_name: String) -> void:
	var result: FeagiRequestOutput = await FeagiCore.requests.rename_morphology(_loaded_morphology.name, new_name)
	if result.has_errored:
		BV.NOTIF.add_notification("Failed to rename connectivity rule: %s" % result.failure_reason)
		_morphology_name_edit.text = _loaded_morphology.name
		return
	BV.NOTIF.add_notification("Renamed connectivity rule to %s" % new_name)
	_loaded_morphology = FeagiCore.feagi_local_cache.morphologies.try_get_morphology_object(new_name)
	if _loaded_morphology:
		load_morphology(_loaded_morphology, true)
