extends HBoxContainer
class_name Prefab_PatternVectorPairWithDelete

var current_vector_pair: PatternVector3Pairs:
	get: return PatternVector3Pairs.new($PV1.current_vector, $PV2.current_vector)
	set(v):
		$PV1.current_vector = v.incoming
		$PV2.current_vector = v.outgoing


func setup(setup_data: Dictionary, _irrelevant2):
	$PV1.editable = setup_data["editable"]
	$PV2.editable = setup_data["editable"]
	$DeleteButton.visible = setup_data["editable"]
	current_vector_pair = setup_data["vectorPair"]

# Connected Via UI to the pressed signal from the delete button
func _on_delete_button_pressed() -> void:
	queue_free()
