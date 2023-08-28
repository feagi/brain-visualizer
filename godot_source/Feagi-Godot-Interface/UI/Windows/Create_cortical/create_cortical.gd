extends Panel



func _on_int_x_value_changed(value):
	$"../../Brain_Visualizer".generate_single_cortical(value,$VBoxContainer/XYZ/IntY.value,$VBoxContainer/XYZ/IntZ.value,$VBoxContainer/WDH/W.value, $VBoxContainer/WDH/D.value, $VBoxContainer/WDH/H.value, "example")


func _on_int_y_value_changed(value):
	$"../../Brain_Visualizer".generate_single_cortical($VBoxContainer/XYZ/IntX.value,value,$VBoxContainer/XYZ/IntZ.value,$VBoxContainer/WDH/W.value, $VBoxContainer/WDH/D.value, $VBoxContainer/WDH/H.value, "example")


func _on_int_z_value_changed(value):
	$"../../Brain_Visualizer".generate_single_cortical($VBoxContainer/XYZ/IntX.value,$VBoxContainer/XYZ/IntY.value,value,$VBoxContainer/WDH/W.value, $VBoxContainer/WDH/D.value, $VBoxContainer/WDH/H.value, "example")



func _on_w_value_changed(value):
	$"../../Brain_Visualizer".generate_single_cortical($VBoxContainer/XYZ/IntX.value,$VBoxContainer/XYZ/IntY.value,$VBoxContainer/XYZ/IntZ.value,value, $VBoxContainer/WDH/D.value, $VBoxContainer/WDH/H.value, "example")



func _on_h_value_changed(value):
	$"../../Brain_Visualizer".generate_single_cortical($VBoxContainer/XYZ/IntX.value,$VBoxContainer/XYZ/IntY.value,$VBoxContainer/XYZ/IntZ.value,$VBoxContainer/WDH/W.value, $VBoxContainer/WDH/D.value, value, "example")



func _on_d_value_changed(value):
	$"../../Brain_Visualizer".generate_single_cortical($VBoxContainer/XYZ/IntX.value,$VBoxContainer/XYZ/IntY.value,$VBoxContainer/XYZ/IntZ.value,$VBoxContainer/WDH/W.value, value, $VBoxContainer/WDH/H.value, "example")



func _on_close_button_pressed():
	$"../../Brain_Visualizer".delete_example()


func _on_button_2_pressed():
	$"../../Brain_Visualizer".delete_example()
	var json_data: Dictionary = {}
	if $VBoxContainer/BoxContainer/RadioButtons/CUSTOM.is_pressed():
		json_data["cortical_type"] = "CUSTOM"
		json_data["cortical_name"] = $VBoxContainer/BoxContainer2/LineEdit.text
		json_data["coordinates_3d"] = []
		json_data["cortical_dimensions"] = []
		json_data["coordinates_3d"].append($VBoxContainer/XYZ/IntX.value)
		json_data["coordinates_3d"].append($VBoxContainer/XYZ/IntY.value)
		json_data["coordinates_3d"].append($VBoxContainer/XYZ/IntZ.value)
		json_data["cortical_dimensions"].append($VBoxContainer/WDH/W.value)
		json_data["cortical_dimensions"].append($VBoxContainer/WDH/H.value)
		json_data["cortical_dimensions"].append($VBoxContainer/WDH/D.value)

#		generate_single_cortical(json_data["coordinates_3d"][0], json_data["coordinates_3d"][1], json_data["coordinates_3d"][2], json_data["cortical_dimensions"][0], json_data["cortical_dimensions"][1], json_data["cortical_dimensions"][2], json_data["cortical_name"])
		FeagiRequests.add_custom_cortical_area(
			$VBoxContainer/BoxContainer2/LineEdit.text,
			Vector3($VBoxContainer/XYZ/IntX.value, $VBoxContainer/XYZ/IntY.value, $VBoxContainer/XYZ/IntZ.value),
			Vector3($VBoxContainer/WDH/IntX.value, $VBoxContainer/WDH/IntY.value, $VBoxContainer/WDH/IntZ.value),
			false,
			Vector2i(0,0),
			"CUSTOM"
		)
#		POST_GE_customCorticalArea(json_data)
		$Button2.release_focus()
#		Godot_list.Node_2D_control = false
