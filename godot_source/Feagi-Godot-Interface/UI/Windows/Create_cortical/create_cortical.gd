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
	var json_data = {}
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
		FeagiRequests.add_custom_cortical_area(json_data)
		$Button2.release_focus()
	$VBoxContainer/XYZ/IntX.value = 0
	$VBoxContainer/XYZ/IntY.value = 0
	$VBoxContainer/XYZ/IntZ.value = 0
	$VBoxContainer/WDH/W.value = 0
	$VBoxContainer/WDH/D.value = 0
	$VBoxContainer/WDH/H.value = 0
	$VBoxContainer/BoxContainer2/LineEdit.text = ""
	$VBoxContainer/BoxContainer/RadioButtons/CUSTOM.set_pressed(false)
	$VBoxContainer/BoxContainer/RadioButtons/OPU.set_pressed(false)
	$VBoxContainer/BoxContainer/RadioButtons/IPU.set_pressed(false)
	$VBoxContainer/BoxContainer2.visible = false
	$VBoxContainer/XYZ.visible = false
	$VBoxContainer/WDH.visible = false


func _on_ipu_pressed():
	$VBoxContainer/BoxContainer2.visible = true

func _on_opu_pressed():
	$VBoxContainer/BoxContainer2.visible = true

func _on_custom_pressed():
	$VBoxContainer/BoxContainer2.visible = true


func _on_line_edit_text_changed(new_text):
	if new_text != "":
		$VBoxContainer/XYZ.visible = true
		$VBoxContainer/WDH.visible = true
	else:
		$VBoxContainer/XYZ.visible = false
		$VBoxContainer/WDH.visible = false


func _on_ca_add_button_pressed():
	if visible:
		visible = false
	else:
		visible = true


func _on_visibility_changed():
	$VBoxContainer/XYZ/IntX.value = 0
	$VBoxContainer/XYZ/IntY.value = 0
	$VBoxContainer/XYZ/IntZ.value = 0
	$VBoxContainer/WDH/W.value = 0
	$VBoxContainer/WDH/D.value = 0
	$VBoxContainer/WDH/H.value = 0
	$VBoxContainer/BoxContainer2/LineEdit.text = ""
	$VBoxContainer/BoxContainer/RadioButtons/CUSTOM.set_pressed(false)
	$VBoxContainer/BoxContainer/RadioButtons/OPU.set_pressed(false)
	$VBoxContainer/BoxContainer/RadioButtons/IPU.set_pressed(false)
	$VBoxContainer/BoxContainer2.visible = false
	$VBoxContainer/XYZ.visible = false
	$VBoxContainer/WDH.visible = false
