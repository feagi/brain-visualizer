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

const MORPHOLOGY_UPDATE_WARNING_POPUP_MIN_SIZE: Vector2i = Vector2i(640, 420)

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
	_request_morphology_update_with_warning(_loaded_morphology.name)

func _rename_then_update_parameters(new_name: String) -> void:
	var result: FeagiRequestOutput = await FeagiCore.requests.rename_morphology(_loaded_morphology.name, new_name)
	if !result.success:
		var error_details: PackedStringArray = result.decode_response_as_generic_error_code()
		BV.NOTIF.add_notification("Failed to rename connectivity rule: %s" % error_details[1])
		_morphology_name_edit.text = _loaded_morphology.name
		return
	BV.NOTIF.add_notification("Renamed connectivity rule to %s" % new_name)
	_loaded_morphology = FeagiCore.feagi_local_cache.morphologies.try_get_morphology_object(new_name)
	if _loaded_morphology:
		_request_morphology_update_with_warning(_loaded_morphology.name)
		load_morphology(_loaded_morphology, true)

func _request_morphology_update_with_warning(morphology_name: StringName) -> void:
	var usage_result: FeagiRequestOutput = await FeagiCore.requests.get_morphology_usage(morphology_name)
	if !usage_result.success:
		var error_details: PackedStringArray = usage_result.decode_response_as_generic_error_code()
		BV.NOTIF.add_notification(
			"Unable to validate impacted mappings for connectivity rule %s: %s"
			% [morphology_name, error_details[1]]
		)
		return

	if !_loaded_morphology or _loaded_morphology is NullMorphology:
		return

	var usage: Array[PackedStringArray] = _loaded_morphology.latest_known_usage_by_cortical_area
	if usage.is_empty():
		_confirm_apply_morphology_update(morphology_name)
		return

	var warning_message: String = _build_morphology_update_warning_message(morphology_name, usage)
	var confirm_action: Callable = _confirm_apply_morphology_update.bind(morphology_name)
	var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_cancel_and_action_popup(
		"Confirm Connectivity Rule Update",
		warning_message,
		confirm_action,
		"Update All Mappings",
		"Cancel",
		MORPHOLOGY_UPDATE_WARNING_POPUP_MIN_SIZE
	)
	var popup_window: WindowConfigurablePopup = BV.WM.spawn_popup(popup_definition)
	popup_window.set_enter_confirms_button("Update All Mappings")
	popup_window.call_deferred("focus_button_with_text", "Update All Mappings")

func _confirm_apply_morphology_update(morphology_name: StringName) -> void:
	BV.NOTIF.add_notification("Requesting FEAGI to update Connectivity rule %s" % morphology_name)
	_UI_morphology_definition.request_feagi_apply_morphology_settings(morphology_name)

func _build_morphology_update_warning_message(
	morphology_name: StringName,
	usage: Array[PackedStringArray]
) -> String:
	var usage_lines: PackedStringArray = []
	for single_mapping in usage:
		usage_lines.append(_mapping_usage_to_text(single_mapping))
	var usage_list: String = "- " + "\n- ".join(usage_lines)
	return (
		"Connectivity rule '%s' is used by %d cortical mapping(s).\n"
		+ "Applying this update will regenerate all synapses for each mapping below.\n"
		+ "This operation can be expensive for large brains.\n\n"
		+ "Impacted mappings:\n%s"
	) % [morphology_name, usage.size(), usage_list]

func _mapping_usage_to_text(mapping: PackedStringArray) -> String:
	if mapping.size() < 2:
		return "UNKNOWN -> UNKNOWN"

	var source_name: String = _friendly_cortical_name(mapping[0])
	var destination_name: String = _friendly_cortical_name(mapping[1])
	return "%s -> %s" % [source_name, destination_name]

func _friendly_cortical_name(cortical_id: String) -> String:
	var cache = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas
	if cortical_id in cache.keys():
		return cache[cortical_id].friendly_name
	push_error("Unable to locate cortical area of ID %s in cache!" % cortical_id)
	return "UNKNOWN"

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
	if !result.success:
		var error_details: PackedStringArray = result.decode_response_as_generic_error_code()
		BV.NOTIF.add_notification("Failed to rename connectivity rule: %s" % error_details[1])
		_morphology_name_edit.text = _loaded_morphology.name
		return
	BV.NOTIF.add_notification("Renamed connectivity rule to %s" % new_name)
	_loaded_morphology = FeagiCore.feagi_local_cache.morphologies.try_get_morphology_object(new_name)
	if _loaded_morphology:
		load_morphology(_loaded_morphology, true)
