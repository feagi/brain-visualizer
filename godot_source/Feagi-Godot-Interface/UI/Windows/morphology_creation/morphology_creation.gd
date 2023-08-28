extends Panel
var gap: int = 50

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in 5:
		var new_node = $Patterns_BOX/Scroll_Vertical/VBoxContainer/HBoxContainer.duplicate()
		$Patterns_BOX/Scroll_Vertical/VBoxContainer.add_child(new_node)
		## Only to test if it does what it should be. Don't forget to delete this
	for i in $RadioButtons.get_children():
		if i.get_class() == "TextureButton":
			i.custom_minimum_size.x = gap
			
