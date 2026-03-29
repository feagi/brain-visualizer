extends VBoxContainer
class_name MappingEditorMemoryMapping

signal user_changed_something()

var _morphologies: MorphologyDropDown
var _scalar: Vector3iField
var _PSP: FloatInput
var _inhibitory: ToggleButton
var _plasticity: ToggleButton
var _plasticity_window: IntInput
var _plasticity_constant: FloatInput
var _LTP_multiplier: FloatInput
var _LTD_multiplier: FloatInput
var _edit: TextureButton
var _row_container: HBoxContainer
var _header_row_wrapper: HBoxContainer

func _ready() -> void:
	_initialize_references()
	if _row_container != null and _header_row_wrapper != null:
		_row_container.resized.connect(_align_headers_to_row)
		call_deferred("_align_headers_to_row")

func _initialize_references() -> void:
	if _row_container != null:
		return
	_row_container = $RowContainer
	_header_row_wrapper = $HeaderRowWrapper
	_morphologies = $RowContainer/MappingDefinitionGroup/Morphology_List
	_scalar = $RowContainer/Scalar
	_PSP = $RowContainer/PSP
	_inhibitory = $RowContainer/Inhibitory
	_plasticity = $RowContainer/Plasticity
	_plasticity_window = $RowContainer/Plasticity_Window
	_plasticity_constant = $RowContainer/Plasticity_Constant
	_LTP_multiplier = $RowContainer/LTP_Multiplier
	_LTD_multiplier = $RowContainer/LTD_Multiplier
	_edit = $RowContainer/MappingDefinitionGroup/edit

func _align_headers_to_row() -> void:
	if not is_instance_valid(_row_container) or not is_instance_valid(_header_row_wrapper):
		return
	await get_tree().process_frame
	var header_box: HBoxContainer = _header_row_wrapper.get_node("labels_box") as HBoxContainer
	if header_box == null or _row_container == null:
		return
	
	var row_count: int = _row_container.get_child_count()
	var header_count: int = header_box.get_child_count()
	var pair_count: int = mini(row_count, header_count)
	
	for idx in range(pair_count):
		var row_node: Control = _row_container.get_child(idx) as Control
		var header_node: Control = header_box.get_child(idx) as Control
		if row_node == null or header_node == null:
			continue
		var w_row: float = row_node.size.x
		if w_row <= 0.001:
			w_row = row_node.get_combined_minimum_size().x
		if w_row <= 0.001:
			continue
		
		if header_node is HBoxContainer and row_node is HBoxContainer:
			var hg: HBoxContainer = header_node as HBoxContainer
			var rg: HBoxContainer = row_node as HBoxContainer
			var inner_n: int = mini(hg.get_child_count(), rg.get_child_count())
			for j in range(inner_n):
				var rc: Control = rg.get_child(j) as Control
				var hc: Control = hg.get_child(j) as Control
				if rc == null or hc == null:
					continue
				var w_inner: float = rc.size.x
				if w_inner <= 0.001:
					w_inner = rc.get_combined_minimum_size().x
				if w_inner <= 0.001:
					continue
				hc.custom_minimum_size = Vector2(w_inner, hc.custom_minimum_size.y)
			header_node.custom_minimum_size = Vector2(w_row, header_node.custom_minimum_size.y)
		else:
			header_node.custom_minimum_size = Vector2(w_row, header_node.custom_minimum_size.y)

func load_mappings(mappings: Array[SingleMappingDefinition]) -> void:
	_initialize_references()
	
	var episodic_memory: BaseMorphology = FeagiCore.feagi_local_cache.morphologies.available_morphologies.get("episodic_memory")
	if episodic_memory == null:
		push_error("WINDOW MAPPING EDITOR: episodic_memory morphology not found!")
		_row_container.visible = false
		return
	
	_morphologies.overwrite_morphologies([episodic_memory])
	_morphologies.set_selected_morphology(episodic_memory)
	_morphologies.disabled = true
	
	_scalar.editable = false
	_PSP.editable = false
	_plasticity_window.editable = false
	_plasticity_constant.editable = false
	_LTP_multiplier.editable = false
	_LTD_multiplier.editable = false
	
	if len(mappings) == 0:
		var default_mapping: SingleMappingDefinition = SingleMappingDefinition.create_default_mapping(episodic_memory)
		_load_single_mapping(default_mapping)
		_row_container.visible = true
		call_deferred("_align_headers_to_row")
		return
	
	if len(mappings) > 1:
		push_error("WINDOW MAPPING EDITOR: Invalid number of mappings towards a memory area!")
		_row_container.visible = false
		return
	
	var first_mapping: SingleMappingDefinition = mappings[0]
	if first_mapping.morphology_used.name != "episodic_memory":
		push_error("WINDOW MAPPING EDITOR: Invalid morphology %s for memory mapping!" % first_mapping.morphology_used.name)
		_row_container.visible = false
		return
	
	_load_single_mapping(first_mapping)
	_row_container.visible = true
	call_deferred("_align_headers_to_row")

func _load_single_mapping(mapping: SingleMappingDefinition) -> void:
	_morphologies.set_selected_morphology(mapping.morphology_used)
	_scalar.current_vector = mapping.scalar
	_PSP.current_float = absf(mapping.post_synaptic_current_multiplier)
	_inhibitory.set_toggle_no_signal(mapping.post_synaptic_current_multiplier < 0)
	_plasticity.set_toggle_no_signal(mapping.is_plastic)
	_plasticity_window.current_int = mapping.plasticity_window
	_plasticity_constant.current_float = mapping.plasticity_constant
	_LTP_multiplier.current_float = mapping.LTP_multiplier
	_LTD_multiplier.current_float = mapping.LTD_multiplier
	
func export_mappings() -> Array[SingleMappingDefinition]:
	_initialize_references()
	
	if not _row_container.visible:
		return []
	
	var morphology_used: BaseMorphology = _morphologies.get_selected_morphology()
	var scalar: Vector3i = _scalar.current_vector
	var PSP: float = _PSP.current_float
	if _inhibitory.button_pressed:
		PSP = -PSP
	var is_plastic: bool = _plasticity.button_pressed
	var plasticity_constant: float = _plasticity_constant.current_float
	var plasticity_window: int = _plasticity_window.current_int
	var LTP_multiplier: float = _LTP_multiplier.current_float
	var LTD_multiplier: float = _LTD_multiplier.current_float
	
	var mapping: SingleMappingDefinition = SingleMappingDefinition.new(
		morphology_used,
		scalar,
		PSP,
		is_plastic,
		plasticity_constant,
		LTP_multiplier,
		LTD_multiplier,
		plasticity_window
	)
	return [mapping]

func _on_edit_pressed() -> void:
	var morphology: BaseMorphology = _morphologies.get_selected_morphology()
	if morphology != null:
		BV.WM.spawn_manager_morphology(morphology)

func _on_mapping_delete_press() -> void:
	_row_container.visible = false
	user_changed_something.emit()




