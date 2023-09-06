extends Panel

var morphology_list = []
var name_file = []

func _ready():
	FeagiEvents.retrieved_latest_morphology_listing.connect(updated_morphology_list)
	FeagiEvents.retrieved_latest_usuage_of_morphology.connect(usuage_update)

func _on_nm_settings_button_pressed():
	if visible:
		visible = false
	else:
		visible = true
		morphology_list = []
		$Composite_BOX/VBoxContainer/HBoxContainer3/OptionButton.clear()
		$Composite_BOX/VBoxContainer/HBoxContainer3/OptionButton.add_item(" ")
		for i in FeagiCache.morphology_cache.available_morphologies:
			morphology_list.append(i)
			$Composite_BOX/VBoxContainer/HBoxContainer3/OptionButton.add_item(i)
			var new_node = $Scroll_Vertical/VBoxContainer/morphology_button.duplicate()
			new_node.text = i
			new_node.visible = true
			new_node.connect("pressed", Callable(_on_texture_button_pressed).bind(new_node.text))
			$Scroll_Vertical/VBoxContainer.add_child(new_node)

func _on_texture_button_pressed(value):
	if value in name_file:
		var path_to_icon = "res://Feagi-Godot-Interface/UI/Resources/morphology_icons/"+str(value) + ".png" 
		$BoxContainer/VBoxContainer2/BoxContainer/VBoxContainer2/TextureRect.visible = true
		$BoxContainer/VBoxContainer2/BoxContainer/VBoxContainer2/Button.visible = false
		$BoxContainer/VBoxContainer2/BoxContainer/VBoxContainer2/TextureRect.texture_normal = load(path_to_icon)
	else:
		$BoxContainer/VBoxContainer2/BoxContainer/VBoxContainer2/TextureRect.visible = false
		$BoxContainer/VBoxContainer2/BoxContainer/VBoxContainer2/Button.visible = true
		$BoxContainer/VBoxContainer2/BoxContainer/VBoxContainer2/Button.text = value
	FeagiRequests.get_morphology_usuage(value)
	FeagiRequests.refresh_morphology_properties(value)

func updated_morphology_list(_dummy):
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

func usuage_update(body):
	$BoxContainer/VBoxContainer2/TextEdit.text = ""
	var test_json_conv = JSON.new()
	test_json_conv.parse(body)
	var api_data = test_json_conv.get_data()
	var string_list = ""
	if api_data != null:
		for i in api_data:
			string_list = string_list + i[0] + " > " + i[1] + "\n"
			$BoxContainer/VBoxContainer2/TextEdit.text += str(string_list)
	else:
		$BoxContainer/VBoxContainer2/TextEdit.text = ""
#	$BoxContainer/VBoxContainer2/TextEdit.text = morphology_list
