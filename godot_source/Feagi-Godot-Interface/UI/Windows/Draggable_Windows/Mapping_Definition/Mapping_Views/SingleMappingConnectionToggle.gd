extends VBoxContainer
class_name SingleMappingConnectionToggle

var _unique_case_text: Label
var _connection_toggle: CheckButton
var _allowed_morphologies: Array[Morphology]

func _ready() -> void:
	_unique_case_text = $UniqueCase
	_connection_toggle = $CheckButton

func display_mapping_properties(mappings_copy: MappingProperties) -> void:
	visible = true
	_set_unique_case_text(mappings_copy)
	_connection_toggle.button_pressed = mappings_copy.number_mappings > 0
	_allowed_morphologies = mappings_copy.source_cortical_area.get_allowed_morphologies_to_map_toward(mappings_copy.destination_cortical_area)

#TODO we should have a drop down for various morphology options
## Creates an Array of [MappingProperty] given the items within the scroll section
func generate_mapping_properties() -> Array[MappingProperty]:
	var mappings: Array[MappingProperty]= []
	if _connection_toggle.button_pressed:
		if len(_allowed_morphologies) == 1:
			mappings.append(MappingProperty.create_default_mapping(_allowed_morphologies[0]))
		#TODO account for cases where there can be muliple allowed morphologies!

	return mappings

func _set_unique_case_text(mapping_properties: MappingProperties) -> void:
	var source_area_type: StringName = mapping_properties.source_cortical_area.type_as_string
	var destination_area_type: StringName = mapping_properties.destination_cortical_area.type_as_string
	var allowed_morphologies: Array[StringName] = Morphology.morphology_array_to_string_array_of_names(mapping_properties.source_cortical_area.get_allowed_morphologies_to_map_toward(mapping_properties.destination_cortical_area))
	_unique_case_text.text = "When connecting a cortical area of type %s toward a cortical area of type %s, you can only enable a single mapping using one of the following morphologies: $s" % [source_area_type, destination_area_type, FEAGIUtils.string_name_array_to_CSV(allowed_morphologies)]
