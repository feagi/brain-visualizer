extends OptionButton
class_name TemplateDropDown

signal template_picked(template: CorticalTemplate)

@export var _template_type: AbstractCorticalArea.CORTICAL_AREA_TYPE

var template_type: AbstractCorticalArea.CORTICAL_AREA_TYPE:
	get: return _template_type
	set(v):
		_template_type = v
		load_cortical_type_options(v)

var _stored_template_references: Array[CorticalTemplate] = []
var _default_width: float

func _ready() -> void:
	_default_width = custom_minimum_size.x
	load_cortical_type_options(_template_type)
	item_selected.connect(_on_user_pick)
	BV.UI.theme_changed.connect(_on_theme_change)
	_on_theme_change()

func load_cortical_type_options(type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> void:
	clear()
	_stored_template_references = []
	
	print("🔍 TEMPLATE DROPDOWN: Loading templates for type: ", type)
	
	match(type):
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			var ipu_templates = FeagiCore.feagi_local_cache.IPU_templates
			print("🔍 TEMPLATE DROPDOWN: Found %d IPU templates in cache" % ipu_templates.size())
			
			for template: CorticalTemplate in ipu_templates.values():
				print("🔍 TEMPLATE DROPDOWN: IPU template '%s' - enabled: %s" % [template.cortical_name, template.is_enabled])
				if !template.is_enabled:
					continue
				_stored_template_references.append(template)
				add_item(template.cortical_name)
				
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			var opu_templates = FeagiCore.feagi_local_cache.OPU_templates
			print("🔍 TEMPLATE DROPDOWN: Found %d OPU templates in cache" % opu_templates.size())
			
			for template: CorticalTemplate in opu_templates.values():
				print("🔍 TEMPLATE DROPDOWN: OPU template '%s' - enabled: %s" % [template.cortical_name, template.is_enabled])
				if !template.is_enabled:
					continue
				_stored_template_references.append(template)
				add_item(template.cortical_name)
				
		_:
			push_error("Unknown cortical area type for Template Drop Down!")
	
	print("🔍 TEMPLATE DROPDOWN: Final dropdown has %d items" % get_item_count())

func get_selected_template() -> CorticalTemplate:
	if selected < 0 or selected >= _stored_template_references.size():
		push_warning("TemplateDropDown: No valid template selected (index: %d, array size: %d)" % [selected, _stored_template_references.size()])
		return null
	return _stored_template_references[selected]

func _on_user_pick(index: int) -> void:
	if index < 0 or index >= _stored_template_references.size():
		push_warning("TemplateDropDown: Invalid selection index: %d (array size: %d)" % [index, _stored_template_references.size()])
		return
	template_picked.emit(_stored_template_references[index])

func _on_theme_change(_new_theme: Theme = null) -> void:
	custom_minimum_size.x = _default_width * BV.UI.loaded_theme_scale.x
