extends BaseWindowPanel
class_name WindowUserOptions

func setup() -> void:
	_setup_base_window("user_options")
	var scale_multiplier_field: FloatInput = $'BoxContainer/Size Scaling/FloatInput'
	scale_multiplier_field.current_float = VisConfig.UI_manager.UI_scale

func _user_change_scale(scale_multiplier: float) -> void:
	VisConfig.UI_manager.UI_scale = scale_multiplier
