extends VBoxContainer
class_name MorphologyManagerDescription

const MORPHOLOGY_ICON_PATH: StringName = &"res://Feagi-Godot-Interface/UI/Resources/morphology_icons/"

var _available_morphology_images: PackedStringArray
var _show_mappings: TextEdit

var _texture_rect: TextureRect


func _ready() -> void:
	_available_morphology_images = DirAccess.get_files_at(MORPHOLOGY_ICON_PATH)
	_texture_rect = $Morphology_Texture
	_show_mappings = $Show_Mappings

## Updates the image of the description 
func update_image_with_morphology(morphology_name: StringName) -> void:
	var morphology_image_name: StringName = morphology_name + &".png"
	var index: int = _available_morphology_images.find(morphology_image_name)

	if index == -1:
		# no image found
		_texture_rect.visible = false
		return
	_texture_rect.visible = true
	_texture_rect.texture = load(MORPHOLOGY_ICON_PATH + morphology_image_name)

## Given usage array is for relevant morphology, formats out a string to show usage
func display_morphology_usage(usage: Array[Array]) -> void:
	var output: String = ""
	for single_mapping in usage:
		output = output + _print_since_usage_mapping(single_mapping) + "\n"
	_show_mappings.text = output

## CLears the usage text box
func clear_usage() -> void:
	_show_mappings.text = ""

func _print_since_usage_mapping(mapping: Array) -> String:
	# each element is an ID
	var output: String = ""
	var source: CorticalArea
	var destination: CorticalArea

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
