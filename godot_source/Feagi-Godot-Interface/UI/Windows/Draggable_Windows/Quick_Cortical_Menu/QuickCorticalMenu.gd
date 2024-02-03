extends BaseWindowPanel
class_name QuickCorticalMenu

const CENTER_OFFSET: Vector2 = Vector2(0,200)

var _cortical_area: BaseCorticalArea
var _title_bar: TitleBar

func setup(cortical_area: BaseCorticalArea) -> void:
	_setup_base_window("quick_cortical_menu")
	_cortical_area = cortical_area
	_title_bar = $TitleBar
	_title_bar.title = _cortical_area.name
	focus_exited.connect(_on_focus_lost)
	position = Vector2(VisConfig.UI_manager.screen_center.x, 0) - (size / 2.0) + CENTER_OFFSET
	if !_cortical_area.user_can_delete_this_area:
		$HBoxContainer/Delete.disabled = true
		$HBoxContainer/Delete.tooltip_text = "This Cortical Area Cannot Be Deleted"
	if !_cortical_area.user_can_clone_this_cortical_area:
		$HBoxContainer/Clone.disabled = true
		$HBoxContainer/Clone.tooltip_text = "This Cortical Area Cannot Be Cloned"
	grab_focus()
	

func _button_details() -> void:
	VisConfig.UI_manager.window_manager.spawn_left_panel(_cortical_area)
	_close_window()

func _button_quick_connect() -> void:
	VisConfig.UI_manager.window_manager.spawn_quick_connect(_cortical_area)
	_close_window()

func _button_clone() -> void:
	VisConfig.UI_manager.window_manager.spawn_clone_cortical(_cortical_area)
	_close_window()

func _button_delete() -> void:
	VisConfig.UI_manager.window_manager.spawn_delete_confirmation(_cortical_area)
	_close_window()

func _on_focus_lost() -> void:
	_close_window()

func _close_window() -> void:
	VisConfig.UI_manager.window_manager.force_close_window("quick_cortical_menu")
