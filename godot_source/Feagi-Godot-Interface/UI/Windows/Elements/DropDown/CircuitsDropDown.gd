extends OptionButton
class_name CircuitsDropDown

signal user_selected_circuit(circuit_file_name: StringName)

func _ready() -> void:
	item_selected.connect(_user_selected_item)
	_list_circuits(FeagiCache.available_circuits)
	FeagiCacheEvents.available_circuit_listing_updated.connect(_list_circuits)

func _list_circuits(circuits: PackedStringArray) -> void:
	clear()
	for circuit in circuits:
		add_item(circuit.left(circuit.length() - 5))
	_remove_radio_buttons()

func _user_selected_item(index: int) -> void:
	user_selected_circuit.emit(FeagiCache.available_circuits[index] + ".json")

func _remove_radio_buttons() -> void:
	var pm: PopupMenu = get_popup()
	for i in pm.get_item_count():
		if pm.is_item_radio_checkable(i):
			pm.set_item_as_radio_checkable(i, false)