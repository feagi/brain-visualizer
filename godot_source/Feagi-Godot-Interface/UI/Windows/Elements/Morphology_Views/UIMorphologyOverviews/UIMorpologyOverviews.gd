extends HBoxContainer
class_name UIMorphologyOverviews

signal request_close()
signal requested_updating_morphology(morphology_name: StringName)
signal request_deleting_morphology(morphology_name: StringName)

@export var enable_add_morphology_button: bool = true
@export var enable_update_morphology_button: bool = true
@export var enable_delete_morphology_button: bool = true
@export var enable_close_button: bool = true
@export var morphology_properties_editable: bool = true

var loaded_morphology: Morphology:
	get: return _loaded_morphology

var _add_morphology_button: Button
var _morphology_scroll: MorphologyScroll
var _morphology_name_label: Label
var _UI_morphology_definition: UIMorphologyDefinition
var _UI_morphology_image: UIMorphologyImage
var _UI_morphology_usage: UIMorphologyUsage
var _UI_morphology_description: UIMorphologyDescription
var _delete_morphology_button: TextureButton
var _close_button: Button
var _update_morphology_button: Button

var _no_name_text: StringName
var _loaded_morphology: Morphology

func _ready() -> void:
	# Get references
	_add_morphology_button = $Listings/AddMorphology
	_morphology_scroll = $Listings/MorphologyScroll
	_morphology_name_label = $SelectedDetails/Name
	_UI_morphology_definition = $SelectedDetails/Details/MarginContainer/VBoxContainer/HBoxContainer/SmartMorphologyView
	_UI_morphology_image = $SelectedDetails/Details/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/UIMorphologyImage
	_UI_morphology_usage = $SelectedDetails/Details/MarginContainer/VBoxContainer/HBoxContainer/VBoxContainer/UIMorphologyUsage
	_UI_morphology_description = $SelectedDetails/Details/MarginContainer/VBoxContainer/UIMorphologyDescription
	_delete_morphology_button = $SelectedDetails/Details/MarginContainer/VBoxContainer/Buttons/Delete
	_close_button = $SelectedDetails/Details/MarginContainer/VBoxContainer/Buttons/Close
	_update_morphology_button = $SelectedDetails/Details/MarginContainer/VBoxContainer/Buttons/Close
	
	_add_morphology_button.visible = enable_add_morphology_button
	_delete_morphology_button.visible = enable_delete_morphology_button
	_close_button.visible = enable_close_button
	_update_morphology_button.visible = enable_update_morphology_button
	_UI_morphology_definition.morphology_editable = morphology_properties_editable
	_no_name_text = _morphology_name_label.text

func load_morphology(morphology: Morphology, override_scroll_selection: bool = false) -> void:
	_loaded_morphology = morphology
	_morphology_name_label.text = morphology.name
	_UI_morphology_definition.load_morphology(morphology)
	_UI_morphology_image.load_morphology(morphology)
	_UI_morphology_usage.load_morphology(morphology)
	_UI_morphology_description.load_morphology(morphology)
	if override_scroll_selection:
		_morphology_scroll.select_morphology(morphology)
	size = Vector2i(0,0) # Force shrink to minimum possible size

func _user_requested_update_morphology() -> void:
	var morphology_to_update: Morphology = _UI_morphology_definition.retrieve_morphology(_loaded_morphology.name, _loaded_morphology.description)
	FeagiRequests.request_updating_morphology(morphology_to_update)
	requested_updating_morphology.emit(morphology_to_update)

func _user_request_create_morphology() -> void:
	VisConfig.UI_manager.window_manager.spawn_create_morphology()

func _user_requested_closing() -> void:
	request_close.emit()

func _user_request_delete_morphology() -> void:
	if _loaded_morphology == null:
		return
	request_deleting_morphology.emit(_loaded_morphology.name)

func _user_selected_morphology_from_scroll(morphology) -> void:
	load_morphology(morphology)
