extends OptionButton
class_name DropDown

signal option_changed(index: int, option: StringName)

@export var initial_items: Array[StringName]
## if the system should attempt to keep the users selection picked whenever the dropdown is updated
@export var attempt_to_preserve_choice_on_update: bool = false

var _DropDownItems: Array[StringName] # not using PackedStringArray due to usage of array modifiers
var _default_font_size: int
var _default_min_size: Vector2

var selected_item: StringName:
	get: return _DropDownItems[selected]

var options: Array:
	get: return _DropDownItems
	set(v): 
		_set_dropdown_via_array(v)

func _ready():
	options = initial_items

func add_option(option: StringName) -> void:
	if option in _DropDownItems:
		push_warning("Item %s already exists in drop down! Skipping!")
		return
	_DropDownItems.append(option)
	add_item(option)

func remove_option(option: StringName) -> void:
	if option not in _DropDownItems:
		push_warning("Item %s does not exist in drop down! Skipping!")
		return
	var option_index: int = _DropDownItems.find(option)
	remove_item(option_index)
	_DropDownItems.remove_at(option_index)
	_default_font_size = get_theme_font_size(&"font_size")
	if custom_minimum_size != Vector2(0,0):
		_default_min_size = custom_minimum_size
	_update_size(VisConfig.UI_manager.UI_scale)
	VisConfig.UI_manager.UI_scale_changed.connect(_update_size)

func set_option(option: StringName):
	if option not in _DropDownItems:
		push_warning("Item %s does not exist in drop down! Skipping!")
		return
	selected = _DropDownItems.find(option)

# cannot type array due to casting issues
func _set_dropdown_via_array(input_array: Array) -> void:
	var keep_text: StringName = ""
	if attempt_to_preserve_choice_on_update and (selected  != -1):
		keep_text = _DropDownItems[selected]
	
	clear()
	_DropDownItems.clear()
	for input_element in input_array:
		add_option(input_element)
	
	if keep_text != "":
		selected = _DropDownItems.find(keep_text)


func _user_selected_item(index: int) -> void:
	option_changed.emit(index, _DropDownItems[index])

func _update_size(multiplier: float) -> void:
	add_theme_font_size_override(&"font_size", int(float(_default_font_size) * multiplier))
	if _default_min_size != Vector2(0,0):
		custom_minimum_size = _default_min_size * multiplier
	size = Vector2(0,0)
