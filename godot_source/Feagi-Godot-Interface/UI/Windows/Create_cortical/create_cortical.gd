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
	visible = false


func _on_button_2_pressed():
	$"../../Brain_Visualizer".delete_example()
	#var json_data: Dictionary = {}
	if $VBoxContainer/BoxContainer/RadioButtons/CUSTOM.is_pressed():
		FeagiRequests.add_custom_cortical_area(
			$VBoxContainer/name_linedit/LineEdit.text,
			Vector3($VBoxContainer/XYZ/IntX.value, $VBoxContainer/XYZ/IntY.value, $VBoxContainer/XYZ/IntZ.value),
			Vector3($VBoxContainer/WDH/W.value, $VBoxContainer/WDH/H.value, $VBoxContainer/WDH/D.value),
			false,
			Vector2i(0,0),
			CorticalArea.CORTICAL_AREA_TYPE.CUSTOM
		)
		$Button2.release_focus()
	$VBoxContainer/XYZ/IntX.value = 0
	$VBoxContainer/XYZ/IntY.value = 0
	$VBoxContainer/XYZ/IntZ.value = 0
	$VBoxContainer/WDH/W.value = 0
	$VBoxContainer/WDH/D.value = 0
	$VBoxContainer/WDH/H.value = 0
	$VBoxContainer/name_linedit/LineEdit.text = ""
	$VBoxContainer/BoxContainer/RadioButtons/CUSTOM.set_pressed(false)
	$VBoxContainer/BoxContainer/RadioButtons/OPU.set_pressed(false)
	$VBoxContainer/BoxContainer/RadioButtons/IPU.set_pressed(false)
	$VBoxContainer/name_linedit.visible = false
	$VBoxContainer/XYZ.visible = false
	$VBoxContainer/WDH.visible = false
	visible = false


func _on_ipu_pressed():
	$VBoxContainer/name_dropdown.visible = true
	$VBoxContainer/name_linedit.visible = false
	$VBoxContainer/name_dropdown/dropdown_node.clear()
	$VBoxContainer/name_dropdown/dropdown_node.add_item(" ")
	var IPU_list = FeagiCache.cortical_areas_cache.search_for_cortical_areas_by_type(CorticalArea.CORTICAL_AREA_TYPE.IPU)
	for i in IPU_list:
		$VBoxContainer/name_dropdown/dropdown_node.add_item(i.name)

func _on_opu_pressed():
	$VBoxContainer/name_dropdown.visible = true
	$VBoxContainer/name_linedit.visible = false
	$VBoxContainer/name_dropdown/dropdown_node.clear()
	$VBoxContainer/name_dropdown/dropdown_node.add_item(" ")
	var OPU_list = FeagiCache.cortical_areas_cache.search_for_cortical_areas_by_type(CorticalArea.CORTICAL_AREA_TYPE.OPU)
	for i in OPU_list:
		$VBoxContainer/name_dropdown/dropdown_node.add_item(i.name)


func _on_custom_pressed():
	$VBoxContainer/name_linedit.visible = true
	$VBoxContainer/name_dropdown.visible = false
	$VBoxContainer/channel_count.visible = false
	$VBoxContainer/name_dropdown/dropdown_node.select(0)
	_on_line_edit_text_changed("")


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
	$VBoxContainer/name_linedit/LineEdit.text = ""
	$VBoxContainer/BoxContainer/RadioButtons/CUSTOM.set_pressed(false)
	$VBoxContainer/BoxContainer/RadioButtons/OPU.set_pressed(false)
	$VBoxContainer/BoxContainer/RadioButtons/IPU.set_pressed(false)
	$VBoxContainer/name_linedit.visible = false
	$VBoxContainer/name_dropdown.visible = false
	$VBoxContainer/XYZ.visible = false
	$VBoxContainer/WDH.visible = false
	$VBoxContainer/channel_count.visible = false
	$"../../Brain_Visualizer".delete_example()



func _on_dropdown_node_item_selected(index):
	if index != 0:
		$VBoxContainer/XYZ.visible = true
		$VBoxContainer/WDH.visible = true
		$VBoxContainer/channel_count.visible = true
	else:
		$VBoxContainer/XYZ.visible = false
		$VBoxContainer/WDH.visible = false
		$VBoxContainer/channel_count.visible = true
