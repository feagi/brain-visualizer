extends Panel

var morphology_list = []
var name_file = []

func ready():
	FeagiCacheEvents.morphology_cache.mor
	FeagiCacheEvents.morphology_cache.morphology_updated(updated_morphology_list)

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
	pass

func updated_morphology_list():
	print("worked")
	var dir = DirAccess.open("res://Feagi-Godot-Interface/UI/Resources/morphology_icons/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir():
				print("Found directory: " + file_name)
			else:
				# Check if the file extension is .import
				if file_name.ends_with(".import"):
					# Ignore .import files
					pass
				else:
					# Check if the file extension is .png
					if file_name.ends_with(".png"):
						# Remove .import and .png extensions from the name
						var clean_name = file_name.replace(".import", "").replace(".png", "")
						if clean_name in FeagiCache.morphology_cache.available_morphologies:
							name_file.append(clean_name)
					else:
						print("Found other file: " + file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	print("HERE: ", name_file)
