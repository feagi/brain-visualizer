extends ColorRect

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if timer_api.loading_box_timer:
		visible = true
	else:
		visible = false
