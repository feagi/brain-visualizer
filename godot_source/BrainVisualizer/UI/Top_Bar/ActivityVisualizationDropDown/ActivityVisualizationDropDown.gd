extends BoxContainer
class_name ActivityVisualizationDropDown

## Index 0: global neural connections (same as legacy eye toggle). Index 1: voxel inspector (hover API).
signal activity_mode_changed(index: int)


func _user_request_activity(_view_name: StringName, index: int) -> void:
	activity_mode_changed.emit(index)
