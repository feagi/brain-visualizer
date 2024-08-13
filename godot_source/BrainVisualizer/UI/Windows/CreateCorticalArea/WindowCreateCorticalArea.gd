extends BaseDraggableWindow
class_name WindowCreateCorticalArea

const WINDOW_NAME: StringName = "create_cortical"

var _header: HBoxContainer
var _selection: VBoxContainer
var _selection_options: PartSpawnCorticalAreaSelection
var _IOPU_definition: PartSpawnCorticalAreaIOPU
var _custom_definition: PartSpawnCorticalAreaCustom
var _memory_definition: PartSpawnCorticalAreaMemory
var _buttons: HBoxContainer
var _type_selected: AbstractCorticalArea.CORTICAL_AREA_TYPE


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
	
	_IOPU_definition.visible = cortical_type in [AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU, AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU]
	_custom_definition.visible = cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM
	_memory_definition.visible = cortical_type == AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY
	_buttons.visible = true
	
	match(cortical_type):
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			_IOPU_definition.cortical_type_selected(cortical_type, close_preview_signals)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			_IOPU_definition.cortical_type_selected(cortical_type, close_preview_signals)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.CUSTOM:
			_custom_definition.cortical_type_selected(cortical_type, close_preview_signals)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.MEMORY:
			_memory_definition.cortical_type_selected(cortical_type, close_preview_signals)
	

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
		
func _back_pressed() -> void:
	_step_1_pick_type()

func _user_requesting_exit() -> void:
	close_window()

func _user_requesing_creation() -> void:
	
	
	
	match(_type_selected):
		AbstractCorticalArea.CORTICAL_AREA_TYPE.IPU:
			var template: CorticalTemplate = _IOPU_definition.dropdown.get_selected_template()
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
						_IOPU_definition.dropdown.get_selected_template(),
						int(_IOPU_definition.device_count.value),
						_IOPU_definition.location.current_vector,
						false
					)
		AbstractCorticalArea.CORTICAL_AREA_TYPE.OPU:
			var template: CorticalTemplate = _IOPU_definition.dropdown.get_selected_template()
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
						_IOPU_definition.dropdown.get_selected_template(),
						int(_IOPU_definition.device_count.value),
						_IOPU_definition.location.current_vector,
						false
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
			FeagiCore.requests.add_custom_cortical_area(
				_custom_definition.cortical_name.text,
				_custom_definition.location.current_vector,
				_custom_definition.dimensions.current_vector,
				FeagiCore.feagi_local_cache.brain_regions.get_root_region(), #TODO TEMP
				false
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
			FeagiCore.requests.add_custom_memory_cortical_area(
				_memory_definition.cortical_name.text,
				_memory_definition.location.current_vector,
				Vector3i(1,1,1),
				FeagiCore.feagi_local_cache.brain_regions.get_root_region(), #TODO temp!
				false
			)
	
	close_window()
