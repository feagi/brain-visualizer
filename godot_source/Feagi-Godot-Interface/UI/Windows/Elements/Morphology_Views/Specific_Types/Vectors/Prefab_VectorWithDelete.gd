extends HBoxContainer

var current_vector: Vector3i:
	get: return $Vector.current_vector


func setup(setup_data: Dictionary, _irrelevant2):
	$Vector.editable = setup_data["editable"]
	$DeleteButton.visible = setup_data["editable"]
	$Vector.current_vector = setup_data["vector"]

# Connected Via UI to the pressed signal from the delete button
func _on_delete_button_pressed() -> void:
	queue_free()
