extends BaseDraggableWindow
class_name QuickCorticalMenu

const WINDOW_NAME: StringName = "quick_menu"
const CENTER_OFFSET: Vector2 = Vector2(0, 100)
var _mode: GenomeObject.ARRAY_MAKEUP
var _selection: Array[GenomeObject]


func setup(selection: Array[GenomeObject]) -> void:
	_mode = GenomeObject.get_makeup_of_array(selection)
	_selection = selection
	
	var details_button: TextureButton = _window_internals.get_node('HBoxContainer/Details')
	var quick_connect_button: TextureButton = _window_internals.get_node('HBoxContainer/QuickConnect')
	var move_to_region_button: TextureButton = _window_internals.get_node('HBoxContainer/AddToRegion')
	var clone_button: TextureButton = _window_internals.get_node('HBoxContainer/Clone')
	var delete_button: TextureButton = _window_internals.get_node('HBoxContainer/Delete')
	_setup_base_window(WINDOW_NAME)
	focus_exited.connect(_on_focus_lost)
	var position_to_spawn: Vector2i = get_viewport().get_mouse_position() - (size / 2.0) - (CENTER_OFFSET * BV.UI.loaded_theme_scale.x)
	if position_to_spawn.y < CENTER_OFFSET.y:
		position_to_spawn.y += int(CENTER_OFFSET.y * 2.0)
	position = position_to_spawn
	
	match(_mode):
		GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA:
			var area: AbstractCorticalArea = (_selection[0] as AbstractCorticalArea)
			_titlebar.title = area.friendly_name
			if !area.user_can_delete_this_area:
				delete_button.disabled = true
				delete_button.tooltip_text = "This Cortical Area Cannot Be Deleted"
			if !area.user_can_clone_this_cortical_area:
				clone_button.disabled = true
				clone_button.tooltip_text = "This Cortical Area Cannot Be Cloned"
		GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
			var region: BrainRegion = (_selection[0] as BrainRegion)
			_titlebar.title = region.friendly_name
			quick_connect_button.visible = false
			clone_button.visible = false
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_CORTICAL_AREAS:
			_titlebar.title = "Selected multiple areas"
			quick_connect_button.visible = false
			clone_button.visible = false
			details_button.visible = false
			delete_button.visible = false
		GenomeObject.ARRAY_MAKEUP.MULTIPLE_BRAIN_REGIONS:
			_titlebar.title = "Selected multiple regions"
			quick_connect_button.visible = false
			clone_button.visible = false
			details_button.visible = false
			delete_button.visible = false
		GenomeObject.ARRAY_MAKEUP.VARIOUS_GENOME_OBJECTS:
			_titlebar.title = "Selected multiple objects"
			quick_connect_button.visible = false
			clone_button.visible = false
			details_button.visible = false
			delete_button.visible = false




	#NOTE: Removed left bar spawn reference from here. Handle that in WindowManager directly instead please!




func _button_details() -> void:
	match(_mode):
		GenomeObject.ARRAY_MAKEUP.SINGLE_CORTICAL_AREA:
			BV.WM.spawn_cortical_properties((_selection[0] as AbstractCorticalArea))
		GenomeObject.ARRAY_MAKEUP.SINGLE_BRAIN_REGION:
			BV.WM.spawn_edit_region((_selection[0] as BrainRegion))
			pass
	close_window()

func _button_quick_connect() -> void:
	BV.WM.spawn_quick_connect((_selection[0] as AbstractCorticalArea))
	close_window()

func _button_clone() -> void:
	BV.WM.spawn_clone_cortical((_selection[0] as AbstractCorticalArea))
	close_window()

func _button_add_to_region() -> void:
	var parent_region: BrainRegion = _selection[0].current_parent_region # Whaever we selected, the parent reigon is the parent region of any element that selection
	BV.WM.spawn_move_to_region(_selection, parent_region)
	close_window()

func _button_delete() -> void:
	BV.WM.spawn_confirm_deletion(_selection)
	close_window()

func _on_focus_lost() -> void:
	close_window()
