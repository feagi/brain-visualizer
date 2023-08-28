extends Panel


# Called when the node enters the scene tree for the first time.
func _ready():
	for i in 5:
		var new_node = $Patterns_BOX/Scroll_Vertical/VBoxContainer/HBoxContainer.duplicate()
		$Patterns_BOX/Scroll_Vertical/VBoxContainer.add_child(new_node)
		## Only to test if it does what it should be. Don't forget to delete this
		
