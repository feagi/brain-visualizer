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
var _default_font_size: int
var _default_min_size: Vector2

func _ready() -> void:
	load_cortical_type_options(_template_type)
	item_selected.connect(_on_user_pick)
	_default_font_size = get_theme_font_size(&"font_size")
	if custom_minimum_size != Vector2(0,0):
		_default_min_size = custom_minimum_size
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)

func load_cortical_type_options(type: BaseCorticalArea.CORTICAL_AREA_TYPE) -> void:
	clear()
	_stored_template_references = []
	for template in FeagiCache.cortical_templates[BaseCorticalArea.cortical_type_to_str(type)].templates.values():
		
		if !template.is_enabled:
			continue
		_stored_template_references.append(template)
		add_item(template.cortical_name)

func get_selected_template() -> CorticalTemplate:
	return _stored_template_references[selected]

func _on_user_pick(index: int) -> void:
	template_picked.emit(_stored_template_references[index])

func _update_size(multiplier: float) -> void:
	add_theme_font_size_override(&"font_size", int(float(_default_font_size) * multiplier))
	if _default_min_size != Vector2(0,0):
		custom_minimum_size = _default_min_size * multiplier
	size = Vector2(0,0)
