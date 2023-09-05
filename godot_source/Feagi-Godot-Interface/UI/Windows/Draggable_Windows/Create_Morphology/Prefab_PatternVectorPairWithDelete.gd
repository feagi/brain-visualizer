extends HBoxContainer

var current_vector_pair: PatternVector3Pairs:
	get: return PatternVector3Pairs.new($PV1.current_vector, $PV2.current_vector)

## All spawned items from scrollbar have setup called, but we don't need to do anything here
func setup(_irrelevant1, _irrelevant2):
	pass

# Connected Via UI to the pressed signal from the delete button
func _on_delete_button_pressed() -> void:
	queue_free()
