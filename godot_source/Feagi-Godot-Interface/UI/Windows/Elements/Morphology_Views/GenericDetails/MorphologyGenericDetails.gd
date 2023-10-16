extends VBoxContainer
class_name MorphologyGenericDetails
## Shows details for a given morphology

## TODO if someone edits connecitons with this window open, we should update mapping view!

const MORPHOLOGY_ICON_PATH: StringName = &"res://Feagi-Godot-Interface/UI/Resources/morphology_icons/"

@export var editable: bool = false

var _available_morphology_images: PackedStringArray
var _morphology_mappings_view: TextEdit
var _morphology_details_view: TextEdit
var _morphology_texture_view: TextureRect
var _shown_morphology: Morphology = NullMorphology.new()

func _ready() -> void:
	_morphology_mappings_view = $UsageAndImage/VBoxContainer/Usage
	_morphology_details_view = $Description
	_morphology_texture_view = $UsageAndImage/VBoxContainer2/Current_Morphology_image
	_available_morphology_images = DirAccess.get_files_at(MORPHOLOGY_ICON_PATH)
	FeagiEvents.retrieved_latest_usuage_of_morphology.connect(_retrieved_morphology_mappings_from_feagi)
	_morphology_details_view.editable = editable

## Update details window with the details of the given morphology
func update_details_from_morphology(morphology: Morphology) -> void:
	_shown_morphology = morphology
	_update_image_with_morphology(morphology.name)
	FeagiRequests.get_morphology_usage(morphology.name)
	_morphology_details_view.text = morphology.description
	

## Updates the image of the description (if no image, just hides the rect)
func _update_image_with_morphology(morphology_name: StringName) -> void:
	var morphology_image_name: StringName = morphology_name + &".png"
	var index: int = _available_morphology_images.find(morphology_image_name)

	if index == -1:
		# no image found
		_morphology_texture_view.visible = false
		return
	_morphology_texture_view.visible = true
	_morphology_texture_view.texture = load(MORPHOLOGY_ICON_PATH + morphology_image_name)

func _retrieved_morphology_mappings_from_feagi(retrieved_morphology: Morphology, usage: Array[Array]):
	if retrieved_morphology.name != _shown_morphology.name:
		return
	_morphology_mappings_view.text = _usage_array_to_string(usage)
	
## Given usage array is for relevant morphology, formats out a string to show usage
func _usage_array_to_string(usage: Array[Array]) -> StringName:
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
