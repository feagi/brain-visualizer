extends BaseDraggableWindow
class_name WindowCreateCorticalArea

const WINDOW_NAME: StringName = "create_cortical"

var _header: HBoxContainer
var _selection: VBoxContainer
var _selection_options: PartSpawnCorticalAreaSelection
var _IOPU_definition
var _custom_definition
var _memory_definition
var _buttons: HBoxContainer
var _add_button: Button
var _validation_message_row: MarginContainer
var _validation_message_label: Label
## Inline validation text (name missing / duplicate); avoids separate error popups for these cases.
const _VALIDATION_ERROR_COLOR: Color = Color(0.95, 0.42, 0.38)
var _type_selected: AbstractCorticalArea.CORTICAL_AREA_TYPE
var _BM_preview: UI_BrainMonitor_InteractivePreview
var _context_region: BrainRegion = null
## When set (before add_child), the dialog opens to the right of this control instead of centered.
var _placement_anchor: Control = null
## Snapshot used when the anchor control may be freed before layout (e.g. template picker closed).
var _placement_anchor_rect: Rect2 = Rect2()
## When true, [member _placement_anchor_rect] is the prior window's top-left (replace flow); else place to the right of it.
var _placement_anchor_rect_exact_top_left: bool = false


func _ready() -> void:
	super()
	_header = _window_internals.get_node("header")
	_selection = _window_internals.get_node("Selection")
	_selection_options = _window_internals.get_node("Selection/options")
	_IOPU_definition = _window_internals.get_node("Definition_IOPU")
	_custom_definition = _window_internals.get_node("Definition_Custom")
	_memory_definition = _window_internals.get_node("Definition_Memory")
	_buttons = _window_internals.get_node("Buttons")
	_add_button = _window_internals.get_node("Buttons/Add")
	_validation_message_row = _window_internals.get_node("ValidationMessageRow")
	_validation_message_label = _window_internals.get_node("ValidationMessageRow/ValidationMessageLabel")
	
	_selection_options.cortical_type_selected.connect(_step_2_set_details)
	_IOPU_definition.unit_id_validation_changed.connect(_on_unit_id_validation_changed)
	_run_center_when_laid_out()


## Called by WindowManager before add_child when opening next to a toolbar button or template window.
func set_placement_anchor(anchor: Control) -> void:
	_placement_anchor = anchor


## Rect in root viewport space; used when [member _placement_anchor] is invalid after layout.
func set_placement_anchor_rect(anchor_rect: Rect2, exact_top_left: bool = false) -> void:
	_placement_anchor_rect = anchor_rect
	_placement_anchor_rect_exact_top_left = exact_top_left


## Place the dialog after theme shrink and layout: anchored to the right, or centered.
func _run_center_when_laid_out() -> void:
	if _placement_anchor_rect.has_area() or (_placement_anchor != null and is_instance_valid(_placement_anchor)):
		# WindowManager keeps us hidden and skips saved position; one layout frame then show at target.
		await get_tree().process_frame
		if _placement_anchor_rect.has_area():
			if _placement_anchor_rect_exact_top_left:
				_position_at_anchor_rect_top_left(_placement_anchor_rect)
			else:
				_position_to_right_of_anchor_rect(_placement_anchor_rect)
		elif _placement_anchor != null and is_instance_valid(_placement_anchor):
			_position_to_right_of_anchor(_placement_anchor)
		else:
			_center_window_in_viewport()
		visible = true
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		_center_window_in_viewport()


func _position_to_right_of_anchor(anchor: Control) -> void:
	var window_size: Vector2i = size
	if window_size.x < 2 or window_size.y < 2:
		window_size = get_combined_minimum_size()
	if window_size.x < 2 or window_size.y < 2:
		return
	var pos: Vector2i = BV.WM.position_window_to_right_of_anchor(self, anchor, window_size)
	if pos != Vector2i.ZERO:
		position = pos
	else:
		_center_window_in_viewport()


func _position_to_right_of_anchor_rect(anchor_rect: Rect2) -> void:
	var window_size: Vector2i = size
	if window_size.x < 2 or window_size.y < 2:
		window_size = get_combined_minimum_size()
	if window_size.x < 2 or window_size.y < 2:
		return
	var pos: Vector2i = BV.WM.position_window_to_right_of_anchor_rect(self, anchor_rect, window_size)
	if pos != Vector2i.ZERO:
		position = pos
	else:
		_center_window_in_viewport()


func _position_at_anchor_rect_top_left(anchor_rect: Rect2) -> void:
	var window_size: Vector2i = size
	if window_size.x < 2 or window_size.y < 2:
		window_size = get_combined_minimum_size()
	if window_size.x < 2 or window_size.y < 2:
		return
	var pos: Vector2i = BV.WM.position_window_at_top_left_of_rect(self, anchor_rect, window_size)
	if pos != Vector2i.ZERO:
		position = pos
	else:
		_center_window_in_viewport()


func _center_window_in_viewport() -> void:
	var rect: Rect2 = get_viewport().get_visible_rect()
	var window_size: Vector2i = size
	if window_size.x < 2 or window_size.y < 2:
		window_size = get_combined_minimum_size()
	if window_size.x < 2 or window_size.y < 2:
		return
	var pos := Vector2i(
		int(floor(rect.position.x + (rect.size.x - float(window_size.x)) * 0.5)),
		int(floor(rect.position.y + (rect.size.y - float(window_size.y)) * 0.5))
	)
	position = pos


func setup() -> void:
	_setup_base_window(WINDOW_NAME)
	_step_1_pick_type()

func setup_with_type(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> void:
	_setup_base_window(WINDOW_NAME)
	_step_2_set_details(cortical_type)

func setup_for_region(context_region: BrainRegion) -> void:
	_context_region = context_region
	setup()

func setup_with_type_for_region(context_region: BrainRegion, cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> void:
	_context_region = context_region
	setup_with_type(cortical_type)

func _step_1_pick_type() -> void:
	_IOPU_definition.visible = false
	_custom_definition.visible = false
	_memory_definition.visible = false
	_buttons.visible = false
	if _validation_message_row != null:
		_validation_message_row.visible = false
	_clear_validation_message()
	_selection.visible = true
	_set_header(AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN)

func _step_2_set_details(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> void:
	_set_header(cortical_type)
	_type_selected = cortical_type
	_selection.visible = false
	
	## All cases that a preview needs to be closed
	var close_preview_signals: Array[Signal] = [
		_window_internals.get_node("Buttons/Back").pressed,
		close_window_requesed_no_arg
	]
	
	# Determine the brain monitor to host previews.
	# IPU/OPU areas belong on the genome root only — never show their preview on a sub-region Brain Monitor tab.
	var host_bm: UI_BrainMonitor_3DScene = null
	if cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU or cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
		var root_region: BrainRegion = null
		if FeagiCore != null and FeagiCore.feagi_local_cache != null and FeagiCore.feagi_local_cache.brain_regions != null:
			root_region = FeagiCore.feagi_local_cache.brain_regions.get_root_region()
		if root_region != null:
			host_bm = BV.UI.get_brain_monitor_for_region(root_region)
		if host_bm == null:
			host_bm = BV.UI.get_temp_root_bm()
	else:
		if _context_region != null:
			host_bm = BV.UI.get_brain_monitor_for_region(_context_region)
		if host_bm == null:
			host_bm = BV.UI.get_active_brain_monitor()
	
	_IOPU_definition.visible = cortical_type in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]
	_custom_definition.visible = cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM
	_memory_definition.visible = cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	_buttons.visible = true
	if _validation_message_row != null:
		_validation_message_row.visible = true
	_clear_validation_message()
	
	# Prefill location BEFORE creating preview so arrow/preview spawn at the right spot
	var last_pos: Vector3i = BV.UI.last_created_cortical_location
	var last_size: Vector3i = BV.UI.last_created_cortical_size
	if last_pos != Vector3i.ZERO:
		match(cortical_type):
			AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
				_custom_definition.location.current_vector = Vector3i(last_pos.x + last_size.x + 8, last_pos.y, last_pos.z)
			AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
				_memory_definition.location.current_vector = Vector3i(last_pos.x + last_size.x + 8, last_pos.y, last_pos.z)
			AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
				_IOPU_definition.location.current_vector = Vector3i(last_pos.x + last_size.x + 8, last_pos.y, last_pos.z)

	match(cortical_type):
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			_IOPU_definition.cortical_type_selected(cortical_type, close_preview_signals, host_bm)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			_IOPU_definition.cortical_type_selected(cortical_type, close_preview_signals, host_bm)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			_custom_definition.cortical_type_selected(cortical_type, close_preview_signals, host_bm)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			_memory_definition.cortical_type_selected(cortical_type, close_preview_signals, host_bm)
	
	# Focus the mandatory name field and hook Enter to submit for CUSTOM and MEMORY
	if cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
		_focus_and_hook_name_field(_custom_definition.cortical_name)
	elif cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
		_focus_and_hook_name_field(_memory_definition.cortical_name)
	

func _set_header(cortical_type: AbstractCorticalArea.CORTICAL_AREA_TYPE) -> void:
	var label: Label = _window_internals.get_node("header/Label")
	var icon: TextureRect = _window_internals.get_node("header/icon")
	if cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.UNKNOWN:
		label.text = "Select Cortical Area Type:"
		icon.texture = null # clear texture
		return
	match(cortical_type):
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			label.text = "Adding input Cortical Area"
			icon.texture = load("res://BrainVisualizer/UI/GenericResources/ButtonIcons/input.png")
			_header.visible = false
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			label.text = "Adding output Cortical Area"
			icon.texture = load("res://BrainVisualizer/UI/GenericResources/ButtonIcons/output.png")
			_header.visible = false
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			label.text = "Adding interconnect Cortical Area"
			icon.texture = load("res://BrainVisualizer/UI/GenericResources/ButtonIcons/interconnected.png")
			_header.visible = true
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			label.text = "Adding memory Cortical Area"
			icon.texture = load("res://BrainVisualizer/UI/GenericResources/ButtonIcons/memory-game.png")
			_header.visible = true
		
## Focus a LineEdit and hook Enter to submit
func _focus_and_hook_name_field(le: LineEdit) -> void:
	if le == null:
		return
	# Focus so user can type immediately
	le.grab_focus()
	# Guard against multiple connections
	if not le.text_submitted.is_connected(_on_name_enter_submit):
		le.text_submitted.connect(_on_name_enter_submit)
	if le is AbstractLineInput and not le.user_interacted.is_connected(_on_name_field_user_interacted):
		le.user_interacted.connect(_on_name_field_user_interacted)


func _on_name_field_user_interacted() -> void:
	_clear_validation_message()


func _clear_validation_message() -> void:
	if _validation_message_label == null:
		return
	_validation_message_label.text = ""
	_validation_message_label.remove_theme_color_override("font_color")


func _show_inline_validation_error(message: String) -> void:
	if _validation_message_label == null:
		return
	_validation_message_label.text = message
	_validation_message_label.add_theme_color_override("font_color", _VALIDATION_ERROR_COLOR)

func _on_name_enter_submit(_text: String) -> void:
	_user_requesing_creation()

func _on_unit_id_validation_changed(is_valid: bool, message: String) -> void:
	if _add_button != null:
		_add_button.disabled = !is_valid
		if !is_valid:
			_add_button.tooltip_text = message
		else:
			_add_button.tooltip_text = ""

func _back_pressed() -> void:
	# If user was selecting an IPU/OPU template via the icon selector, return to that selector
	if _type_selected == AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU or _type_selected == AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
		close_window()
		if _context_region != null:
			BV.WM.spawn_create_cortical_with_type_for_region(_context_region, _type_selected)
		else:
			BV.WM.spawn_create_cortical_with_type(_type_selected)
		return
	# Otherwise fall back to the internal type selection step
	_step_1_pick_type()

func _user_requesting_exit() -> void:
	close_window()

func _user_requesing_creation() -> void:
	
	var rand: RandomNumberGenerator = RandomNumberGenerator.new()
	var pos_2d: Vector2 = Vector2(rand.randf_range(-100.0, 100.0), rand.randf_range(-100.0, 100.0))	
	
	match(_type_selected):
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			var template: CorticalTemplate = _IOPU_definition.get_selected_template()
			if template == null:
				var popup_definition_ipu: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "Please select an input device", "OK")
				BV.WM.spawn_popup(popup_definition_ipu)
				return
			var device_count: int = int(_IOPU_definition.device_count.value)
			var selected_unit_id: int = _IOPU_definition.get_selected_unit_id()
			var neurons_per_voxel: int = _IOPU_definition.get_neurons_per_voxel()
			
			if AbstractCorticalArea.get_neuron_count(template.calculate_IOPU_dimension(device_count), 1.0) + FeagiCore.feagi_local_cache.neuron_count_current > FeagiCore.feagi_local_cache.neuron_count_max:
				var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "The resultant cortical area adds too many neurons!!", "OK")
				BV.WM.spawn_popup(popup_definition)
				return
			
			if template.ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
				# Area exists, update
				var area: IPUCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[template.ID]
				if device_count == 0:
					# delete area since the calculated dimensions would be 0
					var areas_to_delete: Array[GenomeObject] = [area]
					BV.UI.window_manager.spawn_confirm_deletion(areas_to_delete)
				else:
					# update area
					var new_dimension_property: Dictionary = {"cortical_dimensions" = FEAGIUtils.vector3i_to_array(template.calculate_IOPU_dimension(device_count))}
					FeagiCore.requests.update_cortical_area(area.cortical_ID, new_dimension_property)
			
			else:
				# Area doesnt exist, create (unless device count is 0, the ignore)
				if _IOPU_definition.device_count.value != 0:
					var data_type_configs_by_subunit: Dictionary = _IOPU_definition.get_selected_data_type_configs_by_subunit()
					var result: FeagiRequestOutput = await FeagiCore.requests.add_IOPU_cortical_area(
						template,
						int(_IOPU_definition.device_count.value),
						_IOPU_definition.location.current_vector,
						true,
						pos_2d,
						selected_unit_id,
						neurons_per_voxel,
						data_type_configs_by_subunit
					)
					if result.has_errored:
						var error_details = result.decode_response_as_generic_error_code()
						var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup(
							"NPU CAPACITY ERROR", 
							"Failed to create cortical area:\n%s\n\n%s" % [error_details[0], error_details[1]], 
							"OK"
						)
						BV.WM.spawn_popup(popup_definition)
						return
					# Wait a frame to ensure visualization is rendered before cleaning up preview
					await get_tree().process_frame
					# Explicitly clear previews for IOPU areas to ensure they're removed
					_IOPU_definition._clear_all_previews()
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			var template: CorticalTemplate = _IOPU_definition.get_selected_template()
			if template == null:
				var popup_definition_opu: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "Please select an output device", "OK")
				BV.WM.spawn_popup(popup_definition_opu)
				return
			var device_count: int = int(_IOPU_definition.device_count.value)
			var selected_unit_id: int = _IOPU_definition.get_selected_unit_id()
			var neurons_per_voxel: int = _IOPU_definition.get_neurons_per_voxel()
			
			if AbstractCorticalArea.get_neuron_count(template.calculate_IOPU_dimension(device_count), 1.0) + FeagiCore.feagi_local_cache.neuron_count_current > FeagiCore.feagi_local_cache.neuron_count_max:
				var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "The resultant cortical area adds too many neurons!!", "OK")
				BV.WM.spawn_popup(popup_definition)
				return
				
			if template.ID in FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas.keys():
				# Area exists, update
				var area: OPUCorticalArea = FeagiCore.feagi_local_cache.cortical_areas.available_cortical_areas[template.ID]
				if device_count == 0:
					# delete area since the calculated dimensions would be 0
					var areas_to_delete: Array[GenomeObject] = [area]
					BV.UI.window_manager.spawn_confirm_deletion(areas_to_delete)
				else:
					# update area
					var new_dimension_property: Dictionary = {"cortical_dimensions" = FEAGIUtils.vector3i_to_array(template.calculate_IOPU_dimension(device_count))}
					FeagiCore.requests.update_cortical_area(area.cortical_ID, new_dimension_property)
			
			else:
				# Area doesnt exist, create (unless device count is 0, the ignore)
				if _IOPU_definition.device_count.value != 0:
					var data_type_configs_by_subunit_opu: Dictionary = _IOPU_definition.get_selected_data_type_configs_by_subunit()
					var result: FeagiRequestOutput = await FeagiCore.requests.add_IOPU_cortical_area(
						template,
						int(_IOPU_definition.device_count.value),
						_IOPU_definition.location.current_vector,
						true,
						pos_2d,
						selected_unit_id,
						neurons_per_voxel,
						data_type_configs_by_subunit_opu
					)
					if result.has_errored:
						var error_details = result.decode_response_as_generic_error_code()
						var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup(
							"NPU CAPACITY ERROR", 
							"Failed to create cortical area:\n%s\n\n%s" % [error_details[0], error_details[1]], 
							"OK"
						)
						BV.WM.spawn_popup(popup_definition)
						return
					# Wait a frame to ensure visualization is rendered before cleaning up preview
					await get_tree().process_frame
					# Explicitly clear previews for IOPU areas to ensure they're removed
					_IOPU_definition._clear_all_previews()
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			# Checks...
			if _custom_definition.cortical_name.text == "":
				_show_inline_validation_error("Please define a name for your cortical area")
				return
			
			if AbstractCorticalArea.get_neuron_count(_custom_definition.dimensions.current_vector, 1.0) + FeagiCore.feagi_local_cache.neuron_count_current > FeagiCore.feagi_local_cache.neuron_count_max:
				var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "The resultant cortical area adds too many neurons!!", "OK")
				BV.WM.spawn_popup(popup_definition)
				return
			
			if FeagiCore.feagi_local_cache.cortical_areas.exist_cortical_area_of_name(_custom_definition.cortical_name.text):
				_show_inline_validation_error("This name is already taken!")
				return
			
			#Create
			var parent_region: BrainRegion = _context_region if _context_region != null else FeagiCore.feagi_local_cache.brain_regions.get_root_region()
			FeagiCore.requests.add_custom_cortical_area(
				_custom_definition.cortical_name.text,
				_custom_definition.location.current_vector,
				_custom_definition.dimensions.current_vector,
				parent_region,
				true,
				pos_2d
				)
			# Update session last-created position and size
			BV.UI.last_created_cortical_location = _custom_definition.location.current_vector
			BV.UI.last_created_cortical_size = _custom_definition.dimensions.current_vector
				
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			# Checks...
			if _memory_definition.cortical_name.text == "":
				_show_inline_validation_error("Please define a name for your cortical area")
				return
			
			if FeagiCore.feagi_local_cache.cortical_areas.exist_cortical_area_of_name(_memory_definition.cortical_name.text):
				_show_inline_validation_error("This name is already taken!")
				return
			var memory_dims: Vector3i = Vector3i(1, 1, 1)
			if AbstractCorticalArea.get_neuron_count(memory_dims, 1.0) + FeagiCore.feagi_local_cache.neuron_count_current > FeagiCore.feagi_local_cache.neuron_count_max:
				var popup_definition_mem: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "The resultant cortical area adds too many neurons!!", "OK")
				BV.WM.spawn_popup(popup_definition_mem)
				return
			
			var parent_region_mem: BrainRegion = _context_region if _context_region != null else FeagiCore.feagi_local_cache.brain_regions.get_root_region()
			var create_result: FeagiRequestOutput = await FeagiCore.requests.add_custom_memory_cortical_area(
				_memory_definition.cortical_name.text,
				_memory_definition.location.current_vector,
				memory_dims,
				parent_region_mem,
				true,
				pos_2d
			)
			if create_result.has_errored:
				var err_details = create_result.decode_response_as_generic_error_code()
				var popup_create_fail: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup(
					"ERROR",
					"Failed to create memory cortical area:\n%s\n\n%s" % [err_details[0], err_details[1]],
					"OK"
				)
				BV.WM.spawn_popup(popup_create_fail)
				return
			var response_dict: Dictionary = create_result.decode_response_as_dict()
			var new_cortical_id: StringName = StringName(str(response_dict.get("cortical_id", "")))
			if new_cortical_id != &"":
				var mem_props: Dictionary = _memory_definition.get_memory_parameters_for_api()
				var update_result: FeagiRequestOutput = await FeagiCore.requests.update_cortical_area(new_cortical_id, mem_props)
				if update_result.has_errored:
					var upd_err = update_result.decode_response_as_generic_error_code()
					var popup_upd_fail: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup(
						"ERROR",
						"Memory area was created but applying memory settings failed:\n%s\n\n%s" % [upd_err[0], upd_err[1]],
						"OK"
					)
					BV.WM.spawn_popup(popup_upd_fail)
					return
			BV.UI.last_created_cortical_location = _memory_definition.location.current_vector
			BV.UI.last_created_cortical_size = memory_dims
	
	close_window()
