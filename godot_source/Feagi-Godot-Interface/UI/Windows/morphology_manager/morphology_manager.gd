extends Panel

var morphology_list = []

func ready():
	pass

func _on_nm_settings_button_pressed():
	if visible:
		visible = false
	else:
		visible = true
		morphology_list = []
		for i in FeagiCache.morphology_cache.available_morphologies:
			morphology_list.append(i)
			var new_node = $Scroll_Vertical/VBoxContainer/morphology_button.duplicate()
			new_node.text = i
			new_node.visible = true
			new_node.connect("pressed", Callable(_on_texture_button_pressed).bind(new_node.text))
			$Scroll_Vertical/VBoxContainer.add_child(new_node)

func _on_texture_button_pressed(value):
	print(value) # Needs to use API to send data
