extends VBoxContainer
class_name LeftBarDangerZone

# https://www.youtube.com/watch?v=yK0P1Bk8Cx4

var _cortical_area_ref: CorticalArea

func initial_values_from_FEAGI(cortical_reference: CorticalArea) -> void:
	_cortical_area_ref = cortical_reference

## Called via delete button press (signal connected via tscn)
func _user_pressed_delete_button() -> void:
	print("Left Bar requesting cortical area deletion for " + _cortical_area_ref.cortical_ID)
	FeagiRequests.delete_cortical_area(_cortical_area_ref.cortical_ID)
