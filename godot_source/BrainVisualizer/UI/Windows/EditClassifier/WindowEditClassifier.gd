extends BaseDraggableWindow
class_name WindowEditClassifier
## Classifier editor. Not a cortical-area properties window and not a circuit editor.

const WINDOW_NAME: StringName = "edit_classifier"
const _VECTOR_FIELD_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Vectors/Vector3iSpinBoxField.tscn")

var _name_input: LineEdit
var _parent_option: OptionButton
var _vector: Vector3iSpinboxField
var _kernel_option: OptionButton
var _class_option: OptionButton
var _field_option: OptionButton
var _update_button: Button
var _editing_classifier: GenomeClassifier
var _area_ids: Array[StringName] = []
var _region_ids: Array[StringName] = []


func _ready() -> void:
	super()
	visible = true


func setup(editing_classifier: GenomeClassifier) -> void:
	_setup_base_window(WINDOW_NAME)
	if editing_classifier == null:
		push_error("UI WINDOW: Classifier editor opened without a classifier.")
		close_window()
		return
	_editing_classifier = editing_classifier
	_build_classifier_fields()


func _build_classifier_fields() -> void:
	var internals: VBoxContainer = _window_internals
	for child in internals.get_children():
		internals.remove_child(child)
		child.queue_free()

	var id_value := LineEdit.new()
	id_value.text = String(_editing_classifier.classifier_id)
	id_value.editable = false
	id_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	internals.add_child(_labeled("Classifier ID", id_value))

	_name_input = LineEdit.new()
	_name_input.text = String(_editing_classifier.friendly_name)
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	internals.add_child(_labeled("Classifier Name", _name_input))

	_parent_option = OptionButton.new()
	_parent_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_parent_options()
	internals.add_child(_labeled("Parent Circuit", _parent_option))

	_vector = _VECTOR_FIELD_PREFAB.instantiate() as Vector3iSpinboxField
	_vector.initial_vector = _editing_classifier.coordinates_3D
	internals.add_child(_labeled("3D Position", _vector))

	_kernel_option = OptionButton.new()
	_class_option = OptionButton.new()
	_field_option = OptionButton.new()
	_populate_area_options()
	internals.add_child(_labeled("Kernel Area", _kernel_option))
	internals.add_child(_labeled("Class Area", _class_option))
	internals.add_child(_labeled("Field Area", _field_option))

	var internals_value := LineEdit.new()
	internals_value.text = _editing_classifier.hidden_internals_text()
	internals_value.editable = false
	internals_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	internals.add_child(_labeled("Hidden Internals", internals_value))

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
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(140, 0)
	row.add_child(label)
	row.add_child(control)
	return row


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
	_field_option.clear()
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
		_field_option.add_item(label)
		_area_ids.append(area.cortical_ID)
	_select_area(_kernel_option, _editing_classifier.kernel_area_id)
	_select_area(_class_option, _editing_classifier.class_area_id)
	_select_area(_field_option, _editing_classifier.field_area_id)


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
	_update_button.disabled = true
	var result: FeagiRequestOutput = await FeagiCore.requests.edit_classifier(
		_editing_classifier,
		next_name,
		coords,
		_selected_region_id(),
		_selected_area_id(_kernel_option),
		_selected_area_id(_class_option),
		_selected_area_id(_field_option)
	)
	if result == null or result.has_errored or result.failed_requirement:
		_update_button.disabled = false
		if BV != null and BV.NOTIF != null:
			BV.NOTIF.add_notification("Failed to update classifier.")
		return
	close_window()
