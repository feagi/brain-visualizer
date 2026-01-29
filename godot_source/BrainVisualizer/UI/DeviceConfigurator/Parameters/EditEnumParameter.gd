extends EditAbstractParameter
class_name EditEnumParameter
## Editor for EnumParameter using a dropdown.

var _options: OptionButton

## Set up the UI from the given EnumParameter.
func setup(parameter: EnumParameter) -> void:
	base_setup(parameter)
	_options = $Value
	_options.clear()
	for option in parameter.options:
		_options.add_item(String(option))
	var index := -1
	for idx in range(_options.item_count):
		if _options.get_item_text(idx) == String(parameter.value):
			index = idx
			break
	if index >= 0:
		_options.select(index)
	else:
		_options.add_item(String(parameter.value))
		_options.select(_options.item_count - 1)
		_options.disabled = true
		_options.tooltip_text = "Unsupported enum value"

## Export the edited EnumParameter.
func export() -> AbstractParameter:
	var parameter: EnumParameter = super()
	if _options.selected >= 0:
		parameter.value = StringName(_options.get_item_text(_options.selected))
	return parameter
