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
var _type_selected: AbstractCorticalArea.CORTICAL_AREA_TYPE
var _BM_preview: UI_BrainMonitor_InteractivePreview
var _context_region: BrainRegion = null


func _ready() -> void:
	super()
	_header = _window_internals.get_node("header")
	_selection = _window_internals.get_node("Selection")
	_selection_options = _window_internals.get_node("Selection/options")
	_IOPU_definition = _window_internals.get_node("Definition_IOPU")
	_custom_definition = _window_internals.get_node("Definition_Custom")
	_memory_definition = _window_internals.get_node("Definition_Memory")
	_buttons = _window_internals.get_node("Buttons")
	
	_selection_options.cortical_type_selected.connect(_step_2_set_details)


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
	
	# Determine the brain monitor to host previews: prefer region's BM if provided
	var host_bm: UI_BrainMonitor_3DScene = null
	if _context_region != null:
		host_bm = BV.UI.get_brain_monitor_for_region(_context_region)
	if host_bm == null:
		host_bm = BV.UI.get_active_brain_monitor()
	
	_IOPU_definition.visible = cortical_type in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]
	_custom_definition.visible = cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM
	_memory_definition.visible = cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	_buttons.visible = true
	
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

func _on_name_enter_submit(_text: String) -> void:
	_user_requesing_creation()

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
					FeagiCore.requests.add_IOPU_cortical_area(
						template,
						int(_IOPU_definition.device_count.value),
						_IOPU_definition.location.current_vector,
						true,
						pos_2d
					)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			var template: CorticalTemplate = _IOPU_definition.get_selected_template()
			if template == null:
				var popup_definition_opu: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "Please select an output device", "OK")
				BV.WM.spawn_popup(popup_definition_opu)
				return
			var device_count: int = int(_IOPU_definition.device_count.value)
			
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
					FeagiCore.requests.add_IOPU_cortical_area(
						template,
						int(_IOPU_definition.device_count.value),
						_IOPU_definition.location.current_vector,
						true,
						pos_2d
					)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			# Checks...
			if _custom_definition.cortical_name.text == "":
				var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "Please define a name for your cortical area", "OK")
				BV.WM.spawn_popup(popup_definition)
				return
			
			if AbstractCorticalArea.get_neuron_count(_custom_definition.dimensions.current_vector, 1.0) + FeagiCore.feagi_local_cache.neuron_count_current > FeagiCore.feagi_local_cache.neuron_count_max:
				var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "The resultant cortical area adds too many neurons!!", "OK")
				BV.WM.spawn_popup(popup_definition)
				return
			
			if FeagiCore.feagi_local_cache.cortical_areas.exist_cortical_area_of_name(_custom_definition.cortical_name.text):
				var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "This name is already taken!", "OK")
				BV.WM.spawn_popup(popup_definition)
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
				
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			# Checks...
			if _memory_definition.cortical_name.text == "":
				var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "Please define a name for your cortical area", "OK")
				BV.WM.spawn_popup(popup_definition)
				return
			
			if FeagiCore.feagi_local_cache.cortical_areas.exist_cortical_area_of_name(_memory_definition.cortical_name.text):
				var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "This name is already taken!", "OK")
				BV.WM.spawn_popup(popup_definition)
				return
			if AbstractCorticalArea.get_neuron_count(_custom_definition.dimensions.current_vector, 1.0) + FeagiCore.feagi_local_cache.neuron_count_current > FeagiCore.feagi_local_cache.neuron_count_max:
				var popup_definition: ConfigurablePopupDefinition = ConfigurablePopupDefinition.create_single_button_close_popup("ERROR", "The resultant cortical area adds too many neurons!!", "OK")
				BV.WM.spawn_popup(popup_definition)
				return
			
			#Create
			var parent_region_mem: BrainRegion = _context_region if _context_region != null else FeagiCore.feagi_local_cache.brain_regions.get_root_region()
			FeagiCore.requests.add_custom_memory_cortical_area(
				_memory_definition.cortical_name.text,
				_memory_definition.location.current_vector,
				Vector3i(1,1,1),
				parent_region_mem,
				true,
				pos_2d
			)
	
	close_window()
