extends DraggableWindow
class_name QuickCorticalMenu

var _cortical_area: BaseCorticalArea
var _title_bar: TitleBar

func _ready():
	super._ready()

func setup(cortical_area: BaseCorticalArea) -> void:
	_cortical_area = cortical_area
	_title_bar = $TitleBar
	_title_bar.title = _cortical_area.name
	focus_exited.connect(_on_focus_lost)
	position = VisConfig.UI_manager.screen_center - (size / 2.0)
	

func _button_details() -> void:
	VisConfig.UI_manager.window_manager.spawn_left_panel(_cortical_area)
	_close_window()

func _button_quick_connect() -> void:
	VisConfig.UI_manager.window_manager.spawn_quick_connect()
	_close_window()

func _button_clone() -> void:
	_close_window()

func _button_delete() -> void:
	FeagiRequests.delete_cortical_area(_cortical_area.cortical_ID)
	_close_window()

func _on_focus_lost() -> void:
	_close_window()

func _close_window() -> void:
	VisConfig.UI_manager.window_manager.force_close_window("quick_cortical_menu")
