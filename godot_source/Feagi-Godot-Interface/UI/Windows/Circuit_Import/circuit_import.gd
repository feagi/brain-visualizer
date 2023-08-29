extends Panel


# Called when the node enters the scene tree for the first time.
func _ready():
	$HBoxContainer3/Vector3Spinbox/W.editable = false
	$HBoxContainer3/Vector3Spinbox/H.editable = false
	$HBoxContainer3/Vector3Spinbox/D.editable = false
	$TextEdit.editable = false
	FeagiCacheEvents.available_circuit_listing_updated.connect(update_circuit)

func _on_nc_button_pressed():
	size.x = 329
	if visible:
		visible = false
	else:
		visible = true
		$HBoxContainer/OptionButton.clear()
		$HBoxContainer/OptionButton.add_item("")
		FeagiRequests.refresh_available_circuits()

func update_circuit(data):
	for i in data:
		$HBoxContainer/OptionButton.add_item(i)
	size.x += $HBoxContainer/OptionButton.size.x + 65

func _on_option_button_item_selected(index):
	FeagiRequests.get_circuit_size($HBoxContainer/OptionButton.text)
