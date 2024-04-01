extends OptionButton
class_name CircuitsDropDown

signal user_selected_circuit(circuit_file_name: StringName)
signal circuit_example_transform_change(dimensions: Vector3i, location: Vector3i)

var _list_of_circuit_friendly_names: PackedStringArray
var _default_font_size: int
var _default_min_size: Vector2


func _ready() -> void:
	item_selected.connect(_user_selected_item)
	FeagiEvents.retrieved_circuit_listing.connect(_list_circuits)
	FeagiRequests.refresh_available_circuits()
	_default_font_size = get_theme_font_size(&"font_size")
	if custom_minimum_size != Vector2(0,0):
		_default_min_size = custom_minimum_size
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)

func get_current_circuit_friendly_name() -> StringName:
	if selected == -1: 
		return ""
	return _list_of_circuit_friendly_names[selected]

func get_current_circuit_file_name() -> StringName:
	if selected == -1: 
		return ""
	return CircuitDetails.friendly_name_to_file_name(_list_of_circuit_friendly_names[selected])

func _list_circuits(circuits: PackedStringArray) -> void:
	_list_of_circuit_friendly_names = CircuitDetails.file_name_array_to_friendly_name_array(circuits)
	clear()
	for circuit_friendly_name in _list_of_circuit_friendly_names:
		add_item(circuit_friendly_name)
	_remove_radio_buttons()
	selected = -1

func _user_selected_item(index: int) -> void:
	user_selected_circuit.emit(CircuitDetails.friendly_name_to_file_name(_list_of_circuit_friendly_names[index]))

func _remove_radio_buttons() -> void:
	var pm: PopupMenu = get_popup()
	for i in pm.get_item_count():
		if pm.is_item_radio_checkable(i):
			pm.set_item_as_radio_checkable(i, false)

func _update_size(multiplier: float) -> void:
	add_theme_font_size_override(&"font_size", int(float(_default_font_size) * multiplier))
	if _default_min_size != Vector2(0,0):
		custom_minimum_size = _default_min_size * multiplier
	size = Vector2(0,0)
