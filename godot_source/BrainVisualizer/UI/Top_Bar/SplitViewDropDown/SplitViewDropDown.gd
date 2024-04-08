extends BoxContainer
class_name SplitViewDropDown



#signal requesting_view_change(view: TempSplit.STATES)
signal requesting_view_change()

func _user_request_view(_view_name: StringName, index: int) -> void:
	#requesting_view_change.emit(TempSplit.STATES.values()[index])
	requesting_view_change.emit()
