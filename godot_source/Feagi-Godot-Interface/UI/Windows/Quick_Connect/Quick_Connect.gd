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
