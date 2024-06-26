extends BaseDraggableWindow
class_name QuickCorticalMenu

const CENTER_OFFSET: Vector2 = Vector2(0, 100)

var _cortical_area: BaseCorticalArea

func setup(cortical_area: BaseCorticalArea) -> void:
	var delete_button: TextureButton = _window_internals.get_node('HBoxContainer/Delete')
	var clone_button: TextureButton = _window_internals.get_node('HBoxContainer/Clone')
	
	_setup_base_window("quick_cortical_menu")
	_cortical_area = cortical_area
	_titlebar.title = _cortical_area.name
	focus_exited.connect(_on_focus_lost)
	
	var position_to_spawn: Vector2i = get_viewport().get_mouse_position() - (size / 2.0) - CENTER_OFFSET
	if position_to_spawn.y < CENTER_OFFSET.y:
		position_to_spawn.y += int(CENTER_OFFSET.y * 2.0)
	position = position_to_spawn
	if !_cortical_area.user_can_delete_this_area:
		delete_button.disabled = true
		delete_button.tooltip_text = "This Cortical Area Cannot Be Deleted"
	if !_cortical_area.user_can_clone_this_cortical_area:
		clone_button.disabled = true
		clone_button.tooltip_text = "This Cortical Area Cannot Be Cloned"
	#grab_focus()

	#NOTE: Removed left bar spawn reference from here. Handle that in WindowManager directly instead please!

	

func _button_details() -> void:
	BV.WM.spawn_cortical_properties(_cortical_area)
	close_window()

func _button_quick_connect() -> void:
	BV.WM.spawn_quick_connect(_cortical_area)
	close_window()

func _button_clone() -> void:
	BV.WM.spawn_clone_cortical(_cortical_area)
	close_window()

func _button_delete() -> void:
	var no_button: ConfigurableButtonDefinition = ConfigurableButtonDefinition.create_close_button_definition(
		"No"
		)
	var yes_button: ConfigurableButtonDefinition = ConfigurableButtonDefinition.create_custom_button_definition(
		"Yes",
		FeagiCore.requests.delete_cortical_area,
		[_cortical_area.cortical_ID]
	)
	var button_array: Array[ConfigurableButtonDefinition] = [no_button, yes_button]

	var delete_confirmation: ConfigurablePopupDefinition = ConfigurablePopupDefinition.new(
		"Confirm Deletion", 
		"Are you sure you wish to delete cortical area %s?" % _cortical_area.name,
		button_array
		)
	BV.WM.spawn_popup(delete_confirmation)


	
	close_window()

func _on_focus_lost() -> void:
	close_window()
