extends Panel


# Called when the node enters the scene tree for the first time.
func _ready():
	$HBoxContainer3/Vector3Spinbox/W.editable = false
	$HBoxContainer3/Vector3Spinbox/H.editable = false
	$HBoxContainer3/Vector3Spinbox/D.editable = false


func _on_nc_button_pressed():
	if visible:
		visible = false
	else:
		visible = true
