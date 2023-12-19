extends VBoxContainer
class_name SingleMappingConnectionToggle

var _unique_case_text: Label

func _ready() -> void:
	_unique_case_text = $UniqueCase

func display_mapping_properties(mappings_copy: MappingProperties) -> void:
	visible = true



func _set_unique_case_text(mapping_properties: MappingProperties) -> void:
	var source_area_type: StringName = mapping_properties.source_cortical_area.type_as_string
	var destination_area_type: StringName = mapping_properties.destination_cortical_area.type_as_string
	var allowed_morphologies: Array[StringName] = Morphology.morphology_array_to_string_array_of_names(mapping_properties.source_cortical_area.get_allowed_morphologies_to_map_toward(mapping_properties.destination_cortical_area))
	
	
