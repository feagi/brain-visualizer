extends Panel


# Called when the node enters the scene tree for the first time.
func _ready():
	$HBoxContainer3/Vector3Spinbox/W.editable = false
	$HBoxContainer3/Vector3Spinbox/H.editable = false
	$HBoxContainer3/Vector3Spinbox/D.editable = false
	$TextEdit.editable = false
	FeagiCacheEvents.available_circuit_listing_updated.connect(update_circuit)
	FeagiEvents.retrieved_circuit_size.connect(_on_circuit_size_updated)
	$HBoxContainer/OptionButton.item_selected.connect(_on_option_button_item_selected)

func _on_nc_button_pressed():
	size.x = 329
	if visible:
		visible = false
		$HBoxContainer3/Vector3Spinbox/W.value = 0
		$HBoxContainer3/Vector3Spinbox/H.value = 0
		$HBoxContainer3/Vector3Spinbox/D.value = 0
	else:
		visible = true
		$HBoxContainer/OptionButton.clear()
		$HBoxContainer/OptionButton.add_item("")
		FeagiRequests.refresh_available_circuits()

func update_circuit(data):
	for i in data:
		$HBoxContainer/OptionButton.add_item(i)
	size.x += $HBoxContainer/OptionButton.size.x + 65

func _on_option_button_item_selected(_index):
	FeagiRequests.get_circuit_size($HBoxContainer/OptionButton.text)

func _on_circuit_size_updated(circuit_name: StringName, circuit_dimensions: Vector3i) -> void:
	if circuit_name != ($HBoxContainer/OptionButton.text):
		push_warning("Got wrong circuit area dimensions! Skipping!")
		return
	$HBoxContainer3/Vector3Spinbox/W.value = circuit_dimensions.x
	$HBoxContainer3/Vector3Spinbox/H.value = circuit_dimensions.y
	$HBoxContainer3/Vector3Spinbox/D.value = circuit_dimensions.z
