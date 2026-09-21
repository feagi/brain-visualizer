extends BaseDraggableWindow
class_name WindowCreateClassifier

const WINDOW_NAME: StringName = "create_classifier"
const _VALIDATION_ERROR_COLOR: Color = Color(1.0, 0.35, 0.35)
const _VECTOR_FIELD_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Vectors/Vector3iSpinBoxField.tscn")
var _name_input: LineEdit
var _vector: Vector3iSpinboxField
var _kernel_option: OptionButton
var _class_option: OptionButton
var _field_option: OptionButton
var _validation_label: Label
var _create_button: Button
var _location: Vector3i
var _context_region: BrainRegion = null
var _area_ids: Array[StringName] = []
var _host_bm: UI_BrainMonitor_3DScene = null
var _preview: UI_BrainMonitor_InteractivePreview = null


func _ready() -> void:
	super()
	_build_ui()
	visible = true
	if _name_input != null:
		_name_input.grab_focus()


func setup_for_region(context_region: BrainRegion, coordinates_3d: Vector3i = Vector3i.ZERO) -> void:
	_setup_base_window(WINDOW_NAME)
	_context_region = context_region
	_location = coordinates_3d
	_populate_area_options()
	_apply_default_position()
	_clear_validation()
	_connect_preview_controls()
	_refresh_stamp_preview()


func _build_ui() -> void:
	var internals: VBoxContainer = _window_internals
	var title := Label.new()
	title.text = "The stamp is the memory assembly. Width and height grow with stored memory neurons; depth is classifier temporal depth. A separate twin area is created beside the field."
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	internals.add_child(title)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Classifier name"
	_name_input.text_changed.connect(func(_text: String) -> void: _clear_validation())
	internals.add_child(_name_input)

	_vector = _VECTOR_FIELD_PREFAB.instantiate() as Vector3iSpinboxField
	internals.add_child(_labeled("3D Position", _vector))

	_kernel_option = OptionButton.new()
	_class_option = OptionButton.new()
	_field_option = OptionButton.new()
	internals.add_child(_labeled("Kernel area", _kernel_option))
	internals.add_child(_labeled("Class area", _class_option))
	internals.add_child(_labeled("Field area", _field_option))

	_validation_label = Label.new()
	_validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	internals.add_child(_validation_label)

	_create_button = Button.new()
	_create_button.text = "Create Classifier"
	_create_button.pressed.connect(_on_create_pressed)
	internals.add_child(_create_button)


func _labeled(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _connect_preview_controls() -> void:
	if _vector != null and not _vector.user_updated_vector.is_connected(_on_position_changed):
		_vector.user_updated_vector.connect(_on_position_changed)
	if _field_option != null and not _field_option.item_selected.is_connected(_on_area_selection_changed):
		_field_option.item_selected.connect(_on_area_selection_changed)
	if _class_option != null and not _class_option.item_selected.is_connected(_on_area_selection_changed):
		_class_option.item_selected.connect(_on_area_selection_changed)
	if not close_window_requesed_no_arg.is_connected(_cleanup_stamp_preview):
		close_window_requesed_no_arg.connect(_cleanup_stamp_preview)


func _on_position_changed(new_position: Vector3i) -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.set_new_position(new_position)


func _on_area_selection_changed(_index: int) -> void:
	_refresh_stamp_preview()


func _host_brain_monitor() -> UI_BrainMonitor_3DScene:
	if _context_region != null:
		var region_bm: UI_BrainMonitor_3DScene = BV.UI.get_brain_monitor_for_region(_context_region)
		if region_bm != null:
			return region_bm
	return BV.UI.get_active_brain_monitor()


func _stamp_preview_dimensions() -> Vector3i:
	return GenomeClassifier.stamp_visual_dimensions(1, 1)


func _refresh_stamp_preview() -> void:
	_host_bm = _host_brain_monitor()
	if _host_bm == null:
		return
	var position_3d: Vector3i = _placement_coordinates()
	var dimensions: Vector3i = _stamp_preview_dimensions()
	if _preview == null or not is_instance_valid(_preview):
		_preview = _host_bm.create_preview(
			position_3d,
			dimensions,
			false,
			AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM,
			null,
			true,
			true
		)
		if _host_bm.has_method("start_cortical_preview_relocation"):
			_host_bm.start_cortical_preview_relocation(
				_preview,
				position_3d,
				Callable(self, "_on_preview_moved_via_gizmo")
			)
	else:
		_preview.set_new_position(position_3d)
		_preview.set_new_dimensions(dimensions)
	if _preview.has_method("apply_classifier_stamp_look"):
		_preview.apply_classifier_stamp_look(dimensions.z)


func _on_preview_moved_via_gizmo(new_coords: Vector3i) -> void:
	if _vector != null:
		_vector.current_vector = new_coords


func _cleanup_stamp_preview() -> void:
	if _preview != null and is_instance_valid(_preview):
		if _host_bm != null and _host_bm.has_method("stop_cortical_preview_relocation"):
			_host_bm.stop_cortical_preview_relocation(_preview)
		_preview.queue_free()
	_preview = null
	_host_bm = null


func _populate_area_options() -> void:
	_kernel_option.clear()
	_class_option.clear()
	_field_option.clear()
	_area_ids.clear()
	for area in _candidate_areas():
		if area == null:
			continue
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


func _candidate_areas() -> Array[AbstractCorticalArea]:
	var areas: Array[AbstractCorticalArea] = []
	if _context_region != null:
		for area in _context_region.contained_cortical_areas:
			if area != null and area not in areas:
				areas.append(area)
	if areas.is_empty():
		for area in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.values():
			if area is AbstractCorticalArea:
				areas.append(area)
	areas.sort_custom(func(a: AbstractCorticalArea, b: AbstractCorticalArea) -> bool:
		return String(a.friendly_name).to_lower() < String(b.friendly_name).to_lower()
	)
	return areas


func _selected_area_id(option: OptionButton) -> StringName:
	if option == null or option.selected < 0 or option.selected >= _area_ids.size():
		return &""
	return _area_ids[option.selected]


func _apply_default_position() -> void:
	if _vector == null:
		return
	_vector.current_vector = _default_placement_coordinates(_selected_area_id(_kernel_option), _selected_area_id(_field_option))


func _default_placement_coordinates(kernel_id: StringName, field_id: StringName) -> Vector3i:
	if _location != Vector3i.ZERO:
		return _location
	if BV.UI != null:
		var last_pos: Vector3i = BV.UI.last_created_cortical_location
		var last_size: Vector3i = BV.UI.last_created_cortical_size
		if last_pos != Vector3i.ZERO:
			return Vector3i(last_pos.x + last_size.x + 8, last_pos.y, last_pos.z)
	var field_area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(field_id, null)
	if field_area != null:
		return Vector3i(field_area.coordinates_3D.x + field_area.dimensions_3D.x + 8, field_area.coordinates_3D.y, field_area.coordinates_3D.z)
	var kernel_area: AbstractCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.get(kernel_id, null)
	if kernel_area != null:
		return Vector3i(kernel_area.coordinates_3D.x + kernel_area.dimensions_3D.x + 8, kernel_area.coordinates_3D.y, kernel_area.coordinates_3D.z)
	return Vector3i.ZERO


func _placement_coordinates() -> Vector3i:
	return _vector.current_vector


func _show_validation(message: String) -> void:
	if _validation_label == null:
		return
	_validation_label.text = message
	_validation_label.add_theme_color_override("font_color", _VALIDATION_ERROR_COLOR)


func _clear_validation() -> void:
	if _validation_label == null:
		return
	_validation_label.text = ""
	_validation_label.remove_theme_color_override("font_color")


func _on_create_pressed() -> void:
	_clear_validation()
	if _context_region == null:
		_show_validation("Classifier must be created inside a brain region.")
		return
	var classifier_name: String = _name_input.text.strip_edges()
	if classifier_name.is_empty():
		_show_validation("Enter a classifier name.")
		return
	if FeagiCore.feagi_local_cache.cortical_areas.exist_cortical_area_of_name(StringName(classifier_name + "_kernel_mem")):
		_show_validation("A classifier using this name already exists.")
		return
	if _area_ids.is_empty() or _kernel_option.selected < 0 or _class_option.selected < 0 or _field_option.selected < 0:
		_show_validation("Kernel, class, and field must be non-memory areas in this region.")
		return
	var kernel_id: StringName = _area_ids[_kernel_option.selected]
	var class_id: StringName = _area_ids[_class_option.selected]
	var field_id: StringName = _area_ids[_field_option.selected]
	_create_button.disabled = true
	var coordinates_3d: Vector3i = _placement_coordinates()
	var stamp_size: Vector3i = _stamp_preview_dimensions()
	var result: FeagiRequestOutput = await FeagiCore.requests.add_classifier_assembly(
		classifier_name,
		coordinates_3d,
		_context_region,
		kernel_id,
		class_id,
		field_id
	)
	if result == null or result.has_errored or result.failed_requirement:
		_create_button.disabled = false
		var error_text: String = "Failed to create classifier."
		if result != null:
			var error_details = result.decode_response_as_generic_error_code()
			error_text = "Failed to create classifier:\n%s\n%s" % [error_details[0], error_details[1]]
		_show_validation(error_text)
		var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup(
			"ERROR",
			error_text,
			"OK"
		)
		BV.WM.spawn_popup(popup_definition)
		return
	BV.UI.last_created_cortical_location = coordinates_3d
	BV.UI.last_created_cortical_size = stamp_size
	_cleanup_stamp_preview()
	close_window()
