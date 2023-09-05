extends Panel
var gap: int = 20
var duplicated_reference_name_listV = [] # store all node in Vectors
var duplicated_reference_name_listP = [] # Store all node in Patterns

# Called when the node enters the scene tree for the first time.
func _ready():
	## Only to test if it does what it should be. Don't forget to delete this
	for i in $RadioButtons.get_children():
		if i.get_class() == "TextureButton":
			i.custom_minimum_size.x = gap

func _on_composite_pressed():
	$Composite_BOX.visible = true
	$Vector_BOX.visible = false
	$Patterns_BOX.visible = false
	$add_row.visible= false



func _on_vectors_pressed():
	$Composite_BOX.visible = false
	$Vector_BOX.visible = true
	$Patterns_BOX.visible = false
	$add_row.visible= true
	if not duplicated_reference_name_listV:
		_on_add_row_pressed() # directly ping the signal function


func _on_patterns_pressed():
	$Composite_BOX.visible = false
	$Vector_BOX.visible = false
	$Patterns_BOX.visible = true
	$add_row.visible= true
	if not duplicated_reference_name_listP:
		_on_add_row_pressed() # directly ping the signal function


func _on_nm_add_button_pressed():
	if visible:
		visible = false
	else:
		visible = true
		$Composite_BOX/VBoxContainer/HBoxContainer3/OptionButton.clear()
		$Composite_BOX/VBoxContainer/HBoxContainer3/OptionButton.add_item(" ")
		for i in FeagiCache.morphology_cache.available_morphologies:
			$Composite_BOX/VBoxContainer/HBoxContainer3/OptionButton.add_item(i)

func clear_list_of_pattern():
	print("heree")
	for i in duplicated_reference_name_listP:
		i.queue_free()
	duplicated_reference_name_listP = []

func clear_list_of_vector():
	for i in duplicated_reference_name_listV:
		i.queue_free()
	duplicated_reference_name_listV = []
	
func _on_visibility_changed():
	if not visible:
		clear_list_of_pattern()
		clear_list_of_vector()
		$Composite_BOX.visible = false
		$Vector_BOX.visible = false
		$Patterns_BOX.visible = false
		$RadioButtons/composite.button_pressed = false
		$RadioButtons/vectors.button_pressed = false
		$RadioButtons/patterns.button_pressed = false

func delete_itself(node):
	for i in duplicated_reference_name_listP:
		if node == i:
			duplicated_reference_name_listP.erase(i)
			node.queue_free()
			return
	for i in duplicated_reference_name_listV:
		if node == i:
			duplicated_reference_name_listV.erase(i)
			node.queue_free()
			return

func _on_add_row_pressed():
	if $Vector_BOX.visible:
		var new_node = $Vector_BOX/Scroll_Vertical/VBoxContainer/XYZ_BOX.duplicate()
		new_node.visible = true
		new_node.get_node("Button").connect("pressed",Callable(delete_itself).bind(new_node))
		$Vector_BOX/Scroll_Vertical/VBoxContainer.add_child(new_node)
		duplicated_reference_name_listV.append(new_node)
	elif $Patterns_BOX.visible:
		var new_node = $Patterns_BOX/Scroll_Vertical/VBoxContainer/HBoxContainer.duplicate()
		new_node.visible = true
		new_node.get_node("remove").connect("pressed",Callable(delete_itself).bind(new_node))
		$Patterns_BOX/Scroll_Vertical/VBoxContainer.add_child(new_node)
		duplicated_reference_name_listP.append(new_node)


func _on_create_pressed():
	var json = {}
	var new_name = $morp_box/LineEdit.text
	var new_type = "Patterns"
	var empty_flag = 0
	var string_input = []
	var full_array = []
	for i in duplicated_reference_name_listP: # iterate all duplicated node
		empty_flag = 0
		full_array = []
		var empty_array1 = [i.get_node("X1").text, i.get_node("Y1").text, i.get_node("Z1").text]
		var empty_array2 = [i.get_node("X2").text, i.get_node("Y2").text, i.get_node("Z2").text]
		var symbols_to_check = ["?", "*"]
		for x in empty_array1:
			if x in symbols_to_check:
				empty_array1[empty_flag] = str(x)
			else:
				empty_array1[empty_flag] = int(x)
			empty_flag += 1
		empty_flag = 0
		for b in empty_array2:
			if b in symbols_to_check:
				empty_array2[empty_flag] = str(b)
			else:
				empty_array2[empty_flag] = int(b)
			empty_flag += 1
		full_array.append(empty_array1)
		full_array.append(empty_array2)
		#string_input.append(PatternVector3Pairs(full_array))
	json["patterns"] = string_input
	FeagiRequests.request_creating_pattern_morphology("Patterns", json["patterns"])
