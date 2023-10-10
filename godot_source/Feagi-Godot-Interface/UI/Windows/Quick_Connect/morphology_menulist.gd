extends Panel

var stored_name: Array = []
var node_list: Array = [] # Just to store node's reference so I can clear them

"""
Needs to add singal to prevent the every loop 
"""

func dir_contents(path): # res://Feagi-Godot-Interface/UI/Resources/morphology_icons/
	for i in node_list:
		i.queue_free()
	node_list = []
	var dir = DirAccess.open(path)
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
						var path_to_icon = "res://Feagi-Godot-Interface/UI/Resources/morphology_icons/"+str(file_name)
						if clean_name in FeagiCache.morphology_cache.available_morphologies:
							var new_node = $Scroll_Vertical/VBoxContainer/TextureButton.duplicate()
							$Scroll_Vertical/VBoxContainer.add_child(new_node)
							new_node.texture_normal = load(path_to_icon)
							new_node.visible = true
							new_node.set_name(clean_name)
							new_node.connect("pressed", Callable($".."._on_texture_button_pressed).bind(new_node.get_name()))
							node_list.append(new_node)
							stored_name.append(clean_name)
					else:
						print("Found other file: " + file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	for i in FeagiCache.morphology_cache.available_morphologies:
		if not i in stored_name:
			var new_node = $Scroll_Vertical/VBoxContainer/Button_morp.duplicate()
			new_node.visible = true
			new_node.text = i
			new_node.connect("pressed", Callable($".."._on_texture_button_pressed).bind(new_node.text))
			node_list.append(new_node)
			$Scroll_Vertical/VBoxContainer.add_child(new_node)
