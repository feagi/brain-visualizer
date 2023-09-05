extends Panel


func ready():
	pass

func _on_nm_settings_button_pressed():
	if visible:
		visible = false
	else:
		visible = true
