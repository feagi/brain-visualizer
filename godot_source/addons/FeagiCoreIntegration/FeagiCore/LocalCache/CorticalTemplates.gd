extends Object
class_name CorticalTemplates
## Holds all available templates for a specific cortical area type


var cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE:
	get: return _cortical_type
var templates: Dictionary:
	get: return _templates
var gui_name: StringName:
	get: return _gui_name

var _cortical_type: BaseCorticalArea.CORTICAL_AREA_TYPE
var _templates: Dictionary
var _gui_name: StringName

func _init(cortical_types_dict_from_FEAGI: Dictionary, type_cortical_area_str: StringName) -> void:
	_gui_name = cortical_types_dict_from_FEAGI[type_cortical_area_str]["gui_name"]
	_cortical_type = BaseCorticalArea.cortical_type_str_to_type(type_cortical_area_str)
	if "supported_devices" not in cortical_types_dict_from_FEAGI[type_cortical_area_str].keys():
		_templates = {} # no templates available
		return
	var buffer_dimensions: Array[int] = []
	for template_id in cortical_types_dict_from_FEAGI[type_cortical_area_str]["supported_devices"]:
		var sub_dict = cortical_types_dict_from_FEAGI[type_cortical_area_str]["supported_devices"][template_id]
		buffer_dimensions.assign(sub_dict["resolution"])
		_templates[template_id] = CorticalTemplate.new(template_id, sub_dict["enabled"], sub_dict["cortical_name"], sub_dict["structure"], buffer_dimensions, _cortical_type)

static func cortical_templates_factory(cortical_types_dict_from_FEAGI: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for cortical_type_str in BaseCorticalArea.CORTICAL_AREA_TYPE.keys():
		if cortical_type_str not in cortical_types_dict_from_FEAGI.keys():
			continue
		output[cortical_type_str] = CorticalTemplates.new(cortical_types_dict_from_FEAGI, cortical_type_str)
	return output





