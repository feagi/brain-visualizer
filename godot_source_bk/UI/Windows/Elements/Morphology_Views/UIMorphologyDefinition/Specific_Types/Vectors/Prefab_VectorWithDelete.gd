extends HBoxContainer

var current_vector: Vector3i:
	get: return $Vector.current_vector


func setup(setup_data: Dictionary, _irrelevant2):
	$Vector.current_vector = setup_data["vector"]
	_allow_editing(setup_data["allow_editing"])
	var allow_editing_signal: Signal = setup_data["allow_editing_signal"]
	allow_editing_signal.connect(_allow_editing)

func _allow_editing(editing_allowed: bool) -> void:
	$Vector.editable = editing_allowed
	$DeleteButton.visible = editing_allowed
	
# Connected Via UI to the pressed signal from the delete button
func _on_delete_button_pressed() -> void:
	queue_free()
