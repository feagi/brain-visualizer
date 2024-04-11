extends OptionButton
class_name TemplateDropDown

signal template_picked(template: CorticalTemplate)

@export var _template_type: BaseCorticalArea.CORTICAL_AREA_TYPE

var template_type: BaseCorticalArea.CORTICAL_AREA_TYPE:
	get: return _template_type
	set(v):
		_template_type = v
		load_cortical_type_options(v)

var _stored_template_references: Array[CorticalTemplate] = []

func _ready() -> void:
	load_cortical_type_options(_template_type)
	item_selected.connect(_on_user_pick)

func load_cortical_type_options(type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> void:
	clear()
	_stored_template_references = []
	match(type):
		BaseCorticalArea.CORTICAL_AREA_TYPE.IPU:
			for template: CorticalTemplate in FeagiCore.feagi_local_cache.IPU_templates.values():
				if !template.is_enabled:
					continue
				_stored_template_references.append(template)
				add_item(template.cortical_name)
		BaseCorticalArea.CORTICAL_AREA_TYPE.OPU:
			for template: CorticalTemplate in FeagiCore.feagi_local_cache.OPU_templates.values():
				if !template.is_enabled:
					continue
				_stored_template_references.append(template)
				add_item(template.cortical_name)
		_:
			push_error("Unknown cortical area type for Template Drop Down!")

func get_selected_template() -> CorticalTemplate:
	return _stored_template_references[selected]

func _on_user_pick(index: int) -> void:
	template_picked.emit(_stored_template_references[index])


