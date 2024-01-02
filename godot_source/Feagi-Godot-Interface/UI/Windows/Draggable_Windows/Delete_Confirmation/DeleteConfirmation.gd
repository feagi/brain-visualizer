extends DraggableWindow
class_name DeleteConfirmation

const WARNING_TEXT: String = "Are you sure you wish to delete %s?"

var _cortical_to_delete: BaseCorticalArea

func setup(cortical_area: BaseCorticalArea) -> void:
	$VBoxContainer/text.text = WARNING_TEXT % cortical_area.name
	position = VisConfig.UI_manager.screen_center - (size / 2.0)
	_cortical_to_delete = cortical_area

func _button_cancel() -> void:
	VisConfig.UI_manager.window_manager.force_close_window("delete_confirmation")

func _button_confirm() -> void:
	FeagiRequests.delete_cortical_area(_cortical_to_delete.cortical_ID)
	VisConfig.UI_manager.window_manager.force_close_window("delete_confirmation")

