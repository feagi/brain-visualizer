extends BaseDraggableWindow
class_name WindowCreateClassifier

const WINDOW_NAME: StringName = "create_classifier"
const _Tunables = preload("res://BrainVisualizer/UI/Windows/EditClassifier/EditClassifierTunables.gd")
const _VALIDATION_ERROR_COLOR: Color = Color(1.0, 0.35, 0.35)
const _VECTOR_FIELD_PREFAB: PackedScene = preload("res://BrainVisualizer/UI/GenericElements/Vectors/Vector3iSpinBoxField.tscn")
var _name_input: LineEdit
var _vector: Vector3iSpinboxField
var _validation_label: Label
var _create_button: Button
var _location: Vector3i
var _context_region: BrainRegion = null
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
	_apply_default_position()
	_clear_validation()
	_connect_preview_controls()
	_refresh_stamp_preview()


func _build_ui() -> void:
	var internals: VBoxContainer = _window_internals
	var title := Label.new()
	title.text = "Create the classifier, then connect sample and class inputs with Quick Connect."
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	internals.add_child(title)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Classifier name"
	_name_input.text_changed.connect(func(_text: String) -> void: _clear_validation())
	internals.add_child(_name_input)

	_vector = _VECTOR_FIELD_PREFAB.instantiate() as Vector3iSpinboxField
	internals.add_child(_labeled("3D Position", _vector))

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
	var tip: String = _Tunables.setting_tooltip(label_text)
	if not tip.is_empty():
		row.tooltip_text = tip
		label.tooltip_text = tip
		control.tooltip_text = tip
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _connect_preview_controls() -> void:
	if _vector != null and not _vector.user_updated_vector.is_connected(_on_position_changed):
		_vector.user_updated_vector.connect(_on_position_changed)
	if not close_window_requesed_no_arg.is_connected(_cleanup_stamp_preview):
		close_window_requesed_no_arg.connect(_cleanup_stamp_preview)


func _on_position_changed(new_position: Vector3i) -> void:
	if _preview != null and is_instance_valid(_preview):
		_preview.set_new_position(new_position)


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


func _apply_default_position() -> void:
	if _vector == null:
		return
	_vector.current_vector = _default_placement_coordinates()


func _default_placement_coordinates() -> Vector3i:
	if _location != Vector3i.ZERO:
		return _location
	if BV.UI != null:
		var last_pos: Vector3i = BV.UI.last_created_cortical_location
		var last_size: Vector3i = BV.UI.last_created_cortical_size
		if last_pos != Vector3i.ZERO:
			return Vector3i(last_pos.x + last_size.x + 8, last_pos.y, last_pos.z)
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
	if FeagiCore.feagi_local_cache.cortical_areas.exist_cortical_area_of_name(StringName(classifier_name + "_sample_mem")):
		_show_validation("A classifier using this name already exists.")
		return
	_create_button.disabled = true
	var coordinates_3d: Vector3i = _placement_coordinates()
	var result: FeagiRequestOutput = await FeagiCore.requests.add_classifier_assembly(
		classifier_name,
		coordinates_3d,
		_context_region
	)
	_finish_create(result, coordinates_3d)


func _finish_create(result: FeagiRequestOutput, coordinates_3d: Vector3i) -> void:
	var stamp_size: Vector3i = _stamp_preview_dimensions()
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
