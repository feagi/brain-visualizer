extends BaseDraggableWindow
class_name WindowEditClassifier
## Classifier editor. Not a cortical-area properties window and not a circuit editor.
## Tunables use the same [VerticalCollapsibleHiding] expanders as Cortical Area Details.

const WINDOW_NAME: StringName = "edit_classifier"
const _VECTOR_FIELD_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Vectors/Vector3iSpinBoxField.tscn")
const _COLLAPSIBLE_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Collapsable/VerticalCollapsibleHiding.tscn")
const _Tunables = preload("res://BrainVisualizer/UI/Windows/EditClassifier/EditClassifierTunables.gd")

var _name_input: LineEdit
var _parent_option: OptionButton
var _vector: Vector3iSpinboxField
var _mode_option: OptionButton
var _kernel_option: OptionButton
var _class_option: OptionButton
var _mask_option: OptionButton
var _kernel_size: Vector3iSpinboxField
var _kernel_row: Control
var _class_row: Control
var _mask_row: Control
var _kernel_size_row: Control
var _update_button: Button
var _editing_classifier: GenomeClassifier
var _area_ids: Array[StringName] = []
var _region_ids: Array[StringName] = []
var _kernel_memory_fields: Dictionary = {}
var _class_memory_fields: Dictionary = {}
var _associative_fields: Dictionary = {}
var _kernel_memory_count: IntInput
var _class_memory_count: IntInput
var _kernel_memory_apply: Button
var _class_memory_apply: Button
var _memory_count_generation: int = 0
var _associative_apply: Button


func _ready() -> void:
	super()
	visible = true
	if BV != null and BV.UI != null and BV.UI.selection_system != null:
		BV.UI.selection_system.add_override_usecase(SelectionSystem.OVERRIDE_USECASE.CLASSIFIER_PROPERTIES)


func close_window() -> void:
	super()
	if BV != null and BV.UI != null and BV.UI.selection_system != null:
		BV.UI.selection_system.remove_override_usecase(SelectionSystem.OVERRIDE_USECASE.CLASSIFIER_PROPERTIES)


## Selection changed while this editor is open.
## The same classifier keeps the form and reloads memory counts. Another classifier replaces the form.
func apply_selection(classifier: GenomeClassifier) -> void:
	if classifier == null:
		return
	var open_id: StringName = _editing_classifier.classifier_id if _editing_classifier != null else &""
	if classifier.classifier_id == open_id:
		_editing_classifier = classifier
		_refresh_memory_counts()
		return
	setup(classifier)


func setup(editing_classifier: GenomeClassifier) -> void:
	_setup_base_window(WINDOW_NAME)
	if editing_classifier == null:
		push_error("UI WINDOW: Classifier editor opened without a classifier.")
		close_window()
		return
	_editing_classifier = editing_classifier
	_build_classifier_fields()
	_fit_window_to_content()


func _delay_shrink_window() -> void:
	_fit_window_to_content()


func _build_classifier_fields() -> void:
	var internals: VBoxContainer = _window_internals
	for child in internals.get_children():
		internals.remove_child(child)
		child.queue_free()

	var form := VBoxContainer.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	form.custom_minimum_size = Vector2(_Tunables.WINDOW_CONTENT_WIDTH, 0)
	form.add_theme_constant_override("separation", 8)
	internals.add_child(form)

	var id_value := LineEdit.new()
	id_value.text = String(_editing_classifier.classifier_id)
	id_value.editable = false
	id_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_labeled("Classifier ID", id_value))

	_name_input = LineEdit.new()
	_name_input.text = String(_editing_classifier.friendly_name)
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_child(_labeled("Classifier Name", _name_input))

	_parent_option = OptionButton.new()
	_parent_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_parent_options()
	form.add_child(_labeled("Parent Circuit", _parent_option))

	_vector = _VECTOR_FIELD_PREFAB.instantiate() as Vector3iSpinboxField
	_vector.initial_vector = _editing_classifier.coordinates_3D
	form.add_child(_labeled("3D Position", _vector))

	_mode_option = OptionButton.new()
	_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mode_option.add_item("Kernel training")
	_mode_option.add_item("Scanner training")
	_mode_option.item_selected.connect(func(_index: int) -> void: _apply_training_mode_visibility())
	if _editing_classifier.training_mode == &"scanner":
		_mode_option.select(1)
	form.add_child(_labeled("Training Mode", _mode_option))

	_kernel_option = OptionButton.new()
	_class_option = OptionButton.new()
	_mask_option = OptionButton.new()
	_kernel_size = _VECTOR_FIELD_PREFAB.instantiate() as Vector3iSpinboxField
	_kernel_size.int_x_min = 1
	_kernel_size.int_y_min = 1
	_kernel_size.int_z_min = 1
	var stored_size: Vector3i = _editing_classifier.kernel_size
	_kernel_size.initial_vector = stored_size if stored_size != Vector3i.ZERO else Vector3i(1, 1, 1)
	_populate_area_options()
	_kernel_row = _labeled("Kernel Area", _kernel_option)
	_class_row = _labeled("Class Area", _class_option)
	_mask_row = _labeled("Mask Area", _mask_option)
	_kernel_size_row = _labeled("Kernel Size", _kernel_size)
	form.add_child(_kernel_row)
	form.add_child(_class_row)
	form.add_child(_mask_row)
	form.add_child(_kernel_size_row)
	_apply_training_mode_visibility()

	_kernel_memory_count = _make_memory_count_field()
	_class_memory_count = _make_memory_count_field()
	form.add_child(_labeled("Kernel Memory Neurons", _kernel_memory_count))
	form.add_child(_labeled("Class Memory Neurons", _class_memory_count))
	_show_cached_memory_count(_kernel_memory_count, _editing_classifier.kernel_memory_id)
	_show_cached_memory_count(_class_memory_count, _editing_classifier.class_memory_id)
	_refresh_memory_counts()

	_kernel_memory_apply = _add_memory_section(
		form,
		_Tunables.SECTION_KERNEL_MEMORY,
		_editing_classifier.kernel_memory_id,
		_kernel_memory_fields,
		_on_apply_kernel_memory
	)
	_class_memory_apply = _add_memory_section(
		form,
		_Tunables.SECTION_CLASS_MEMORY,
		_editing_classifier.class_memory_id,
		_class_memory_fields,
		_on_apply_class_memory
	)
	_associative_apply = _add_associative_section(form)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_on_press_cancel)
	_update_button = Button.new()
	_update_button.text = "Update"
	_update_button.pressed.connect(_on_press_update)
	buttons.add_child(cancel)
	buttons.add_child(_update_button)
	internals.add_child(buttons)


func _labeled(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 32)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(220, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(control)
	return row


func _add_collapsible(parent: Control, title: String) -> Dictionary:
	var collapsible: VerticalCollapsibleHiding = _COLLAPSIBLE_PREFAB.instantiate()
	collapsible.section_text = StringName(title)
	collapsible.start_open = false
	collapsible.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collapsible.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(collapsible)
	var section_body: CanvasItem = collapsible.get_node("VerticalCollapsible/PanelContainer")
	section_body.visibility_changed.connect(_fit_window_to_content)
	var title_label: Label = collapsible.get_node("VerticalCollapsible/HBoxContainer/Section_Title")
	title_label.text = title
	title_label.theme_type_variation = &"Label_Header"
	var content_root: Control = collapsible.get_control()
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_theme_constant_override("separation", 4)
	content_root.add_child(holder)
	return {"holder": holder, "section": collapsible}


func _close_section(section_pack: Dictionary) -> void:
	var section: VerticalCollapsibleHiding = section_pack["section"]
	if section.is_open:
		section.is_open = false


func _fit_window_to_content() -> void:
	if not is_inside_tree():
		return
	if _window_internals != null:
		_window_internals.queue_sort()
	call_deferred("_apply_fitted_size")


func _apply_fitted_size() -> void:
	if not is_inside_tree():
		return
	var content_size: Vector2 = get_combined_minimum_size()
	var band_top: int = 0
	var viewport_height: int = int(get_viewport_rect().size.y)
	if BV != null and BV.UI != null and BV.UI.top_bar != null:
		band_top = int(BV.UI.top_bar.position.y + BV.UI.top_bar.size.y)
	var available_height: int = _Tunables.available_window_height(
		viewport_height,
		band_top,
		UIManager.MOUSE_CONTEXT_HEIGHT_PX,
		UIManager.MOUSE_CONTEXT_MARGIN_PX
	)
	var height: int = _Tunables.fitted_window_height(int(ceil(content_size.y)), available_height)
	var width: int = maxi(_Tunables.WINDOW_CONTENT_WIDTH, int(ceil(content_size.x)))
	position.y = _Tunables.fitted_window_top(int(position.y), height, band_top, band_top + available_height)
	custom_minimum_size = Vector2(width, 0)
	size = Vector2i(width, height)


func _make_memory_count_field() -> IntInput:
	var field := IntInput.new()
	field.editable = false
	field.focus_mode = Control.FOCUS_NONE
	field.custom_minimum_size = Vector2(220, 0)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return field


func _show_cached_memory_count(field: IntInput, area_id: StringName) -> void:
	if field == null:
		return
	var area: AbstractCorticalArea = _cached_area(area_id)
	var total: int = area.reported_neuron_count if area != null else 0
	_apply_memory_count_display(field, total, null, null)


func _refresh_memory_counts() -> void:
	_memory_count_generation += 1
	var generation: int = _memory_count_generation
	_refresh_one_memory_count(_editing_classifier.kernel_memory_id, _kernel_memory_count, generation)
	_refresh_one_memory_count(_editing_classifier.class_memory_id, _class_memory_count, generation)


func _refresh_one_memory_count(area_id: StringName, field: IntInput, generation: int) -> void:
	if field == null or area_id == &"":
		return
	if FeagiCore == null or FeagiCore.requests == null or not FeagiCore.can_interact_with_feagi():
		return
	var out: FeagiRequestOutput = await FeagiCore.requests.get_memory_cortical_area(str(area_id), 0, 1)
	if generation != _memory_count_generation or not is_instance_valid(field):
		return
	if out == null or not out.success:
		return
	var payload: Dictionary = out.decode_response_as_dict()
	var short_term: int = int(payload.get("short_term_neuron_count", 0))
	var long_term: int = int(payload.get("long_term_neuron_count", 0))
	# Genome-cache reported_neuron_count is often stale (0) for hidden classifier
	# memory areas. ST+LT is the live active-neuron total from /v1/cortical_area/memory.
	_apply_memory_count_display(
		field,
		_Tunables.memory_neuron_total(short_term, long_term),
		short_term,
		long_term
	)


func _apply_memory_count_display(field: IntInput, total_count: int, short_term_count: Variant, long_term_count: Variant) -> void:
	if field == null:
		return
	if short_term_count != null and long_term_count != null:
		var short_term: int = int(short_term_count)
		var long_term: int = int(long_term_count)
		field.suffix = _Tunables.memory_count_suffix(short_term, long_term)
		field.tooltip_text = _Tunables.memory_count_tooltip(total_count, short_term, long_term)
		field.previous_text = str(total_count)
		field.text = _Tunables.memory_count_display(total_count, short_term, long_term)
		return
	field.suffix = ""
	field.tooltip_text = "Total neurons: %s" % _Tunables.format_int_with_commas(total_count)
	field.previous_text = str(total_count)
	field.text = _Tunables.format_compact_count(total_count)


func _add_memory_section(
	parent: Control,
	title: String,
	area_id: StringName,
	field_store: Dictionary,
	apply_callback: Callable
) -> Button:
	var section_pack: Dictionary = _add_collapsible(parent, title)
	var holder: VBoxContainer = section_pack["holder"]
	var area: AbstractCorticalArea = _cached_area(area_id)
	if area == null:
		var missing := Label.new()
		missing.text = "Memory area is not in cache."
		holder.add_child(missing)
	var params: CorticalPropertyMemoryParameters = _memory_parameters(area)
	for spec in _Tunables.MEMORY_FIELD_SPECS:
		var key: String = String(spec["key"])
		var control: Control = _make_spec_control(spec)
		field_store[key] = control
		holder.add_child(_labeled(String(spec["label"]), control))
		_apply_spec_value(control, spec, _memory_spec_value(params, spec))
	var apply := Button.new()
	apply.text = "Apply Update"
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply.disabled = area == null
	apply.pressed.connect(apply_callback)
	holder.add_child(apply)
	if area != null:
		_wire_section_dirty(field_store, apply)
		apply.disabled = true
	_close_section(section_pack)
	return apply


func _add_associative_section(parent: Control) -> Button:
	var section_pack: Dictionary = _add_collapsible(parent, _Tunables.SECTION_ASSOCIATIVE)
	var holder: VBoxContainer = section_pack["holder"]
	var mapping: SingleMappingDefinition = _first_associative_mapping()
	if mapping == null:
		var missing := Label.new()
		missing.text = "Associative mapping is not in cache."
		holder.add_child(missing)
	for spec in _Tunables.ASSOCIATIVE_FIELD_SPECS:
		var key: String = String(spec["key"])
		var control: Control = _make_spec_control(spec)
		_associative_fields[key] = control
		holder.add_child(_labeled(String(spec["label"]), control))
		_apply_spec_value(control, spec, _associative_spec_value(mapping, spec))
	var apply := Button.new()
	apply.text = "Apply Update"
	apply.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply.disabled = mapping == null
	apply.pressed.connect(_on_apply_associative)
	holder.add_child(apply)
	if mapping != null:
		_wire_section_dirty(_associative_fields, apply)
		apply.disabled = true
	_close_section(section_pack)
	return apply


func _make_spec_control(spec: Dictionary) -> Control:
	var kind: String = String(spec.get("kind", "int"))
	if kind == "bool":
		var toggle := ToggleButton.new()
		_Tunables.configure_theme_toggle(toggle)
		return toggle
	if kind == "float":
		var float_field := FloatInput.new()
		float_field.custom_minimum_size = Vector2(120, 0)
		float_field.size_flags_horizontal = Control.SIZE_SHRINK_END
		float_field.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if spec.has("min"):
			float_field.min_value = float(spec["min"])
		return float_field
	var int_field := IntInput.new()
	int_field.custom_minimum_size = Vector2(120, 0)
	int_field.size_flags_horizontal = Control.SIZE_SHRINK_END
	int_field.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	int_field.min_value = int(spec.get("min", 1))
	return int_field


func _apply_spec_value(control: Control, spec: Dictionary, value: Variant) -> void:
	var kind: String = String(spec.get("kind", "int"))
	if kind == "bool" and control is ToggleButton:
		(control as ToggleButton).set_toggle_no_signal(bool(value))
		return
	if kind == "float" and control is FloatInput:
		(control as FloatInput).current_float = float(value)
		return
	if control is IntInput:
		(control as IntInput).current_int = int(value)


func _wire_section_dirty(fields: Dictionary, apply: Button) -> void:
	for control in fields.values():
		if control == null:
			continue
		if (control as Variant).has_signal("user_interacted"):
			(control as Variant).user_interacted.connect(func() -> void: apply.disabled = false)
		if control is ToggleButton:
			(control as ToggleButton).toggled.connect(func(_pressed: bool) -> void: apply.disabled = false)


func _memory_spec_value(params: CorticalPropertyMemoryParameters, spec: Dictionary) -> Variant:
	if String(spec.get("kind", "int")) == "bool":
		if params == null:
			return false
		return params.get(String(spec["property"]))
	if params == null:
		return _Tunables.spec_numeric_default(spec)
	return _Tunables.numeric_or_default(params.get(String(spec["property"])), spec)


func _associative_spec_value(mapping: SingleMappingDefinition, spec: Dictionary) -> Variant:
	var raw: Variant = null
	if mapping != null:
		match String(spec["key"]):
			"plasticity_window":
				raw = mapping.plasticity_window
			"plasticity_constant":
				raw = mapping.plasticity_constant
			"ltp_multiplier":
				raw = mapping.LTP_multiplier
			"ltd_multiplier":
				raw = mapping.LTD_multiplier
	return _Tunables.numeric_or_default(raw, spec)


func _values_from_fields(fields: Dictionary, specs: Array[Dictionary]) -> Dictionary:
	var values: Dictionary = {}
	for spec in specs:
		var key: String = String(spec["key"])
		var control: Variant = fields.get(key, null)
		if control is IntInput:
			values[key] = (control as IntInput).current_int
		elif control is FloatInput:
			values[key] = (control as FloatInput).current_float
		elif control is ToggleButton:
			values[key] = (control as ToggleButton).button_pressed
	return values


func _cached_area(area_id: StringName) -> AbstractCorticalArea:
	if area_id == &"" or FeagiCore == null or FeagiCore.feagi_local_cache == null:
		return null
	return FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(area_id, null)


func _memory_parameters(area: AbstractCorticalArea) -> CorticalPropertyMemoryParameters:
	if area is MemoryCorticalArea:
		return (area as MemoryCorticalArea).memory_parameters
	return null


func _first_associative_mapping() -> SingleMappingDefinition:
	var mappings: Array[SingleMappingDefinition] = _associative_mapping_set()
	for mapping in mappings:
		if mapping != null and mapping.morphology_used != null and mapping.morphology_used.name == &"associative_memory":
			return mapping
	if mappings.is_empty():
		return null
	return mappings[0]


func _associative_mapping_set() -> Array[SingleMappingDefinition]:
	if _editing_classifier == null:
		return []
	var kernel_memory: AbstractCorticalArea = _cached_area(_editing_classifier.kernel_memory_id)
	var class_memory: AbstractCorticalArea = _cached_area(_editing_classifier.class_memory_id)
	if kernel_memory == null or class_memory == null:
		return []
	return kernel_memory.get_mapping_array_toward_cortical_area(class_memory)


func _mapping_with_associative_overrides(mapping: SingleMappingDefinition, overrides: Dictionary) -> SingleMappingDefinition:
	return SingleMappingDefinition.new(
		mapping.morphology_used,
		mapping.scalar,
		mapping.post_synaptic_current_multiplier,
		true,
		float(overrides.get("plasticity_constant", mapping.plasticity_constant)),
		float(overrides.get("ltp_multiplier", mapping.LTP_multiplier)),
		float(overrides.get("ltd_multiplier", mapping.LTD_multiplier)),
		int(overrides.get("plasticity_window", mapping.plasticity_window)),
		mapping.synaptic_delay_bursts,
		mapping.plasticity_mode,
		mapping.eligibility_decay_bursts,
		mapping.reward_source_area,
		mapping.punishment_source_area,
		mapping.gate_source_area,
	)


func _notify_failure(message: String) -> void:
	if BV != null and BV.NOTIF != null:
		BV.NOTIF.add_notification(message)


func _on_apply_kernel_memory() -> void:
	await _apply_memory_section(_editing_classifier.kernel_memory_id, _kernel_memory_fields, _kernel_memory_apply)


func _on_apply_class_memory() -> void:
	await _apply_memory_section(_editing_classifier.class_memory_id, _class_memory_fields, _class_memory_apply)


func _apply_memory_section(area_id: StringName, fields: Dictionary, apply: Button) -> void:
	if FeagiCore == null or FeagiCore.requests == null:
		return
	var payload: Dictionary = _Tunables.memory_update_payload(
		_values_from_fields(fields, _Tunables.MEMORY_FIELD_SPECS)
	)
	if payload.is_empty():
		return
	apply.disabled = true
	var result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_area(area_id, payload)
	if result == null or result.has_errored or result.failed_requirement:
		apply.disabled = false
		_notify_failure("Failed to update classifier memory tunables.")


func _on_apply_associative() -> void:
	if FeagiCore == null or FeagiCore.requests == null or _editing_classifier == null:
		return
	var kernel_memory: AbstractCorticalArea = _cached_area(_editing_classifier.kernel_memory_id)
	var class_memory: AbstractCorticalArea = _cached_area(_editing_classifier.class_memory_id)
	var existing: Array[SingleMappingDefinition] = _associative_mapping_set()
	if kernel_memory == null or class_memory == null or existing.is_empty():
		_notify_failure("Associative mapping is not in cache.")
		return
	var overrides: Dictionary = _values_from_fields(_associative_fields, _Tunables.ASSOCIATIVE_FIELD_SPECS)
	var next_mappings: Array[SingleMappingDefinition] = []
	var patched_any: bool = false
	for mapping in existing:
		var is_associative: bool = mapping.morphology_used != null and mapping.morphology_used.name == &"associative_memory"
		if is_associative or existing.size() == 1:
			next_mappings.append(_mapping_with_associative_overrides(mapping, overrides))
			patched_any = true
		else:
			next_mappings.append(mapping)
	if not patched_any:
		_notify_failure("No associative mapping to update.")
		return
	_associative_apply.disabled = true
	var result: FeagiRequestOutput = await FeagiCore.requests.set_mappings_between_corticals(
		kernel_memory,
		class_memory,
		next_mappings
	)
	if result == null or result.has_errored or result.failed_requirement:
		_associative_apply.disabled = false
		_notify_failure("Failed to update associative memory parameters.")


func _populate_parent_options() -> void:
	_parent_option.clear()
	_region_ids.clear()
	if FeagiCore == null or FeagiCore.feagi_local_cache == null:
		return
	var regions: Array = FeagiCore.feagi_local_cache.brain_regions.available_brain_regions.values()
	regions.sort_custom(func(a: BrainRegion, b: BrainRegion) -> bool:
		return String(a.friendly_name).to_lower() < String(b.friendly_name).to_lower()
	)
	var selected := 0
	for region in regions:
		if region == null:
			continue
		_parent_option.add_item(String(region.friendly_name))
		_region_ids.append(region.region_ID)
		if _editing_classifier.current_parent_region != null and region.region_ID == _editing_classifier.current_parent_region.region_ID:
			selected = _region_ids.size() - 1
	if _parent_option.item_count > 0:
		_parent_option.select(selected)


func _populate_area_options() -> void:
	_kernel_option.clear()
	_class_option.clear()
	_mask_option.clear()
	_area_ids.clear()
	var parent_region: BrainRegion = _editing_classifier.current_parent_region
	var areas: Array[AbstractCorticalArea] = []
	if parent_region != null:
		for area in parent_region.contained_cortical_areas:
			if area != null and area not in areas:
				areas.append(area)
	if FeagiCore != null and FeagiCore.feagi_local_cache != null:
		for area_id in _editing_classifier.inbound_visual_source_ids():
			var referenced: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(area_id, null)
			if referenced != null and referenced not in areas:
				areas.append(referenced)
	areas.sort_custom(func(a: AbstractCorticalArea, b: AbstractCorticalArea) -> bool:
		return String(a.friendly_name).to_lower() < String(b.friendly_name).to_lower()
	)
	for area in areas:
		if area.cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			continue
		if area.is_scan_twin() or area.is_classifier_internal_memory() or area.is_leftover_classifier_auto_twin():
			continue
		var dims: Vector3i = area.dimensions_3D
		var label := "%s %sx%sx%s" % [area.friendly_name, dims.x, dims.y, dims.z]
		_kernel_option.add_item(label)
		_class_option.add_item(label)
		_mask_option.add_item(label)
		_area_ids.append(area.cortical_ID)
	_select_area(_kernel_option, _editing_classifier.kernel_area_id)
	_select_area(_class_option, _editing_classifier.class_area_id)
	_select_area(_mask_option, _editing_classifier.mask_area_id)


func _apply_training_mode_visibility() -> void:
	var scanner: bool = _mode_option != null and _mode_option.selected == 1
	if _kernel_row != null:
		_kernel_row.visible = not scanner
	if _class_row != null:
		_class_row.visible = not scanner
	if _mask_row != null:
		_mask_row.visible = scanner
	if _kernel_size_row != null:
		_kernel_size_row.visible = scanner


func _is_scanner_mode() -> bool:
	return _mode_option != null and _mode_option.selected == 1


func _select_area(option: OptionButton, area_id: StringName) -> void:
	var index: int = _area_ids.find(area_id)
	if index >= 0:
		option.select(index)


func _selected_area_id(option: OptionButton) -> StringName:
	if option == null or option.selected < 0 or option.selected >= _area_ids.size():
		return &""
	return _area_ids[option.selected]


func _selected_region_id() -> StringName:
	if _parent_option == null or _parent_option.selected < 0 or _parent_option.selected >= _region_ids.size():
		return &""
	return _region_ids[_parent_option.selected]


func _on_press_cancel() -> void:
	close_window()


func _on_press_update() -> void:
	if _editing_classifier == null or FeagiCore == null or FeagiCore.requests == null:
		close_window()
		return
	var next_name: String = _name_input.text if _name_input != null else String(_editing_classifier.friendly_name)
	var coords: Vector3i = _vector.current_vector if _vector != null else _editing_classifier.coordinates_3D
	var training_mode: String = "scanner" if _is_scanner_mode() else "kernel"
	if training_mode == "scanner":
		var kernel_size: Vector3i = _kernel_size.current_vector if _kernel_size != null else Vector3i.ZERO
		if _selected_area_id(_mask_option) == &"" or kernel_size.x < 1 or kernel_size.y < 1 or kernel_size.z < 1:
			_update_button.disabled = false
			_notify_failure("Scanner training needs a mask area and a kernel size.")
			return
	elif _selected_area_id(_kernel_option) == &"" or _selected_area_id(_class_option) == &"":
		_update_button.disabled = false
		_notify_failure("Kernel training needs a kernel area and a class area.")
		return
	_update_button.disabled = true
	var result: FeagiRequestOutput = await FeagiCore.requests.edit_classifier(
		_editing_classifier,
		next_name,
		coords,
		_selected_region_id(),
		training_mode,
		_selected_area_id(_kernel_option),
		_selected_area_id(_class_option),
		_selected_area_id(_mask_option),
		_kernel_size.current_vector if _kernel_size != null else Vector3i.ZERO
	)
	if result == null or result.has_errored or result.failed_requirement:
		_update_button.disabled = false
		_notify_failure("Failed to update classifier.")
		return
	close_window()
