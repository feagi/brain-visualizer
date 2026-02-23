extends HBoxContainer
class_name Prefab_PatternVectorPairWithDelete

var current_vector_pair: PatternVector3Pairs:
	get: return PatternVector3Pairs.new($PV1.current_vector, $PV2.current_vector)
	set(v):
		$PV1.current_vector = v.incoming
		$PV2.current_vector = v.outgoing

func setup(setup_data: Dictionary, _irrelevant2):
	current_vector_pair = setup_data["vectorPair"]
	_allow_editing(setup_data["allow_editing"])
	var allow_editing_signal: Signal = setup_data["allow_editing_signal"]
	allow_editing_signal.connect(_allow_editing)
	
func _allow_editing(editing_allowed: bool) -> void:
	$PV1.editable = editing_allowed
	$PV2.editable = editing_allowed
	$VisualEditButton.visible = editing_allowed
	$DeleteButton.visible = editing_allowed

func _on_visual_edit_button_pressed() -> void:
	BV.WM.spawn_pattern_visual_edit(
		current_vector_pair,
		func(pair: PatternVector3Pairs) -> void:
			current_vector_pair = pair
	)

# Connected Via UI to the pressed signal from the delete button
func _on_delete_button_pressed() -> void:
	queue_free()
