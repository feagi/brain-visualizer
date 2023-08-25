extends ItemList


func _ready():
	dir_contents("res://Feagi-Godot-Interface/UI/Resources/morphology_icons/")

	

func dir_contents(path):
	var dir = DirAccess.open(path)
	var counter = 0
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
#						var icon_texture = ImageTexture.new()
#						var image = Image.load(path_to_icon)                
#						# Resize the image
#						var new_size = Vector2(50, 50)  # Adjust the size as needed
#						image.resize(new_size)
						add_item(clean_name, load(path_to_icon), true)
						# Pause  this, we will revisit this
						counter += 1
					else:
						print("Found other file: " + file_name)
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")

