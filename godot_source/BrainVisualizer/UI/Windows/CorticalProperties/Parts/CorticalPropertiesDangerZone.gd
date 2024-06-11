extends VBoxContainer
class_name CorticalPropertiesDangerZone

# https://www.youtube.com/watch?v=yK0P1Bk8Cx4

var _cortical_area_ref: AbstractCorticalArea

func initial_values_from_FEAGI(cortical_reference: AbstractCorticalArea) -> void:
	_cortical_area_ref = cortical_reference

## Called via delete button press (signal connected via tscn)
func _user_pressed_delete_button() -> void:
	print("Cortical Properties requesting cortical area deletion for " + _cortical_area_ref.cortical_ID)
	var arr: Array[GenomeObject] = [_cortical_area_ref]
	BV.WM.spawn_confirm_deletion(arr)
