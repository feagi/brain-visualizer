extends CBNodeConnectableBase
class_name CBNodeRegion

const CUSTOM_TOOLTIP_TRIGGER_SCRIPT = preload("res://BrainVisualizer/UI/GenericElements/CustomTooltip/CustomTooltipTrigger.gd")

var representing_region: BrainRegion:
	get: return _representing_region

var _representing_region: BrainRegion
var _description_tooltip_trigger: Node


## Called by CB right after instantiation
func setup(region_ref: BrainRegion) -> void:
	var input_path: NodePath = NodePath("Inputs")
	var output_path: NodePath = NodePath("Outputs")
	var recursive_path: NodePath = NodePath("") # Regions dont have recursives
	setup_base(recursive_path, input_path, output_path)
	
	_representing_region = region_ref
	CACHE_updated_region_name(region_ref.friendly_name)
	CACHE_updated_2D_position(region_ref.coordinates_2D)
	name = region_ref.region_ID
	
	_representing_region.friendly_name_updated.connect(CACHE_updated_region_name)
	_representing_region.coordinates_2D_updated.connect(CACHE_updated_2D_position)
	_representing_region.description_updated.connect(_on_region_description_updated)
	_representing_region.UI_highlighted_state_updated.connect(func(is_highlighted: bool): if is_highlighted != selected: selected = is_highlighted)
	_setup_description_tooltip()
	# NOTE: Deletion of the of the region (node) is handled by CB


## Side-caret tooltip sits to the right of the region node so it does not cover the circuit.
func _setup_description_tooltip() -> void:
	if get_node_or_null("DescriptionTooltipTrigger") != null:
		_description_tooltip_trigger = get_node("DescriptionTooltipTrigger")
	else:
		_description_tooltip_trigger = Node.new()
		_description_tooltip_trigger.set_script(CUSTOM_TOOLTIP_TRIGGER_SCRIPT)
		_description_tooltip_trigger.name = "DescriptionTooltipTrigger"
		add_child(_description_tooltip_trigger)
	_description_tooltip_trigger.set("use_side_caret_tooltip", true)
	_description_tooltip_trigger.set("max_visible_lines", FEAGIUtils.region_description_tooltip_max_lines())
	_description_tooltip_trigger.set("max_wrap_width_px", FEAGIUtils.region_description_tooltip_wrap_width_px())
	_sync_description_tooltip_text()


func _on_region_description_updated(_new_description: StringName) -> void:
	_sync_description_tooltip_text()


func _sync_description_tooltip_text() -> void:
	if _description_tooltip_trigger == null or not is_instance_valid(_description_tooltip_trigger):
		return
	if _representing_region == null:
		return
	var text: String = String(_representing_region.description).strip_edges()
	if _description_tooltip_trigger.has_method("set_tooltip_text"):
		_description_tooltip_trigger.set_tooltip_text(text)
	else:
		_description_tooltip_trigger.set("tooltip_text", text)

# Responses to changes in cache directly. NOTE: Connection and creation / deletion we won't do here and instead allow CB to handle it, since they can involve interactions with connections
#region CACHE Events and responses

## Updates the title text of the node
func CACHE_updated_region_name(name_text: StringName) -> void:
	title = name_text

## Updates the position within CB of the node
func CACHE_updated_2D_position(new_position: Vector2i) -> void:
	apply_model_position_offset(new_position)


#endregion

#region User Interactions

func _on_single_left_click() -> void:
	var is_multi := Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_META) or Input.is_physical_key_pressed(KEY_SHIFT)
	if not is_multi:
		var cb_parent = get_parent()
		if cb_parent is CircuitBuilder:
			(cb_parent as CircuitBuilder)._select_single_graph_element(self)
		BV.UI.selection_system.clear_all_highlighted()
	BV.UI.selection_system.add_to_highlighted(_representing_region)
	BV.UI.selection_system.select_objects(SelectionSystem.SOURCE_CONTEXT.FROM_CIRCUIT_BUILDER_CLICK)



func _on_double_left_click() -> void:
	double_clicked.emit(self)


signal double_clicked(self_ref: CBNodeRegion) ## Node was double clicked # TEMP



#func _gui_input(event):
#	var mouse_event: InputEventMouseButton
#	if event is InputEventMouseButton:
#		mouse_event = event as InputEventMouseButton
#		if mouse_event.double_click:
#			double_clicked.emit(self)
#			return
#		if mouse_event.is_pressed(): return
#		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
#			return
#		if !_dragged:
#			if _representing_region != null:
#				BV.UI.user_selected_single_cortical_area_independently(_representing_region)

	#	TODO TEMP

#endregion
