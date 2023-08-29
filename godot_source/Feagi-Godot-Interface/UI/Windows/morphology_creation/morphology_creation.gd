extends Panel
var gap: int = 20

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in 5:
		var new_node = $Patterns_BOX/Scroll_Vertical/VBoxContainer/HBoxContainer.duplicate()
		$Patterns_BOX/Scroll_Vertical/VBoxContainer.add_child(new_node)
		## Only to test if it does what it should be. Don't forget to delete this
	for i in $RadioButtons.get_children():
		if i.get_class() == "TextureButton":
			i.custom_minimum_size.x = gap

func _on_composite_pressed():
	$Composite_BOX.visible = true
	$Vector_BOX.visible = false
	$Patterns_BOX.visible = false



func _on_vectors_pressed():
	$Composite_BOX.visible = false
	$Vector_BOX.visible = true
	$Patterns_BOX.visible = false


func _on_patterns_pressed():
	$Composite_BOX.visible = false
	$Vector_BOX.visible = false
	$Patterns_BOX.visible = true


func _on_nm_add_button_pressed():
	if visible:
		visible = false
	else:
		visible = true
		$Composite_BOX/VBoxContainer/HBoxContainer3/OptionButton.clear()
		$Composite_BOX/VBoxContainer/HBoxContainer3/OptionButton.add_item(" ")
		for i in FeagiCache.morphology_cache.available_morphologies:
			$Composite_BOX/VBoxContainer/HBoxContainer3/OptionButton.add_item(i)


func _on_visibility_changed():
	if not visible:
		$Composite_BOX.visible = false
		$Vector_BOX.visible = false
		$Patterns_BOX.visible = false
		$Composite_BOX.set_press(false)
		$Vector_BOX.set_press(false)
		$Patterns_BOX.set_press(false)
