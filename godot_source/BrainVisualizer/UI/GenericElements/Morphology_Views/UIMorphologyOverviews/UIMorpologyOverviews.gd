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
var _morphology_name_label: Label
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

func _ready() -> void:
	# Get references
	_add_morphology_button = $Listings/AddMorphology
	_morphology_scroll = $Listings/MorphologyScroll
	_morphology_name_label = $SelectedDetails/HBoxContainer/Name
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
	_no_name_text = _morphology_name_label.text
	_custom_minimum_size_scalar = ScalingCustomMinimumSize.new(controls_to_scale_by_min_size)
	_custom_minimum_size_scalar.theme_updated(BV.UI.loaded_theme)
	BV.UI.theme_changed.connect(_custom_minimum_size_scalar.theme_updated)
	
func load_morphology(morphology: BaseMorphology, override_scroll_selection: bool = false) -> void:
	_loaded_morphology = morphology
	if morphology is NullMorphology:
		_morphology_name_label.text = "No Connectivity Rule Loaded!"
	else:
		_morphology_name_label.text = morphology.name
	_UI_morphology_definition.load_morphology(morphology)
	_UI_morphology_image.load_morphology(morphology)
	_UI_morphology_usage.load_morphology(morphology)
	_UI_morphology_description.load_morphology(morphology)
	_UI_morphology_delete_button.load_morphology(morphology)
	if override_scroll_selection:
		_morphology_scroll.select_morphology(morphology)
	
	# Scroll already requests a property refresh on selection, but since we use usages, lets also refresh usage information
	FeagiCore.requests.get_morphology_usage(morphology.name)
	size = Vector2i(0,0) # Force shrink to minimum possible size

func _user_requested_update_morphology() -> void:
	BV.NOTIF.add_notification("Requesting FEAGI to update Connectivity rule %s" % _loaded_morphology.name)
	_UI_morphology_definition.request_feagi_apply_morphology_settings(_loaded_morphology.name)

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
