extends GrowingPanel

func _ready():
	$TitleBar.get_node("Title_Text").text = "Tutorial Menu"


func _on_tu_button_pressed():
	if visible:
		visible = false
	else:
		visible = true
