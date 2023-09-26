extends OptionButton
class_name TemplateDropDown

signal template_picked(template: CorticalTemplate)

var template_type: CorticalArea.CORTICAL_AREA_TYPE:
	get: return _template_type
	set(v):
		_template_type = v
		load_cortical_type_options(v)

@export var _template_type: CorticalArea.CORTICAL_AREA_TYPE
var _ordered_ID_name_mapping: Array[CorticalTemplate] = []

func _ready() -> void:
	load_cortical_type_options(_template_type)

func load_cortical_type_options(type: CorticalArea.CORTICAL_AREA_TYPE) -> void:
	clear()
	_ordered_ID_name_mapping = []
	for template in FeagiCache.cortical_templates[CorticalArea.CORTICAL_AREA_TYPE.keys()[type]].templates.values():
		
		if !template.is_enabled:
			continue
		_ordered_ID_name_mapping.append(template)
		add_item(template.cortical_name)

func _on_user_pick(index: int) -> void:
	template_picked.emit(_ordered_ID_name_mapping[index])


