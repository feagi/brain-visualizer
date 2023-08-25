extends Panel

func _ready():
	$TitleBar/Title_Text.text = "Quick_Connect"
	$source.anchors_preset = PRESET_CENTER_LEFT
	$arrow.anchors_preset = PRESET_CENTER_LEFT
	$arrow.position.x = $source.size.x + $source.position.x + 50
	$arrow/Label.anchors_preset = PRESET_CENTER
	$arrow.size = $arrow.size + $arrow/Label.size 
	$arrow.anchors_preset = PRESET_CENTER
	size = size + $arrow.size


func _on_source_pressed():
	$source.text = "Select a cortical"

func _on_destination_pressed():
	$destination.text = "Select a cortical"


func _on_ca_connect_button_pressed():
	if visible:
		visible = false
	else:
		visible = true


func _on_morphology_menulist_item_selected(index):
	$arrow/Label.text = $morphology_menulist.get_item_text(index)
	$morphology_menulist.visible = false


func _on_arrow_pressed():
	$morphology_menulist.visible = true


func _on_visibility_changed():
	if not visible:
		$morphology_menulist.visible = false
		$source.text = "Source"
		$destination.text = "Destination"
		$arrow/Label.text = "Select a morphology"
