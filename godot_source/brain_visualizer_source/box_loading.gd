extends ColorRect

func _process(_delta):
	if timer_api.loading_box_timer:
		visible = true
	else:
		visible = false
