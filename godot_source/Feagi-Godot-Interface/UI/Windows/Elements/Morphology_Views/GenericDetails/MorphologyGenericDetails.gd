extends VBoxContainer
class_name MorphologyGenericDetails
## Shows details for a given morphology

## TODO if someone edits connecitons with this window open, we should update mapping view!
## TODO add a signal if someone edits the description so we know somehting has been edited

const MORPHOLOGY_ICON_PATH: StringName = &"res://Feagi-Godot-Interface/UI/Resources/morphology_icons/"

@export var editable: bool = false

var details_text: StringName:
	get: return _morphology_details_view.text

var _available_morphology_images: PackedStringArray
var _morphology_mappings_view: TextEdit
var _morphology_details_view: TextEdit
var _morphology_texture_view: TextureRect
var _texture_container: VBoxContainer
var _shown_morphology: Morphology = NullMorphology.new()

func _ready() -> void:
	_morphology_mappings_view = $UsageAndImage/VBoxContainer/Usage
	_morphology_details_view = $Description
	_texture_container = $UsageAndImage/VBoxContainer2
	_morphology_texture_view = $UsageAndImage/VBoxContainer2/Current_Morphology_image
	_available_morphology_images = DirAccess.get_files_at(MORPHOLOGY_ICON_PATH)
	_morphology_details_view.editable = editable

## Update details window with the details of the given morphology
func load_morphology(morphology: Morphology, update_FEAGI_cache: bool = false) -> void:
	
	if _shown_morphology.retrieved_usage.is_connected(_retrieved_morphology_mappings_from_feagi):
		_shown_morphology.retrieved_usage.disconnect(_retrieved_morphology_mappings_from_feagi)
	_shown_morphology = morphology
	_update_image_with_morphology(morphology.name)
	morphology.retrieved_usage.connect(_retrieved_morphology_mappings_from_feagi)
	FeagiRequests.get_morphology_usage(morphology.name)
	_morphology_details_view.text = morphology.description
	if update_FEAGI_cache:
		FeagiRequests.refresh_morphology_properties(morphology.name)

## Wipes everything such that it is blank
func clear_UI() -> void:
	_shown_morphology = NullMorphology.new()
	_update_image_with_morphology("")
	_morphology_details_view.text = ""

## Updates the image of the description (if no image, just hides the rect)
func _update_image_with_morphology(morphology_name: StringName) -> void:
	var morphology_image_name: StringName = morphology_name + &".png"
	var index: int = _available_morphology_images.find(morphology_image_name)

	if index == -1:
		# no image found
		if _texture_container.visible:
			# we are changing size by doing this. Shrink as much as possible
			size = Vector2(0,0)
		_texture_container.visible = false
		return
	
	if !_texture_container.visible:
		# we are changing size by doing this. Shrink as much as possible
		size = Vector2(0,0)
	_texture_container.visible = true
	_morphology_texture_view.texture = load(MORPHOLOGY_ICON_PATH + morphology_image_name)

func _retrieved_morphology_mappings_from_feagi(usage: Array[PackedStringArray], _is_being_used: bool, _self_reference: Morphology):
	_morphology_mappings_view.text = _usage_array_to_string(usage)
	
## Given usage array is for relevant morphology, formats out a string to show usage
func _usage_array_to_string(usage: Array[PackedStringArray]) -> StringName:
	var output: String = ""
	for single_mapping in usage:
		output = output + _print_since_usage_mapping(single_mapping) + "\n"
	return output

func _print_since_usage_mapping(mapping: Array) -> String:
	# each element is an ID
	var output: String = ""

	if mapping[0] in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		output = FeagiCache.cortical_areas_cache.cortical_areas[mapping[0]].name + " -> "
	else:
		push_error("Unable to locate cortical area of ID %s in cache!" % mapping[0])
		output = "UNKNOWN -> "
	
	if mapping[1] in FeagiCache.cortical_areas_cache.cortical_areas.keys():
		output = output + FeagiCache.cortical_areas_cache.cortical_areas[mapping[1]].name
	else:
		push_error("Unable to locate cortical area of ID %s in cache!" % mapping[1])
		output = output + "UNKNOWN"
	return output
